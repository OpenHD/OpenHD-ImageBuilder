# # This runs in context if the image (CHROOT)
# # Do not use log here, it will end up in the image
# # This stage will install and remove packages which are required to get OpenHD to work
# # If anything fails here the script is failing!
#!/bin/bash

set -e

# Raspbian-specific code
function install_raspbian_packages {
    PLATFORM_PACKAGES_HOLD="firmware-atheros raspberrypi-kernel libraspberrypi-dev libraspberrypi-bin libraspberrypi0 libraspberrypi-doc"
    PLATFORM_PACKAGES_REMOVE="nfs-common libcamera* raspberrypi-kernel"
    PLATFORM_PACKAGES="apt-transport-https git apt-utils firmware-atheros firmware-misc-nonfree open-hd-web-ui openhd-userland openhd-linux-pi openhd-linux-pi-headers libsdl2-dev libspdlog-dev libcamera-openhd libcamera-apps-openhd libavcodec-dev libavformat-dev mavsdk gstreamer1.0-gl gst-latest openhd-qt openhd qopenhd libsodium-dev libpcap-dev git nano openssh-server libboost-filesystem1.74-dev meson"
}
# Debian-Rockship-specific code
function fix_radxa_apt {
    wget -O - apt.radxa.com/bullseye-stable/public.key | apt-key add -
    apt update
}
function install_debian_packages {
    PLATFORM_PACKAGES_HOLD="linux-image-5.10.66-27-rockchip linux-5.10-rock-5-latest"
    PLATFORM_PACKAGES="apt-transport-https git apt-utils openhd qopenhd rtl8812au-autocompiler procps git cmake dkms"
}
# Ubuntu-x86-specific code
function install_ubuntu_x86_packages {
    PLATFORM_PACKAGES_HOLD="linux-image-5.15.0-57-generic hold grub-efi-amd64-signed linux-generic linux-headers-generic linux-image-generic linux-generic-hwe-22.04 linux-image-generic-hwe-22.04 linux-headers-generic-hwe-22.04"
    PLATFORM_PACKAGES="apt-transport-https git apt-utils git openhdimagewriter nano python3-pip htop libavcodec-dev libavformat-dev libelf-dev libboost-filesystem-dev openhd libspdlog-dev openhd-qt-x86-jammy qopenhd build-essential libfontconfig1-dev libdbus-1-dev libfreetype6-dev libicu-dev libinput-dev libxkbcommon-dev libsqlite3-dev libssl-dev libpng-dev libjpeg-dev libglib2.0-dev libgles2-mesa-dev libgbm-dev libdrm-dev libwayland-dev pulseaudio libpulse-dev flex bison gperf libre2-dev libnss3-dev libdrm-dev libxml2-dev libxslt1-dev libminizip-dev libjsoncpp-dev liblcms2-dev libevent-dev libprotobuf-dev protobuf-compiler '^libxcb.*-dev' libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev libxkbcommon-x11-dev libgtk2.0-dev libgtk-3-dev libfuse2 mono-complete mono-runtime libmono-system-windows-forms4.0-cil libmono-system-core4.0-cil libmono-system-management4.0-cil libmono-system-xml-linq4.0-cil libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly gstreamer1.0-plugins-bad libgstreamer-plugins-bad1.0-dev gstreamer1.0-pulseaudio gstreamer1.0-tools gstreamer1.0-alsa gstreamer1.0-qt5"
}

# Ubuntu-Jetson-specific code
function fix_jetson_apt {
         rm /etc/apt/sources.list.d/nvidia-l4t-apt-source.list || true
         echo "deb https://repo.download.nvidia.com/jetson/common r32.6 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source2.list
         echo "deb https://repo.download.nvidia.com/jetson/t210 r32.6 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
         sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
         sudo add-apt-repository ppa:mhier/libboost-latest -y
         sudo add-apt-repository ppa:git-core/ppa -y
         apt update
}
function install_jetson_packages {
    PLATFORM_PACKAGES_REMOVE="libreoffice* gnome-applet* gnome-bluetooth gnome-desktop* gnome-sessio* gnome-user* gnome-shell-common gnome-control-center gnome-screenshot ubuntu-release-upgrader-gtk ubuntu-web-launchers unity-settings-daemon packagekit wamerican mysql-common libgdm1 vlc-data lightdm ubuntu-artwork ubuntu-sounds ubuntu-wallpapers ubuntu-wallpapers-bionic ubuntu-desktop gdm3 gnome-* libreoffice-writer chromium-browser chromium* yelp unity thunderbird rhythmbox nautilus gnome-software"
    PLATFORM_PACKAGES="apt-transport-https git apt-utils nano mingetty libgstreamer-plugins-base1.0-dev python-pip libelf-dev libboost1.74-dev openhd-linux-jetson openhd"
}

function clone_github_repos {
    cd /opt
    git clone --recursive https://github.com/OpenHD/OpenHD
    git clone --recursive https://github.com/OpenHD/QOpenHD
    chmod -R 777 /opt
}

# Main function
 if [[ "${OS}" == "raspbian" ]]; then
    install_raspbian_packages
 elif [[ "${OS}" == "debian" ]] ; then
    fix_radxa_apt
    install_debian_packages
 elif [[ "${OS}" == "ubuntu-x86" ]] ; then
    install_ubuntu_x86_packages
 elif [[ "${OS}" == "ubuntu" ]] ; then
    fix_jetson_apt
    install_jetson_packages
 fi

 # Add OpenHD Repository platform-specific packages
 apt install -y curl
 curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-3-evo/setup.deb.sh'| sudo -E bash
 apt update


 # Remove platform-specific packages
 echo "Removing platform-specific packages..."
 for package in ${PLATFORM_PACKAGES_REMOVE}; do
     echo "Removing ${package}..."
     apt purge -y ${package}
     if [ $? -ne 0 ]; then
         echo "Failed to remove ${package}!"
         exit 1
     fi
 done

 # Hold platform-specific packages
 echo "Holding back platform-specific packages..."
 for package in ${PLATFORM_PACKAGES_HOLD}; do
     echo "Holding ${package}..."
     apt-mark hold ${package}
     if [ $? -ne 0 ]; then
         echo "Failed to remove ${package}!"
         exit 1
     fi
 done

 # Install platform-specific packages
 echo "Installing platform-specific packages..."
 for package in ${PLATFORM_PACKAGES}; do
     echo "Installing ${package}..."
     apt install -y -o Dpkg::Options::="--force-overwrite" --no-install-recommends ${package}
     if [ $? -ne 0 ]; then
         echo "Failed to install ${package}!"
         exit 1
     fi
 done

 # Clean up packages and cache
 echo "Cleaning up packages and cache..."
 apt autoremove -y
 apt clean
 rm -rf /var/lib/apt/lists/*
 rm -rf /var/cache/apt/archives/*
 rm -rf /usr/share/doc/*
 rm -rf /usr/share/man/*

#
# Write the openhd package version back to the base of the image and
# in the work dir so the builder can use it in the image name
export OPENHD_VERSION=$(dpkg -s openhd | grep "^Version" | awk '{ print $2 }')

echo ${OPENHD_VERSION} > /openhd_version.txt
echo ${OPENHD_VERSION} > /boot/openhd_version.txt
