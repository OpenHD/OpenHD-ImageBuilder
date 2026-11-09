#!/bin/sh
# NAND boards keep recordings on a separately prepared, labelled SD card.
# Never format a card automatically, and never record into the NAND rootfs.
[ "$1" = start ] || exit 0
set -eu
grep -q ' / ubifs ' /proc/mounts || exit 0
settings=/usr/local/share/openhd/video/LUCKFOX_MIS5001_0.json
suspended=/userdata/Config/.sd-recording-suspended
no_card() {
    if [ -f "$settings" ]; then
        mode=$(sed -n 's/.*"air_recording"[[:space:]]*:[[:space:]]*\([012]\).*/\1/p' "$settings")
        case "$mode" in
        1|2)
            mkdir -p /userdata/Config
            printf '%s\n' "$mode" > "$suspended"
            sed -i 's/"air_recording"[[:space:]]*:[[:space:]]*[012]/"air_recording": 0/' "$settings"
            ;;
        esac
    fi
}
mkdir -p /Video
if ! mountpoint -q /Video; then
    # Vendor DTs mark this slot non-removable. Rescan a card inserted after boot.
    driver=/sys/bus/platform/drivers/dwmmc_rockchip
    if [ ! -b /dev/mmcblk1 ] && [ -e "$driver/ffaa0000.mmc" ]; then
        if echo ffaa0000.mmc > "$driver/unbind" && echo ffaa0000.mmc > "$driver/bind"; then
            sleep 2
        else
            no_card; exit 1
        fi
    fi
    # BusyBox blkid is available in the minimal NAND image; lsblk is not.
    devices=$(blkid | sed -n '/[[:space:]]LABEL="RECORDINGS"/s/:.*//p')
    set -- $devices
    [ "$#" -eq 1 ] || { no_card; exit 0; }
    case "$1" in /dev/mmcblk*p*) ;; *) no_card; exit 0 ;; esac
    # Do not steal a partition already mounted elsewhere.
    if awk -v device="$1" '$1 == device { found=1 } END { exit !found }' /proc/mounts; then
        no_card; exit 0
    fi
    mount -o noatime "$1" /Video || { no_card; exit 1; }
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
marker=/userdata/Config/.sd-recording-initialized
if [ ! -e "$marker" ]; then
    mkdir -p "$(dirname "$settings")" /userdata/Config
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
