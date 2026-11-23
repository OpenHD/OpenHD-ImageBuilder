#!/usr/bin/env bash
set -euo pipefail

ready=/run/openhd-zero3w-imx415-ready
if [[ ${1:-} == --check ]]; then
    [[ -f "$ready" ]] && systemctl is-active --quiet rkaiq_3A
    exit $?
fi

rm -f "$ready"
for media in /dev/media[0-9]*; do
    [[ -c "$media" ]] || continue
    topology=$(media-ctl -d "$media" -p) || continue
    sensor=$(sed -n 's/^[- ]*entity [0-9]*: \(m00_b_imx415 [^ ]*\) (.*$/\1/p' <<<"$topology")
    [[ -n $sensor && $sensor != *$'\n'* && $topology == *rkisp_mainpath* ]] || continue

    test -s /etc/iqfiles/imx415_CMK-OT2022-PX1_IR0147-50IRC-8M-F20.json
    capture=$(media-ctl -d "$media" -e rkisp_mainpath)
    # Radxa's 4-lane driver exposes the 30 fps binning mode as RAW12 1944x1097.
    media-ctl -d "$media" -V "\"$sensor\":0 [fmt:SGBRG12_1X12/1944x1097]"
    [[ $(media-ctl -d "$media" --get-v4l2 "\"$sensor\":0") == *SGBRG12_1X12/1944x1097* ]]
    media-ctl -d "$media" -V '"rkisp-isp-subdev":0 [fmt:SGBRG12_1X12/1944x1097 crop:(12,8)/1920x1080]'
    media-ctl -d "$media" -V '"rkisp-isp-subdev":2 [fmt:YUYV8_2X8/1920x1080 crop:(0,0)/1920x1080]'
    v4l2-ctl -d "$capture" --set-fmt-video=width=1920,height=1080,pixelformat=NV12 \
        --set-selection=target=crop,left=0,top=0,width=1920,height=1080
    touch "$ready"
    echo "Configured $sensor and RKISP for 1920x1080 at 30 fps on $media"
    exit 0
done
