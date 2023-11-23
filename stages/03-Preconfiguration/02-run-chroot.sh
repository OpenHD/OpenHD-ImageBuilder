#!/bin/bash

# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image
# Here we do simple platform detection for OpenHD with creating a few folders

#check for QOpenHD config file
echo "___________________________________"
echo "_______________debug_______________"
ls /root/.config/OpenHD
ls /root/.config/OpenHD/qopenhd


if [[ "${OS}" == "radxa-debian-rock5a" ]]; then
mkdir -p /usr/local/share/openhd_platform/rock/rock5a
elif [[ "${OS}" == "radxa-debian-rock5b" ]]; then
mkdir -p /usr/local/share/openhd_platform/rock/rock5b
elif [[ "${OS}" == "radxa-debian-rock-cm3" ]]; then
mkdir -p /usr/local/share/openhd_platform/rock/rk3566
elif [[ "${OS}" == "radxa-debian-rock-cm3-core3566" ]]; then
mkdir -p /usr/local/share/openhd_platform/rock/rk3566
elif [[ "${OS}" == "raspbian" ]]; then
mkdir -p /usr/local/share/openhd_platform/rpi/
elif [[ "${OS}" == "debian-X20" ]]; then
mkdir -p /usr/local/share/openhd_platform/x20
elif [[ "${OS}" == "ubuntu-x86" ]]; then
mkdir -p /usr/local/share/openhd_platform/x86
fi

