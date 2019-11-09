# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image

#!/bin/bash

# Remove bad and unnecessary symlinks 
rm /lib/modules/4.14.71*/build
rm /lib/modules/4.14.71*/source

# Install kernel-headers before apt-get update
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install raspberrypi-kernel-headers

# Latest package source
# sudo rm -rf /var/lib/apt/lists/*
# sudo apt-get clean
sudo apt-get update

# Install essentials
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install python-pip
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install aircrack-ng
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gnuplot
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install dnsmasq
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install socat
# DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install --assume-no wireshark-common
# DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install tshark
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install ser2net
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install mc

DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libgstreamer1.0-0
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-plugins-base 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-plugins-good 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-plugins-bad 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-plugins-ugly 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-libav 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-tools 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-x 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-alsa 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-gl 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-gtk3 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-qt5 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-pulseaudio
#DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gtk-doc-tools
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-omx-rpi-config

DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libtool
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install autoconf
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libsdl1.2-dev
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libboost-all-dev cmake libconfig++-dev libreadline-dev
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

#Arducam Multi Camera Adapter Module V2.1
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install  i2c-tools

# v4l2loopback and flir dependencies NEED TO CHECK IF THEY ARE ALREADY INSTALLED
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install vim
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install fuse
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libusb-1.0-0-dev

# install omxplayer. Used by SSync to display video
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install omxplayer


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

# Clean Up
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq autoremove

# Python essentials for mavlink router autoconf
sudo pip install future
#Python3 GPIO
sudo apt-get -y install python3-rpi.gpio
