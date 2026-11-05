#!/usr/bin/env bash
# Validate legacy Pi camera support without changing the selected camera.
set -euo pipefail
root="${1:-}"
boot="$root/boot"
[[ -f "$boot/firmware/config.txt" ]] && boot="$boot/firmware"
overlay=""
for candidate in "$root/usr/share/openhd/overlays/veye_gxcam.dtbo" \
                 "$root/usr/local/share/openhd/kernel/overlays/veye_gxcam.dtbo" \
                 "$boot/overlays/veye_gxcam.dtbo"; do
    if [[ -s "$candidate" ]]; then overlay="$candidate"; break; fi
done
if [[ -z "$overlay" ]]; then
    echo "VEYE GX overlay missing: install a complete openhd-veye-gx or openhd-linux-pi package" >&2
    exit 1
fi
if ! find "$root/lib/modules" -type f -name 'veye_gxcam.ko*' -print -quit | grep -q .; then
    echo "VEYE GX kernel module missing" >&2
    exit 1
fi
mkdir -p "$boot/overlays"
if [[ "$overlay" != "$boot/overlays/veye_gxcam.dtbo" ]]; then
    install -m 644 "$overlay" "$boot/overlays/veye_gxcam.dtbo"
fi
echo "VEYE GX driver and boot overlay verified; camera selection preserved"
