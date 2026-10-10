#!/usr/bin/env bash
# Raspberry Pi 2/3/4 EGLFS images only; do not replace the Pi 5/Glide boot path.
set -euo pipefail
[[ "${OS:-}" == "raspbian" && "${RPI5:-false}" != "true" ]] || exit 0
# The new QOpenHD binary owns the Plymouth-to-EGLFS handoff. An older package
# would leave Plymouth holding the display, so fail rather than produce that image.
if ! grep -a -q 'QOpenHD startup splash: early first frame' /usr/local/bin/QOpenHD; then
    echo 'The Raspberry Pi splash requires the current QOpenHD startup-video package.' >&2
    exit 1
fi
assets=$(cd "$(dirname "$0")/openhd-splash" && pwd)
apt-get install -y --no-install-recommends plymouth plymouth-themes gstreamer1.0-libav
install -d /usr/share/plymouth/themes/openhd
install -m 0644 "$assets"/* /usr/share/plymouth/themes/openhd/
plymouth-set-default-theme openhd

# Avoid writing the dashboard over the splash. The interactive console remains
# available when OpenHD is launched manually; service diagnostics go to journald.
install -d /etc/systemd/system/openhd.service.d /etc/systemd/system/qopenhd.service.d
cat >/etc/systemd/system/openhd.service.d/20-boot-splash.conf <<'EOF'
[Service]
# Air units have no QOpenHD process to release the splash.
ExecStartPre=-/bin/sh -c 'if [ -f /Config/openhd/air.txt ]; then /usr/bin/plymouth quit --retain-splash; fi'
StandardInput=null
StandardOutput=journal
StandardError=journal
TTYReset=no
TTYVHangup=no
TTYVTDisallocate=no
EOF
cat >/etc/systemd/system/qopenhd.service.d/20-boot-splash.conf <<'EOF'
[Unit]
Wants=plymouth-start.service
After=plymouth-start.service

# QOpenHD releases Plymouth immediately before opening its EGLFS window.
# Keeping the daemon alive until then avoids a black pre-initialization gap.
EOF

# Initialize the real display before Plymouth selects a renderer. Starting on
# firmware simplefb would lose the splash when vc4 replaces that framebuffer.
install -d /etc/systemd/system/plymouth-start.service.d
cat >/etc/systemd/system/plymouth-start.service.d/20-openhd-display.conf <<'EOF'
[Service]
ExecStartPre=-/sbin/modprobe vc4
EOF

# A daemon splash must never block multi-user.target or wait for a display manager.
systemctl unmask plymouth-start.service plymouth-read-write.service
systemctl mask plymouth-quit.service plymouth-quit-wait.service
install -d /etc/systemd/system/sysinit.target.wants
ln -sf /lib/systemd/system/plymouth-start.service /etc/systemd/system/sysinit.target.wants/plymouth-start.service

# The stock Pi image boots without an initrd. Start Plymouth in early userspace;
# quiet the preceding firmware/kernel output without introducing an initrd delay.
python3 - <<'PY'
from pathlib import Path
p = Path('/boot/cmdline.txt')
tokens = p.read_text().split()
tokens = [t for t in tokens if t not in ('console=tty1', 'console=tty3')
          and not t.startswith(('loglevel=', 'systemd.show_status=', 'vt.global_cursor_default='))]
for t in ('console=tty3', 'quiet', 'splash', 'plymouth.ignore-serial-consoles', 'loglevel=3', 'logo.nologo',
          'systemd.show_status=false', 'vt.global_cursor_default=0'):
    if t not in tokens:
        tokens.append(t)
p.write_text(' '.join(tokens) + '\n')
p = Path('/boot/config.txt')
s = p.read_text()
if '# OpenHD boot splash' not in s:
    block = '# OpenHD boot splash\ndisable_splash=1\n'
    if '#OPENHD_DYNAMIC_CONTENT_BEGIN#' in s:
        s = s.replace('#OPENHD_DYNAMIC_CONTENT_BEGIN#', block + '#OPENHD_DYNAMIC_CONTENT_BEGIN#', 1)
    else:
        s += '\n[all]\n' + block
    p.write_text(s)
PY

# ImageWriter may restore these boot flags only when runtime support is bundled.
printf '1\n' > /boot/openhd-boot-splash.version
