#!/usr/bin/env bash
set -euo pipefail

carrier=${OPENHD_OCHIN_CARRIER:-}
case "$carrier" in
    v1|v2) ;;
    '')
        if [[ "${OS:-}" != radxa-debian-rock-cm3 ||
              "${OPENHD_ZERO3W_IMX708:-false}" == true ]]; then
            exit 0
        fi
        ;;
    *) echo "Unrecognized OCHIN carrier version" >&2; exit 1 ;;
esac

apt-get -y --no-install-recommends install cpp device-tree-compiler v4l-utils
shopt -s nullglob
bases=(/usr/lib/linux-image-*/rockchip/rk3566-radxa-cm3-rpi-cm4-io.dtb)
if (( ${#bases[@]} == 0 )); then
    echo "Cannot find the Radxa CM3 Raspberry Pi CM4 IO base device tree" >&2
    exit 1
fi

source_dir=$(dirname "$0")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
profiles=(
    'imx219 sony,imx219 10 24000000 456000000 RADXA-CAMERA-8M'
)
supported_kernel=false
for base in "${bases[@]}"; do
    kernel=${base%/rockchip/*}
    kernel=${kernel##*/linux-image-}
    case "$kernel" in
        5.10.160-radxa-rk356x|5.10.160-core3566-rk356x|6.1.*-rk2410-nocsf)
            apt-get -y --no-install-recommends install build-essential patch "linux-headers-$kernel"
            bash "$source_dir/configure-zero3w-imx708.sh" --sensors-only "$kernel"
            supported_kernel=true
            ;;
    esac
done
if [[ $supported_kernel == true ]]; then
    profiles+=(
        'imx708 sony,imx708 1a 24000000 450000000 uhq'
        'imx519 sony,imx519 1a 24000000 493500000 arducam'
        'imx462 sony,imx290 1a 37125000 445500000 imx290'
        'imx462-pivariety arducam,arducam-pivariety c 24000000 445500000 IMX462'
    )
fi

ports=(0 1)
[[ -n $carrier ]] || ports=(1)
overlays=()
for port in "${ports[@]}"; do
    if [[ $port == 0 ]]; then
        bus=i2c0 dphy=csi2_dphy2 isp=rkisp_vir1 receiver=csi_in isp_source=cif_out
    else
        bus=i2c2 dphy=csi2_dphy1 isp=rkisp_vir0 receiver=isp_in isp_source=dphy_out
    fi
    # The stock CM4 IO board routes CAM1 controls to I2C0.
    [[ -n $carrier ]] || bus=i2c0
    i2c2=0
    [[ $bus != i2c2 ]] || i2c2=1
    for profile in "${profiles[@]}"; do
        read -r name compatible address clock link module <<< "$profile"
        actuator=0
        [[ $name != imx708 ]] || actuator=1
        output="$work/ochin-cam$port-$name"
        if [[ -z $carrier ]]; then
            case "$name" in
                imx219) continue ;; # Stock CM3 already packages its CAM1 IMX219 overlay.
                imx519) output="$work/radxa-cm3-arducam-pivariety-imx519" ;;
                imx462) output="$work/radxa-cm3-arducam-pivariety-imx462" ;;
                *) output="$work/radxa-cm3-$name" ;;
            esac
        fi
        cpp -P -nostdinc -undef -x assembler-with-cpp \
            "-DCAM_INDEX=$port" "-DCAM_I2C=$bus" "-DCAM_I2C2=$i2c2" "-DCAM_DPHY=$dphy" "-DCAM_ISP=$isp" \
            "-DRECEIVER_IN=$receiver" "-DISP_SOURCE=$isp_source" \
            "-DCLOCK_NODE=ochin-cam$port-clock" "-DSENSOR_NODE=$name@$address" \
            "-DSENSOR_COMPATIBLE=\"$compatible\"" "-DSENSOR_ADDRESS=0x$address" \
            "-DSENSOR_CLOCK=$clock" "-DSENSOR_LINK=$link" "-DSENSOR_MODULE=\"$module\"" \
            "-DCAMERA_IMX708=$actuator" "$source_dir/ochin-camera.dts" > "$output.dts"
        dtc -@ -I dts -O dtb -o "$output.dtbo" "$output.dts"
        overlays+=("$output.dtbo")
    done
done
for base in "${bases[@]}"; do
    for overlay in "${overlays[@]}"; do
        fdtoverlay -i "$base" -o "$work/merged.dtb" "$overlay"
    done
    for cam0 in "$work"/ochin-cam0-*.dtbo; do
        for cam1 in "$work"/ochin-cam1-*.dtbo; do
            fdtoverlay -i "$base" -o "$work/merged.dtb" "$cam0" "$cam1"
        done
    done
done
for overlay in "${overlays[@]}"; do
    install -D -m 0644 "$overlay" "/boot/dtbo/${overlay##*/}.disabled"
done
install -D -m 0755 "$source_dir/ochin-camera-media.sh" /usr/local/libexec/openhd-ochin-camera-media
install -d /etc/systemd/system/rkaiq_3A.service.d /etc/systemd/system/openhd.service.d
cat >/etc/systemd/system/rkaiq_3A.service.d/40-openhd-ochin.conf <<'EOF'
[Service]
ExecStartPre=/usr/local/libexec/openhd-ochin-camera-media
EOF
cat >/etc/systemd/system/openhd.service.d/40-openhd-ochin.conf <<'EOF'
[Unit]
After=rkaiq_3A.service
Wants=rkaiq_3A.service
EOF
if [[ -n $carrier ]]; then
    install -d /boot/openhd
    printf '%s\n' "$carrier" > /boot/openhd/ochin-cm3.txt
fi
