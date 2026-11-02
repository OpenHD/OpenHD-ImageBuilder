#!/bin/bash
# Executed inside the Pi 5 Trixie image, with service startup inhibited.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
curl -fsSL --retry 4 https://dl.cloudsmith.io/public/openhd/dev-release/gpg.key \
    -o /usr/share/keyrings/openhd-dev-release.asc
# OpenHD's portable arm64 packages are published against Bookworm. Only this
# OpenHD feed uses Bookworm; Raspberry Pi OS and Debian remain on Trixie.
printf '%s\n' 'deb [arch=arm64 signed-by=/usr/share/keyrings/openhd-dev-release.asc] https://dl.cloudsmith.io/public/openhd/dev-release/deb/raspbian bookworm main' \
    > /etc/apt/sources.list.d/openhd.list
# The existing Web UI package requires ICU 72. Install that parallel runtime
# from Debian's signed Bookworm archive, with all other Bookworm packages pinned out.
printf '%s\n' 'deb [arch=arm64 signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian bookworm main' \
    > /etc/apt/sources.list.d/openhd-compat.list
cat > /etc/apt/preferences.d/openhd-compat <<'EOF'
Package: *
Pin: release o=Debian,n=bookworm
Pin-Priority: -1

Package: libicu72 libpcre3 librtlsdr0
Pin: release o=Debian,n=bookworm
Pin-Priority: 500
EOF
apt-get update
apt-get install -y --no-install-recommends openhd openhd-sys-utils open-hd-web-ui libpcre3 librtlsdr0 \
    gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly libsdl2-2.0-0 \
    libusb-1.0-0 iw wireless-tools rfkill usb-modeswitch ethtool wireguard-tools \
    iproute2 sudo openssh-server dosfstools parted
mkdir -p /usr/share/openhd
dpkg-query -W -f='${Package}=${Version}\n' openhd openhd-sys-utils open-hd-web-ui \
    > /usr/share/openhd/image-components.txt
