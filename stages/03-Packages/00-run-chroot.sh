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
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install raspberrypi-kernel-headers || exit 1

# Install libraspberrypi-dev before apt-get update
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libraspberrypi-dev libraspberrypi-dev libraspberrypi-bin libraspberrypi0 firmware-misc-nonfree || exit 1
apt-mark hold libraspberrypi-dev libraspberrypi-bin libraspberrypi0

# Latest package source
# sudo rm -rf /var/lib/apt/lists/*
# sudo apt-get clean
sudo apt-get update || exit 1

if [[ "${DISTRO}" == "stretch" ]]; then
    # on buster the gnuplot package pulls in 670MB of other stuff we don't want, it's a giant waste of space
    GNUPLOT="gnuplot"
fi

# Build tools
BUILD_TOOLS="git build-essential autotools-dev automake libtool autoconf"

# Libraries used by our own code
LIBRARIES="libpcap-dev libpng-dev libsdl2-dev libsdl1.2-dev libconfig++-dev libreadline-dev 
           libjpeg8-dev libusb-1.0-0-dev libsodium-dev"


# Python interpreters, we won't need python2 much longer
PYTHON2="python-pip python-dev python-setuptools"
PYTHON3="python3-pip python3-dev python3-setuptools"


# Python dependencies used by our own code
PYTHON2_DEPENDENCIES="python-future python-attr python-m2crypto python-rpi.gpio"
PYTHON3_DEPENDENCIES="python3-future python3-attr python3-picamera python3-rpi.gpio"


# Command line utilities used at runtime by the OpenHD scripts
SCRIPT_DEPENDENCIES="wiringpi usbmount ser2net i2c-tools fuse socat dos2unix dosfstools ffmpeg indent omxplayer"


FONT_SUPPORT="libfontconfig1-dev libfreetype6-dev ttf-dejavu-core"


NETWORK_UTILITIES="hostapd iw pump dnsmasq aircrack-ng"


DEVELOPMENT_UTILITIES="vim mc"


MESA_DRM_STACK="libegl1-mesa libegl1-mesa-dev libgles2-mesa libgles2-mesa-dev libgbm-dev"


MICROSERVICE_DEPENDENCIES="libboost-dev libboost-program-options-dev libboost-system-dev libasio-dev libboost-chrono-dev"

RC_DEPENDENCIES="libboost-regex-dev libboost-filesystem-dev libboost-thread-dev"

TEXTTOSPEECH_QOPENHD="libspeechd-dev flite1-dev flite speech-dispatcher-flite"


QT_DEPENDENCIES="libfontconfig1-dev libdbus-1-dev libfreetype6-dev libicu-dev libinput-dev libxkbcommon-dev
                 libsqlite3-dev libssl-dev libpng-dev libjpeg8-dev libglib2.0-dev libasound2-dev pulseaudio
                 libpulse-dev libdouble-conversion-dev libudev-dev libinput-dev libts-dev mtdev-tools"


GSTREAMER="libgstreamer1.0-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
           gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-alsa gstreamer1.0-pulseaudio
           gstreamer1.0-omx-rpi-config"


PURGE="wireless-regdb crda cron apt-transport-https aptitude aptitude-common apt-listchanges
       avahi-daemon cifs-utils curl iptables triggerhappy"


DEBIAN_FRONTEND=noninteractive sudo apt-get -y --no-install-recommends install \
${BUILD_TOOLS} \
${LIBRARIES} \
${PYTHON2} \
${PYTHON3} \
${PYTHON2_DEPENDENCIES} \
${PYTHON3_DEPENDENCIES} \
${SCRIPT_DEPENDENCIES} \
${FONT_SUPPORT} \
${NETWORK_UTILITIES} \
${DEVELOPMENT_UTILITIES} \
${MESA_DRM_STACK} \
${MICROSERVICE_DEPENDENCIES} \
${RC_DEPENDENCIES} \
${TEXTTOSPEECH_QOPENHD} \
${QT_DEPENDENCIES} \
${GSTREAMER} ${GNUPLOT} || exit 1

DEBIAN_FRONTEND=noninteractive sudo apt-get -yq purge ${PURGE} || exit 1

DEBIAN_FRONTEND=noninteractive sudo apt-get -yq clean || exit 1
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq autoremove || exit 1

if [ ${APT_CACHER_NG_ENABLED} == "true" ]; then
    rm /etc/apt/apt.conf.d/10cache
fi
