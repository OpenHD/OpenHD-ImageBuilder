#!/bin/bash

apt update
apt-mark hold radxa-system-config-kernel-cmdline-ttyfiq0

mkdir -p /usr/share/sddm/themes/breeze/
touch /usr/share/sddm/themes/breeze/Main.qml
rm -Rf /etc/modprobe.d/panfrost.conf
apt remove -y radxa-sddm-theme

mkdir -p /etc/pulse/
touch /etc/pulse/default.pa
apt remove -y rockchip-pulseaudio-config

PLATFORM_PACKAGES_REMOVE="gstreamer1.0-gtk3 gstreamer1.0-libav gstreamer1.0-plugins-bad gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-rtp gstreamer1.0-plugins-ugly gstreamer1.0-qt5 gstreamer1.0-vaapi gvfs gvfs-backends gvfs-fuse mesa-utils mesa-va-drivers plymouth plymouth-theme-breeze plymouth-themes vdpau-driver-all vulkan-tools xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs xdg-user-dirs-gtk xdg-utils task-xfce-desktop thunar-volman xfce4-clipman xfce4-notifyd xfce4-power-manager xfce4-screenshooter xfce4-terminal xiccd aha breeze-cursor-theme clinfo codium cups desktop-base firefox-esr fonts-noto-cjk fprintd fwupd maliit-keyboard dnsmasq libllvm* firmware-misc-nonfree libmali-bifrost-g52-g2p0-x11-gbm adwaita-icon-theme firmware-brcm80211 network-manager libcairo2 libvulkan1 libgtk-3-common libcups2 libavcodec58 libavformat58 libavfilter7 libopencv* codium dkms plasma-desktop lightdm chromium"

for package in ${PLATFORM_PACKAGES_REMOVE}; do
    echo "Removing ${package}..."
    apt purge -y ${package}
    if [ $? -ne 0 ]; then
        echo "Failed to remove ${package}!"
        exit 1
    fi
done

wget -nv https://fra1.digitaloceanspaces.com/openhd-images/Downloader/release/2.6/OpenHD-image-radxa-zero3w--release-06-26-2024-00-28-55.img.xz
ls -a
unxz *.xz
rm -Rf *.xz
mv *.img /opt/additionalFiles/emmc.img

curl -1sLf 'https://dl.cloudsmith.io/public/openhd/release/setup.deb.sh' | sudo -E bash
sudo apt update
sudo apt install -y openhd-sys-utils

echo "openhd_emmc_util.sh flash debug" | sudo tee -a /etc/profile
sudo sed -i 's/^ExecStart=.*/ExecStart=-\/sbin\/agetty --autologin root --noclear %I $TERM/' /lib/systemd/system/getty@.service

echo "______________________--DONE-______________________"
