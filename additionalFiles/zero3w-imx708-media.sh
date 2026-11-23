#!/usr/bin/env bash
set -euo pipefail

# Keep RKAIQ's profile and the sensor readout in sync with OpenHD.
mode_file=/run/openhd-zero3w-imx708-mode
ready_file=/run/openhd-zero3w-imx708-ready
if [[ ${1:-} == --select ]]; then
    case ${2:-} in
        30|60|120) ;;
        *) exit 2 ;;
    esac
    exec 9>"$mode_file.lock"
    flock 9
    current=$(cat "$mode_file" 2>/dev/null || true)
    ready=$(cat "$ready_file" 2>/dev/null || true)
    if [[ $ready != "$2" ]] || ! systemctl is-active --quiet rkaiq_3A; then
        printf '%s\n' "$2" > "$mode_file"
        if ! systemctl restart rkaiq_3A || [[ $(cat "$ready_file" 2>/dev/null || true) != "$2" ]]; then
            if [[ -n $current ]]; then
                printf '%s\n' "$current" > "$mode_file"
            else
                rm -f "$mode_file"
            fi
            systemctl restart rkaiq_3A || true
            exit 1
        fi
    fi
    exit 0
fi

rm -f "$ready_file"
fps=$(cat "$mode_file" 2>/dev/null || python3 -c '
import json
from pathlib import Path

try:
    camera = Path("/usr/local/share/openhd/video/ROCK_3_IMX708_0.json")
    fps = json.loads(camera.read_text())["streamed_video_format"]["framerate"]
except (OSError, ValueError, KeyError, TypeError):
    fps = 60
    try:
        sysutils = Path("/usr/local/share/OpenHD/SysUtils/config.json")
        settings = json.loads(sysutils.read_text())
        if settings.get("camera_type") == 93:
            fps = {"1280x720@30": 30, "1280x720@120": 120}.get(
                settings.get("camera_resolution_fps"), 60)
    except (OSError, ValueError, AttributeError, TypeError):
        pass
print(fps if fps in (30, 60, 120) else 60)
')
mode=1920x1080
profile=imx708-color-lift.json
if [[ $fps == 30 ]]; then
    profile=imx708-color-lift-30.json
elif [[ $fps == 120 ]]; then
    mode=1536x864
    profile=imx708-color-lift-120.json
fi

for media in /dev/media[0-9]*; do
    [[ -c "$media" ]] || continue
    topology=$(media-ctl -d "$media" -p) || continue
    sensor=$(sed -n 's/^[- ]*entity [0-9]*: \(m[0-9]*_[bf]_imx708 [^ ]*\) (.*$/\1/p' <<<"$topology")
    [[ -n "$sensor" && "$sensor" != *$'\n'* && "$topology" == *rkisp_mainpath* ]] || continue
    media-ctl -d "$media" -V "\"$sensor\":0 [fmt:SRGGB10_1X10/${mode}]"
    media-ctl -d "$media" -V "\"rkisp-isp-subdev\":0 [fmt:SRGGB10_1X10/$mode crop:(0,0)/$mode]"
    media-ctl -d "$media" -V "\"rkisp-isp-subdev\":2 [fmt:YUYV8_2X8/$mode crop:(0,0)/$mode]"
    # Unity is 256 on this sensor. RKAIQ still owns exposure and analogue gain.
    sensor_device=$(media-ctl -d "$media" -e "$sensor")
    v4l2-ctl -d "$sensor_device" -c digital_gain=768
    if [[ $fps == 120 ]]; then
        v4l2-ctl -d "$sensor_device" -c vertical_blanking=40
    fi
    profile_path="/usr/share/openhd/iq-profiles/imx708/$profile"
    test -s "$profile_path"
    ln -sfn "$profile_path" /etc/iqfiles/imx708_uhq_default.json
    printf '%s\n' "$fps" > "$ready_file"
    echo "Configured $sensor and RKISP for $mode at $fps fps on $media"
    exit 0
done
