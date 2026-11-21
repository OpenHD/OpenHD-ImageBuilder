#!/usr/bin/env bash
set -euo pipefail

[[ -d /proc/device-tree/ochin-camera-enable ]] || exit 0
shopt -s nullglob
mode=1920x1080
fps=60
[[ ! -e /boot/openhd/ochin-cm3.txt ]] || fps=30
iq=/usr/share/openhd/iq-profiles
for media in /dev/media[0-9]*; do
    topology=$(media-ctl -d "$media" -p) || continue
    while IFS= read -r sensor; do
        [[ -n $sensor ]] || continue
        # The routed CIF input presents the sensor on its own media device.
        media-ctl -d "$media" -V "\"$sensor\":0 [fmt:SRGGB10_1X10/$mode]"
        device=$(media-ctl -d "$media" -e "$sensor")
        case "$sensor" in
            *'_imx708 '*)
                v4l2-ctl -d "$device" -c digital_gain=768
                profile="$iq/imx708/imx708-color-lift.json"
                [[ $fps != 30 ]] || profile="$iq/imx708/imx708-color-lift-30.json"
                ln -sfn "$profile" /etc/iqfiles/imx708_uhq_default.json
                ;;
            *'_imx519 '*)
                ln -sfn "$iq/imx519/imx519-$fps.json" /etc/iqfiles/imx519_arducam_default.json
                ;;
            *'_imx290 '*)
                v4l2-ctl -d "$device" --set-subdev-fps "pad=0,fps=$fps"
                ln -sfn "$iq/imx290/imx290-$fps.json" /etc/iqfiles/imx290_imx290_default.json
                ;;
        esac
    done < <(sed -n 's/^[- ]*entity [0-9]*: \(m0[01]_b_\(imx219\|imx708\|imx519\|imx290\|arducam-pivariety\|pivariety\) [^ ]*\) (.*$/\1/p' <<<"$topology")
done

for media in /dev/media[0-9]*; do
    capture=$(media-ctl -d "$media" -e rkisp_mainpath 2>/dev/null) || continue
    parent=$(readlink -f "/sys/class/video4linux/${capture##*/}/device") || continue
    case "$parent" in
        */rkisp-vir0|*/rkisp-vir1) ;;
        *) continue ;;
    esac
    media-ctl -d "$media" -V "\"rkisp-isp-subdev\":0 [fmt:SRGGB10_1X10/$mode crop:(0,0)/$mode]"
    media-ctl -d "$media" -V "\"rkisp-isp-subdev\":2 [fmt:YUYV8_2X8/$mode crop:(0,0)/$mode]"
done
