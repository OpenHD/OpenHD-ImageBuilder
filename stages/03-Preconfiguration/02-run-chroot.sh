#!/bin/bash

# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image
# Here we do simple platform detection for OpenHD with creating a few folders


# Generate buffer space to allow the user to add files or programs +1000mb
dd if=/dev/zero of=/opt/space.img bs=1M count=1024


rm -Rf /opt/additionalFiles
#echo "alias led='led_sys.sh'" | sudo tee -a /etc/bash.bashrc >/dev/null
sudo mkdir -p /ramdisk && echo "tmpfs /ramdisk tmpfs defaults,size=100M 0 0" | sudo tee -a /etc/fstab && sudo mount /ramdisk

if [[ "${OS}" == "radxa-debian-rock5a" ]]; then
mkdir -p /usr/local/share/openhd_platform/rock/rock5a
touch /boot/openhd/rock-5a.txt
elif [[ "${OS}" == "radxa-debian-rock5b" ]]; then
mkdir -p /usr/local/share/openhd_platform/rock/rock5b
touch /boot/openhd/rock-5b.txt
elif [[ "${OS}" == "radxa-debian-rock-cm3" ]]; then
touch /conf/openhd/rock-rk3566.txt
mkdir -p /usr/local/share/openhd/platform/rock/rk3566
touch /conf/openhd/resize.txt
elif [[ "${OS}" == "radxa-debian-rock-cm3-core3566" ]]; then
touch /conf/openhd/rock-rk3566.txt
touch /conf/openhd/resize.txt
elif [[ "${OS}" == "raspbian" ]]; then
mkdir -p /usr/local/share/openhd_platform/rpi/
echo "options 88x2eu_ohd rtw_regd_src=1 rtw_tx_pwr_by_rate=0 rtw_tx_pwr_lmt_enable=0" | sudo tee /etc/modprobe.d/realtek_88x2eu.conf > /dev/null
elif [[ "${OS}" == "debian-X20" ]]; then
mkdir -p /usr/local/share/openhd_platform/x20
mkdir -p /conf/openhd/Videos
touch /conf/openhd/Videos/external_video_part.txt
touch /conf/openhd/hardware_vtx_v20.txt
elif [[ "${OS}" == "ubuntu-x86" ]]; then
mkdir -p /usr/local/share/openhd_platform/x86
touch /conf/openhd/x86.txt
touch /conf/config.txt
fi

