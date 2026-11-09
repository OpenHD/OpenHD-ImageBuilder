#!/bin/sh
# All Pico boards keep recordings on a dedicated SD/eMMC partition.
# Never format automatically or fall back to recording into the rootfs.
[ "$1" = start ] || exit 0
set -eu
settings=/usr/local/share/openhd/video/LUCKFOX_MIS5001_0.json
suspended=/Config/.sd-recording-suspended
no_card() {
    if [ -f "$settings" ]; then
        mode=$(sed -n 's/.*"air_recording"[[:space:]]*:[[:space:]]*\([012]\).*/\1/p' "$settings")
        case "$mode" in
        1|2)
            mkdir -p /Config
            printf '%s\n' "$mode" > "$suspended"
            sed -i 's/"air_recording"[[:space:]]*:[[:space:]]*[012]/"air_recording": 0/' "$settings"
            ;;
        esac
    fi
}
# Resolve /dev/block/by-name aliases before checking what a mount contains.
mount_device() {
    device=$(awk -v point="$1" '$2 == point { print $1; exit }' /proc/mounts)
    [ -n "$device" ] && readlink -f "$device"
}
root_device=$(mount_device / || true)
config_device=$(mount_device /Config || true)
userdata_device=$(mount_device /userdata || true)
recording_device() {
    case "$1" in /dev/mmcblk*p*) ;; *) return 1 ;; esac
    [ "$1" != "$root_device" ] && [ "$1" != "$config_device" ] &&
        [ "$1" != "$userdata_device" ]
}
mkdir -p /Video
if mountpoint -q /Video; then
    device=$(mount_device /Video || true)
    recording_device "$device" || { no_card; exit 0; }
elif mountpoint -q /Videos; then
    # The existing SD/eMMC boot scripts mount the dedicated partition here.
    device=$(mount_device /Videos || true)
    recording_device "$device" || { no_card; exit 0; }
    mount --bind /Videos /Video || { no_card; exit 1; }
else
    # Vendor DTs mark this slot non-removable. Rescan a card inserted after boot.
    driver=/sys/bus/platform/drivers/dwmmc_rockchip
    if grep -q ' / ubifs ' /proc/mounts &&
       [ ! -b /dev/mmcblk1 ] && [ -e "$driver/ffaa0000.mmc" ]; then
        if echo ffaa0000.mmc > "$driver/unbind" && echo ffaa0000.mmc > "$driver/bind"; then
            sleep 2
        else
            no_card; exit 1
        fi
    fi
    # BusyBox blkid works on both the minimal NAND and SD/eMMC images.
    devices=$(blkid | sed -n '/[[:space:]]LABEL="RECORDINGS"/s/:.*//p')
    # Older GPT images name the partition but do not label its filesystem.
    if [ -z "$devices" ] && [ -b /dev/block/by-name/recordings ]; then
        devices=$(readlink -f /dev/block/by-name/recordings)
    fi
    set -- $devices
    [ "$#" -eq 1 ] || { no_card; exit 0; }
    device=$(readlink -f "$1")
    recording_device "$device" || { no_card; exit 0; }
    # Do not steal a partition already mounted elsewhere.
    if awk -v device="$device" '$1 == device { found=1 } END { exit !found }' /proc/mounts; then
        no_card; exit 0
    fi
    mount -o noatime "$device" /Video || { no_card; exit 1; }
fi
touch /Video/external_video_part.txt
if [ -f "$suspended" ] && [ -f "$settings" ]; then
    mode=$(cat "$suspended")
    case "$mode" in
    1|2) sed -i "s/\"air_recording\"[[:space:]]*:[[:space:]]*[012]/\"air_recording\": $mode/" "$settings" ;;
    *) exit 1 ;;
    esac
    rm "$suspended"
fi
# Enable recording once after a usable card is first mounted. Later user
# changes to recording mode remain authoritative.
marker=/Config/.sd-recording-initialized
if [ ! -e "$marker" ]; then
    mkdir -p "$(dirname "$settings")" /Config
    if [ -f "$settings" ]; then
        # Existing complete camera settings include this field.
        grep -q '"air_recording"[[:space:]]*:' "$settings" || exit 1
        sed -i 's/"air_recording"[[:space:]]*:[[:space:]]*[0-9][0-9]*/"air_recording": 1/' "$settings"
    else
        # Camera settings deserialize missing fields using production defaults.
        printf '{"air_recording":1}\n' > "$settings"
    fi
    touch "$marker"
fi
