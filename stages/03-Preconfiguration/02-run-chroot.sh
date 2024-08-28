#!/bin/bash

# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image
# Here we do simple platform detection for OpenHD with creating a few folders

rm -Rf /opt/additionalFiles
echo "alias led='led_sys.sh'" | sudo tee -a /etc/bash.bashrc >/dev/null


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

elif [[ "${OS}" == "debian-X20" ]]; then
mkdir -p /usr/local/share/openhd_platform/x20
mkdir -p /conf/openhd/Videos
touch /conf/openhd/Videos/external_video_part.txt
touch /conf/openhd/hardware_vtx_v20.txt
elif [[ "${OS}" == "ubuntu-x86" ]]; then
mkdir -p /usr/local/share/openhd_platform/x86
fi

