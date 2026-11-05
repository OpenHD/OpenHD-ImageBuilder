#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
root="$temporary/root"
mkdir -p "$root/usr/share/openhd/overlays" "$root/lib/modules/test/extra" "$root/boot"
printf 'camera_auto_detect=0\ndtoverlay=imx708\n' > "$root/boot/config.txt"
cp "$root/boot/config.txt" "$temporary/original"
if bash "$repo/additionalFiles/prepare-veye-image.sh" "$root"; then exit 1; fi
printf test-overlay > "$root/usr/share/openhd/overlays/veye_gxcam.dtbo"
if bash "$repo/additionalFiles/prepare-veye-image.sh" "$root"; then exit 1; fi
touch "$root/lib/modules/test/extra/veye_gxcam.ko.xz"
bash "$repo/additionalFiles/prepare-veye-image.sh" "$root"
cmp "$root/boot/config.txt" "$temporary/original"
cmp "$root/boot/overlays/veye_gxcam.dtbo" "$root/usr/share/openhd/overlays/veye_gxcam.dtbo"
mkdir -p "$root/boot/firmware"
cp "$temporary/original" "$root/boot/firmware/config.txt"
bash "$repo/additionalFiles/prepare-veye-image.sh" "$root"
cmp "$root/boot/firmware/config.txt" "$temporary/original"
cmp "$root/boot/firmware/overlays/veye_gxcam.dtbo" "$root/usr/share/openhd/overlays/veye_gxcam.dtbo"
echo 'VEYE image support installation and selection preservation passed'
