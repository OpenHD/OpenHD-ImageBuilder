#!/usr/bin/env bash
set -euo pipefail

# Configure the sensor and ISP before RKAIQ reads the media graph. GStreamer
# capture caps set the output size, but do not change the sensor's mode.
for media in /dev/media[0-9]*; do
    [[ -c "$media" ]] || continue
    topology=$(media-ctl -d "$media" -p) || continue
    sensor=$(sed -n 's/^[- ]*entity [0-9]*: \(m[0-9]*_[bf]_imx708 [^ ]*\) (.*$/\1/p' <<<"$topology")
    [[ -n "$sensor" && "$sensor" != *$'\n'* && "$topology" == *rkisp_mainpath* ]] || continue
    media-ctl -d "$media" -V "\"$sensor\":0 [fmt:SRGGB10_1X10/1920x1080]"
    media-ctl -d "$media" -V '"rkisp-isp-subdev":0 [fmt:SRGGB10_1X10/1920x1080 crop:(0,0)/1920x1080]'
    media-ctl -d "$media" -V '"rkisp-isp-subdev":2 [fmt:YUYV8_2X8/1920x1080 crop:(0,0)/1920x1080]'
    # Unity is 256 on this sensor. RKAIQ still owns exposure and analogue gain.
    sensor_device=$(media-ctl -d "$media" -e "$sensor")
    v4l2-ctl -d "$sensor_device" -c digital_gain=768
    echo "Configured $sensor and RKISP for 1920x1080 on $media"
    exit 0
done
