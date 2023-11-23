#!/bin/bash

# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image
# Here we do simple platform detection for OpenHD with creating a few folders


if [[ "${OS}" == "radxa-debian-rock5a" ]]; then
mkdir -p /usr/local/share/openhd_platform/rock/rock5a
elif [[ "${OS}" == "radxa-debian-rock5b" ]]; then
mkdir -p /usr/local/share/openhd_platform/rock/rock5b
elif [[ "${OS}" == "radxa-debian-rock-cm3" ]]; then
touch /boot/openhd/rock-rk3566.txt
elif [[ "${OS}" == "radxa-debian-rock-cm3-core3566" ]]; then
touch /boot/openhd/rock-rk3566.txt
elif [[ "${OS}" == "raspbian" ]]; then
mkdir -p /usr/local/share/openhd_platform/rpi/
elif [[ "${OS}" == "debian-X20" ]]; then
mkdir -p /usr/local/share/openhd_platform/x20
elif [[ "${OS}" == "ubuntu-x86" ]]; then
mkdir -p /usr/local/share/openhd_platform/x86
fi

