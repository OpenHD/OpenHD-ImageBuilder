#!/usr/bin/env bash
# Called after current components are installed in both fresh and cached full images.
set -euo pipefail
[[ "${OPENHD_LITE_IMAGE:-false}" != true ]] || exit 0
case "${OS:-}" in
  radxa-debian-rock5*|radxa-debian-rock3*|radxa-debian-rock-cm3*) ;;
  *) exit 0 ;;
esac
root=${OPENHD_IMAGE_ROOT:-}
base="$root/usr/local/share/qopenhd-rockchip"
assets=$(cd "$(dirname "$0")" && pwd)
test "$(cat "$base/native-video.version")" = 1
for file in QOpenHD openhd-boot-splash boot-logo.png mali/egl-platform-compat.so; do
  test -s "$base/$file" || { echo "Incomplete native Rockchip package: $file" >&2; exit 1; }
done
if grep -q '^distribution=bullseye$' "$base/build-info.txt"; then
  test -s "$base/kiosk-shell-black.so" || { echo 'Missing black Weston 9 kiosk shell' >&2; exit 1; }
fi
sysutils="$root/usr/local/bin/openhd_sys_utils"
[[ -f "$sysutils" ]] || sysutils="$root/usr/bin/openhd_sys_utils"
if ! grep -aFq 'rockchip_native' "$sysutils"; then
  echo 'Full native Rockchip images require the matching SysUtils native-video support' >&2
  exit 1
fi
python3 "$assets/rockchip-mali-runtime.py" --root "${root:-/}"
mkdir -p "$root/etc/qopenhd-rockchip" "$root/etc/systemd/system/openhd-video.service.d" \
  "$root/etc/systemd/system/openhd.service.d" "$root/boot/openhd"
install -m644 "$base/deployment/weston.ini" "$root/etc/qopenhd-rockchip/weston.ini"
for unit in qopenhd.service qopenhd-rockchip-compositor.service openhd-rockchip-boot-splash.service; do
  install -m644 "$base/deployment/$unit" "$root/etc/systemd/system/$unit"
done
install -m644 "$base/deployment/openhd-video-native.conf" "$root/etc/systemd/system/openhd-video.service.d/30-rockchip-native.conf"
touch "$root/etc/qopenhd-rockchip/native-video-enabled"
# The native unit owns these settings; remove only the prototype drop-in.
rm -f "$root/etc/systemd/system/qopenhd.service.d/30-rockchip-native.conf"
cat > "$root/etc/systemd/system/openhd.service.d/20-boot-splash.conf" <<'EOF'
[Service]
StandardInput=null
StandardOutput=journal
StandardError=journal
TTYReset=no
TTYVHangup=no
TTYVTDisallocate=no
EOF
python3 "$assets/rockchip-silent-boot.py" --root "${root:-/}"
# SysUtils owns Ground/Air decisions; it starts QOpenHD (and its compositor)
# only in Ground mode. The early logo is bounded and never gates the daemon.
for unit in qopenhd.service qopenhd-rockchip-compositor.service openhd-video.service \
  openhd-glide.service openhd-glide-autostart.service openhd-glide-stream.service \
  display-manager.service sddm.service lightdm.service gdm.service; do
  systemctl --root="${root:-/}" disable "$unit" 2>/dev/null || true
done
systemctl --root="${root:-/}" set-default multi-user.target
systemctl --root="${root:-/}" mask getty@tty1.service plymouth-start.service plymouth-read-write.service
systemctl --root="${root:-/}" enable openhd-rockchip-boot-splash.service
systemctl --root="${root:-/}" enable openhd.service openhd-sys-utils.service
printf '1\n' > "$root/boot/openhd/openhd-native-boot.version"
echo 'Configured full Rockchip native compositor, silent boot and startup movie'
