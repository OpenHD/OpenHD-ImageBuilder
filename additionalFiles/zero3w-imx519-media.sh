#!/usr/bin/env bash
set -euo pipefail

ready=/run/openhd-zero3w-imx519-ready
if [[ ${1:-} == --check ]]; then
    [[ -n ${2:-} && $(cat "$ready" 2>/dev/null || true) == "$2" ]] &&
        systemctl is-active --quiet rkaiq_3A
    exit $?
fi

rm -f "$ready"
for media in /dev/media[0-9]*; do
    [[ -c "$media" ]] || continue
    topology=$(media-ctl -d "$media" -p) || continue
    sensor=$(sed -n 's/^[- ]*entity [0-9]*: \(m[0-9]*_[bf]_imx519 [^ ]*\) (.*$/\1/p' <<<"$topology")
    [[ -n $sensor && $sensor != *$'\n'* && $topology == *rkisp_mainpath* ]] || continue

    fps=$(python3 - <<'PY'
import json
from pathlib import Path

try:
    camera = Path('/usr/local/share/openhd/video/ROCK_3_IMX519_0.json')
    fps = json.loads(camera.read_text())['streamed_video_format']['framerate']
except (OSError, ValueError, KeyError, TypeError):
    fps = 60
    try:
        sysutils = Path('/usr/local/share/OpenHD/SysUtils/config.json')
        settings = json.loads(sysutils.read_text())
        if settings.get('camera_type') == 95:
            fmt = settings.get('camera_resolution_fps', '')
            if fmt == '1280x720@120':
                fps = 120
            elif fmt in ('1280x720@30', '1920x1080@30'):
                fps = 30
    except (OSError, ValueError, AttributeError):
        pass
print(fps if fps in (30, 60, 120) else 60)
PY
)
    mode=1920x1080
    if [[ $fps == 120 ]]; then
        mode=1280x720
    fi
    profile="/usr/share/openhd/iq-profiles/imx519/imx519-$fps.json"
    test -s "$profile"
    media-ctl -d "$media" -V "\"$sensor\":0 [fmt:SRGGB10_1X10/$mode]"
    media-ctl -d "$media" -V "\"rkisp-isp-subdev\":0 [fmt:SRGGB10_1X10/$mode crop:(0,0)/$mode]"
    media-ctl -d "$media" -V "\"rkisp-isp-subdev\":2 [fmt:YUYV8_2X8/$mode crop:(0,0)/$mode]"
    ln -sfn "$profile" /etc/iqfiles/imx519_arducam_default.json
    printf '%s\n' "$fps" > "$ready"
    echo "Configured $sensor and RKISP for $mode at $fps fps on $media"
    exit 0
done
