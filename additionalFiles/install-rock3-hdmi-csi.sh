#!/usr/bin/env bash
set -euo pipefail

rk628=false
case "${OS:-}" in
    radxa-debian-rock3a|radxa-debian-rock3b)
        board=rock-3ab
        compatible='"radxa,rock-3a", "radxa,rock-3b"'
        i2c=i2c5
        pins=i2c5m0_xfer
        power='&gpio1 9 0'
        dphy2=csi2_dphy0
        lane_counts=(2)
        dtb_patterns=('rk3568-rock-3a*.dtb' 'rk3568-rock-3b*.dtb')
        ;;
    radxa-debian-rock3c)
        board=rock-3c
        compatible='"radxa,rock-3c"'
        i2c=i2c2
        pins=i2c2m1_xfer
        power='&gpio3 22 0'
        dphy2=csi2_dphy0
        lane_counts=(2)
        rk628=true
        dtb_patterns=('rk3566-rock-3c*.dtb')
        ;;
    radxa-debian-rock-cm3*)
        dphy2=csi2_dphy0
        lane_counts=(2 4)
        if [[ "${OPENHD_ZERO3W_IMX708:-false}" == true ]]; then
            board=radxa-zero3
            compatible='"radxa,zero3"'
            i2c=i2c2
            pins=i2c2m1_xfer
            power='&gpio3 22 0'
            rk628=true
            dtb_patterns=('rk3566-radxa-zero3*.dtb' 'rk3566-radxa-zero-3*.dtb')
        else
            board=radxa-cm3
            compatible='"radxa,cm3-rpi-cm4-io"'
            i2c=i2c0
            pins=i2c0_xfer
            power='&gpio4 17 0'
            dphy2=csi2_dphy1
            dtb_patterns=('rk3566-radxa-cm3-rpi-cm4*.dtb')
        fi
        ;;
    *) exit 0 ;;
esac

apt-get -y --no-install-recommends -o Acquire::Retries=5 install cpp device-tree-compiler

# Only validate kernels that are eligible for boot on this image. Radxa uses
# tc35874x; the alternate kernel driver has the same HDMI timing interface.
shopt -s nullglob
dtbs=()
for tree in /usr/lib/linux-image-*/rockchip /boot/dtbs/*/rockchip; do
    kernel=${tree%/rockchip}
    kernel=${kernel##*/}
    kernel=${kernel#linux-image-}
    config="/boot/config-$kernel"
    if [[ ! -f "$config" ]]; then
        continue
    fi
    for pattern in "${dtb_patterns[@]}"; do
        for dtb in "$tree"/$pattern; do
            if ! grep -Eq '^CONFIG_VIDEO_TC35874(3|X)=[ym]$' "$config"; then
                echo "Kernel $kernel has no TC358743 driver for $dtb" >&2
                exit 1
            fi
            if [[ $rk628 == true ]] && ! grep -Eq '^CONFIG_VIDEO_RK628_CSI=[ym]$' "$config"; then
                echo "Kernel $kernel has no RK628 CSI driver for $dtb" >&2
                exit 1
            fi
            dtbs+=("$dtb")
        done
    done
done
if (( ${#dtbs[@]} == 0 )); then
    echo "Cannot find an installed kernel and camera device tree for $board" >&2
    exit 1
fi

source_dir=$(dirname "$0")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
install_overlay() {
    local overlay=$1 source=$2 dtb
    dtc -@ -I dts -O dtb -o "$overlay" "$source"
    for dtb in "${dtbs[@]}"; do
        fdtoverlay -i "$dtb" -o "$work/merged.dtb" "$overlay"
    done
    install -D -m 0644 "$overlay" "/boot/dtbo/${overlay##*/}.disabled"
}
for lanes in "${lane_counts[@]}"; do
    lane_map='1 2'
    dphy=$dphy2
    if [[ $lanes == 4 ]]; then
        lane_map='1 2 3 4'
        dphy=csi2_dphy0
    fi
    overlay="$work/$board-tc358743-$lanes-lane.dtbo"
    cpp -P -nostdinc -undef -x assembler-with-cpp \
        "-DBOARD_COMPATIBLE=$compatible" "-DPOWER_GPIO=$power" \
        "-DCAM_I2C=$i2c" "-DCAM_I2C_PINS=$pins" "-DCAM_DPHY=$dphy" \
        "-DCSI_LANES=$lane_map" "$source_dir/rock3-tc358743.dts" \
        > "$work/camera.dts"
    install_overlay "$overlay" "$work/camera.dts"
done
if [[ $rk628 == true ]]; then
    install_overlay "$work/$board-rk628-hdmi-in.dtbo" "$source_dir/rock3-rk628.dts"
fi
