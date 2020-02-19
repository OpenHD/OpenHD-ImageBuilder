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
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install python-pip
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install aircrack-ng
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gnuplot
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install dnsmasq
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install socat
# DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install --assume-no wireshark-common
# DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install tshark
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install ser2net
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install mc

#DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gtk-doc-tools

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
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install firmware-misc-nonfree

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

# gstreamer 1.16.1 dependencies for QOpenHD
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install build-essential autotools-dev automake autoconf \
                                    libtool autopoint libxml2-dev zlib1g-dev libglib2.0-dev \
                                    pkg-config bison flex python3 git gtk-doc-tools libasound2-dev \
                                    libgudev-1.0-dev libxt-dev libvorbis-dev libcdparanoia-dev \
                                    libpango1.0-dev libtheora-dev libvisual-0.4-dev iso-codes \
                                    libgtk-3-dev libraw1394-dev libiec61883-dev libavc1394-dev \
                                    libv4l-dev libcairo2-dev libcaca-dev libspeex-dev libpng-dev \
                                    libshout3-dev libjpeg-dev libaa1-dev libflac-dev libdv4-dev \
                                    libtag1-dev libwavpack-dev libpulse-dev libsoup2.4-dev libbz2-dev \
                                    libcdaudio-dev libdc1394-22-dev ladspa-sdk libass-dev \
                                    libcurl4-gnutls-dev libdca-dev libdirac-dev libdvdnav-dev \
                                    libexempi-dev libexif-dev libfaad-dev libgme-dev libgsm1-dev \
                                    libiptcdata0-dev libkate-dev libmimic-dev libmms-dev \
                                    libmodplug-dev libmpcdec-dev libofa0-dev libopus-dev \
                                    librsvg2-dev librtmp-dev libschroedinger-dev libslv2-dev \
                                    libsndfile1-dev libsoundtouch-dev libspandsp-dev \
                                    libxvidcore-dev libzbar-dev libzvbi-dev liba52-0.7.4-dev \
                                    libcdio-dev libdvdread-dev libmad0-dev libmp3lame-dev \
                                    libmpeg2-4-dev libopencore-amrnb-dev libopencore-amrwb-dev \
                                    libsidplay1-dev libtwolame-dev libx264-dev libusb-1.0 \
                                    python-gi-dev yasm python3-dev libgirepository1.0-dev \
                                    libopencv-dev libde265-0 libfluidsynth1 liblilv-0-0 libmjpegutils-2.1-0 \
                                    libmpeg2encpp-2.1-0 libmplex2-2.1-0 libsbc1 libvo-aacenc0 libvo-amrwbenc0 \
                                    libvulkan1 libwebrtc-audio-processing1 libwildmidi-dev libbs2b0 libopenal1

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


# we build a newer version of gstreamer with the qmlglsink element enabled, which raspbian packages don't have
DEBIAN_FRONTEND=noninteractive sudo apt-get purge -y '*gstreamer*'

wget https://github.com/OpenHD/gst-raspberrypi/releases/download/${GSTREAMER_VERSION}/GStreamer-${GSTREAMER_VERSION}.tar.gz

tar xvf GStreamer-${GSTREAMER_VERSION}.tar.gz

dpkg -i GStreamer-${GSTREAMER_VERSION}/*.deb  || exit 1

rm GStreamer-${GSTREAMER_VERSION}.tar.gz || true

rm -rf GStreamer-${GSTREAMER_VERSION} || true

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
