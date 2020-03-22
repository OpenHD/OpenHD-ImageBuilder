# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image

#!/bin/bash

# Remove bad and unnecessary symlinks 
rm /lib/modules/*/build || true
rm /lib/modules/*/source || true

if [ "${APT_CACHER_NG_ENABLED}" == "true" ]; then
    echo "Acquire::http::Proxy \"${APT_CACHER_NG_URL}/\";" >> /etc/apt/apt.conf.d/10cache
fi



apt-mark hold raspberrypi-bootloader
apt-mark hold raspberrypi-kernel

# Install kernel-headers before apt-get update
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install raspberrypi-kernel-headers

# Install libraspberrypi-dev before apt-get update
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libraspberrypi-dev libraspberrypi-dev libraspberrypi-bin libraspberrypi0
apt-mark hold libraspberrypi-dev libraspberrypi-bin libraspberrypi0

# Latest package source
# sudo rm -rf /var/lib/apt/lists/*
# sudo apt-get clean
sudo apt-get update

# Install essentials
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install python-pip python-setuptools python-dev python3-dev
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install aircrack-ng
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gnuplot
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install dnsmasq
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install socat
# DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install --assume-no wireshark-common
# DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install tshark
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install ser2net
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install mc

#DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gtk-doc-tools

DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install build-essential autotools-dev automake
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libtool
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install autoconf
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libsdl1.2-dev
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libconfig++-dev libreadline-dev
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install git libpcap-dev wiringpi iw usbmount
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libjpeg8-dev indent libfreetype6-dev ttf-dejavu-core
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install python-m2crypto
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install dos2unix
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install dosfstools
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install hostapd
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install pump
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libpng12-dev
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install python-future python-attr
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libfontconfig1-dev 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libsdl2-dev
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libsdl1.2-dev
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libav-tools
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install firmware-misc-nonfree

DEBIAN_FRONTEND=noninteractive sudo apt install -y libegl1-mesa libegl1-mesa-dev libgles2-mesa libgles2-mesa-dev libgbm-dev 


# text to speech for QOpenHD
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libspeechd-dev flite1-dev flite speech-dispatcher-flite --no-install-recommends

# dependencies for OpenHDMicroservice
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install build-essential git python libboost-dev libboost-program-options-dev libboost-system-dev libasio-dev

#Arducam Multi Camera Adapter Module V2.1
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install  i2c-tools

# v4l2loopback and flir dependencies NEED TO CHECK IF THEY ARE ALREADY INSTALLED
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install vim
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install fuse
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libusb-1.0-0-dev

# mavlink-router build dependencies
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install python3-future

# openhdvid dependency
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install python3-picamera

# install omxplayer. Used by SSync to display video
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install omxplayer


# installs all dependencies for these packages so Qt itself can be built from source
DEBIAN_FRONTEND=noninteractive sudo apt-get install build-essential \
                                                    libfontconfig1-dev libdbus-1-dev \
                                                    libfreetype6-dev libicu-dev libinput-dev \
                                                    libxkbcommon-dev libsqlite3-dev libssl-dev libpng-dev \
                                                    libjpeg-dev libglib2.0-dev \
                                                    libasound2-dev pulseaudio libpulse-dev

DEBIAN_FRONTEND=noninteractive sudo apt-get install libudev-dev libinput-dev libts-dev mtdev-tools
DEBIAN_FRONTEND=noninteractive sudo apt-get install libglib2.0-doc libdca0 libdvdnav4 libdvdread4 libfaad2 \
                                                    libilmbase12 libkate1 libmms0 libmodplug1 libmpcdec6 \
                                                    libopencv-calib3d2.4v5 libopencv-highgui2.4-deb0 libopencv-objdetect2.4v5 \
                                                    libopencv-video2.4v5 libopenexr22 liborc-0.4-0 libsbc1 libsoundtouch1 libspandsp2 \
                                                    libsrtp0 libvo-aacenc0 libvo-amrwbenc0 libwebrtc-audio-processing1 libwildmidi2 libzbar0 \
                                                    libcdparanoia0 libvisual-0.4-0 libtag1v5


# Remove packages that conflict with the workings of EZ-Wifibroadcast
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge wireless-regdb
# DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge wpasupplicant
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge crda
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge cron

#Untested Packages for possible removal
#DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge dbus
#DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge dhcpcd5
#DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge isc-dhcp-client
#DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge isc-dhcp-common


# Remove packages for space savings
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge apt-transport-https
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge aptitude
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge aptitude-common
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge apt-listchanges
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge avahi-daemon
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge cifs_utils
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge curl
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge iptables
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge triggerhappy


DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libgstreamer1.0-0
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-plugins-base 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-plugins-good 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-plugins-bad 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-plugins-ugly 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-libav 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-tools 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-alsa 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-pulseaudio
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-omx-rpi-config


# Python essentials for mavlink router autoconf
sudo pip install future
#Python3 GPIO
sudo apt-get -y install python3-rpi.gpio

# Clean Up
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq clean
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq autoremove

if [ ${APT_CACHER_NG_ENABLED} == "true" ]; then
    rm /etc/apt/apt.conf.d/10cache
fi
