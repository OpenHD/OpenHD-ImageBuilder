#!/usr/bin/env bash
set -euo pipefail

ready=/run/openhd-zero3w-imx290-ready
if [[ ${1:-} == --check ]]; then
    [[ -n ${2:-} && $(cat "$ready" 2>/dev/null || true) == "$2" ]] &&
        systemctl is-active --quiet rkaiq_3A
    exit $?
fi

rm -f "$ready"
for media in /dev/media[0-9]*; do
    [[ -c "$media" ]] || continue
    topology=$(media-ctl -d "$media" -p) || continue
    sensor=$(sed -n 's/^[- ]*entity [0-9]*: \(m00_b_imx290 [^ ]*\) (.*$/\1/p' <<<"$topology")
    [[ -n $sensor && $sensor != *$'\n'* && $topology == *rkisp_mainpath* ]] || continue

    fps=$(python3 - <<'PY'
import json
from pathlib import Path

try:
    camera = Path("/usr/local/share/openhd/video/ROCK_3_IMX462_0.json")
    fps = json.loads(camera.read_text())["streamed_video_format"]["framerate"]
except (OSError, ValueError, KeyError, TypeError):
    fps = 60
    try:
        settings = json.loads(Path("/usr/local/share/OpenHD/SysUtils/config.json").read_text())
        if settings.get("camera_type") == 94:
            fmt = settings.get("camera_resolution_fps", "")
            fps = {"1920x1080@30": 30, "1280x720@120": 120}.get(fmt, 60)
    except (OSError, ValueError, AttributeError):
        pass
print(fps if fps in (30, 60, 120) else 60)
PY
)
    mode=1920x1080
    if [[ $fps == 120 ]]; then
        mode=1280x720
    fi
    profile="/usr/share/openhd/iq-profiles/imx290/imx290-$fps.json"
    test -s "$profile"
    subdev=$(media-ctl -d "$media" -e "$sensor")
    capture=$(media-ctl -d "$media" -e rkisp_mainpath)
    media-ctl -d "$media" -V "\"$sensor\":0 [fmt:SRGGB10_1X10/$mode]"
    v4l2-ctl -d "$subdev" --set-subdev-fps "pad=0,fps=$fps"
    media-ctl -d "$media" -V "\"rkisp-isp-subdev\":0 [fmt:SRGGB10_1X10/$mode crop:(0,0)/$mode]"
    media-ctl -d "$media" -V "\"rkisp-isp-subdev\":2 [fmt:YUYV8_2X8/$mode crop:(0,0)/$mode]"
    w=${mode%x*}
    h=${mode#*x}
    v4l2-ctl -d "$capture" --set-fmt-video="width=$w,height=$h,pixelformat=NV12" \
        --set-selection="target=crop,left=0,top=0,width=$w,height=$h"
    ln -sfn "$profile" /etc/iqfiles/imx290_imx290_default.json
    printf '%s\n' "$fps" > "$ready"
    exit 0
done
