#!/bin/bash
# Executed inside a Pi 5 image after installing the Qt 6/native runtime.
set -euo pipefail
base=/usr/local/share/qopenhd-rpi
test -s "$base/QOpenHD"
test -s "$base/weston"
mkdir -p /etc/qopenhd-rpi /usr/local/share/OpenHD/SysUtils /boot/firmware/openhd \
    /etc/systemd/system/openhd.service.d /etc/systemd/system/ssh.service.d
install -m644 "$base/deployment/weston.ini" /etc/qopenhd-rpi/weston.ini
install -m644 "$base/deployment/qopenhd.service" /etc/systemd/system/qopenhd.service
install -m644 "$base/deployment/qopenhd-rpi-compositor.service" /etc/systemd/system/qopenhd-rpi-compositor.service
touch /etc/qopenhd-rpi/native-video-enabled
printf '{"run_mode":"ground","platform_type":13,"platform_name":"RPI 5"}\n' \
    > /usr/local/share/OpenHD/SysUtils/config.json
touch /boot/firmware/openhd/ground.txt /boot/firmware/openhd/rpi.txt /boot/firmware/openhd/rpi5.txt
mkdir -p /Config
if [[ ! -e /Config/openhd ]]; then ln -s /boot/firmware/openhd /Config/openhd; fi
if [[ ! -e /boot/openhd ]]; then ln -s firmware/openhd /boot/openhd; fi
cat > /etc/systemd/system/openhd.service.d/40-pi5-ground.conf <<'EOF'
[Unit]
Requires=openhd-sys-utils.service
After=openhd-sys-utils.service
[Service]
ExecStart=
ExecStart=/usr/local/bin/openhd --ground
StandardInput=null
StandardOutput=journal
StandardError=journal
EOF
cat > /etc/systemd/system/ssh.service.d/10-host-keys.conf <<'EOF'
[Service]
ExecStartPre=
ExecStartPre=/usr/bin/ssh-keygen -A
ExecStartPre=/usr/sbin/sshd -t
EOF
python3 - <<'PY'
from pathlib import Path
p = Path('/boot/firmware/config.txt')
s = p.read_text()
# Keep the stock Pi 5 firmware and KMS configuration; increase only its CMA pool.
s = s.replace('dtoverlay=vc4-kms-v3d\n', 'dtoverlay=vc4-kms-v3d,cma-512\n')
if 'dtoverlay=vc4-kms-v3d' not in s:
    s += '\n[all]\ndtoverlay=vc4-kms-v3d,cma-512\n'
if '#OPENHD_DYNAMIC_CONTENT_BEGIN#' not in s:
    s += '\n[all]\ncamera_auto_detect=0\nenable_uart=1\n#OPENHD_DYNAMIC_CONTENT_BEGIN#\n'
p.write_text(s)
p = Path('/boot/firmware/cmdline.txt')
options = p.read_text().strip().split()
options = [x for x in options if not x.startswith(('console=serial', 'console=ttyAMA', 'systemd.run=', 'systemd.run_success_action=', 'systemd.unit='))]
options += ['quiet', 'loglevel=3', 'vt.global_cursor_default=0']
p.write_text(' '.join(dict.fromkeys(options)) + '\n')
PY
id openhd >/dev/null 2>&1 || useradd -m -s /bin/bash openhd
echo 'openhd:openhd' | chpasswd
for group in sudo video render input dialout plugdev netdev; do
    if getent group "$group" >/dev/null; then usermod -aG "$group" openhd; fi
done
printf 'OpenHD-Ground\n' > /etc/hostname
sed -i 's/^127\.0\.1\.1.*/127.0.1.1\tOpenHD-Ground/' /etc/hosts
touch /etc/cloud/cloud-init.disabled
for unit in userconfig.service getty@tty1.service getty@tty7.service \
    display-manager.service weston.service openhd-video.service \
    openhd-glide.service openhd-glide-autostart.service openhd-glide-stream.service; do
    systemctl disable "$unit" 2>/dev/null || true
    systemctl mask "$unit" 2>/dev/null || true
done
systemctl set-default multi-user.target
systemctl enable openhd-sys-utils.service openhd.service ssh.service
# SysUtils starts QOpenHD in Ground mode; the compositor follows its dependency.
systemctl disable qopenhd.service 2>/dev/null || true
printf 'OpenHD Raspberry Pi 5 Ground / Raspberry Pi OS Trixie / Qt 6\n' > /etc/issue
