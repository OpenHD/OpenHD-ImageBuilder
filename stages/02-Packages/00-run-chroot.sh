# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image

#!/bin/bash
if [[ "${OS}" != "ubuntu" ]]; then
    # Remove bad and unnecessary symlinks if system is not ubuntu
    rm /lib/modules/*/build || true
    rm /lib/modules/*/source || true
fi


if [ "${APT_CACHER_NG_ENABLED}" == "true" ]; then
    echo "Acquire::http::Proxy \"${APT_CACHER_NG_URL}/\";" >> /etc/apt/apt.conf.d/10cache
fi

if [[ "${LEGACY}" == true ]]; then
    echo "This is a TEST"
    exit
else
    echo $LEGACY
    exit
fi

if [[ "${OS}" == "raspbian" ]]; then
    echo "OS is raspbian"
    mkdir -p /home/openhd
    chown openhd:openhd /home/openhd
    apt-mark hold firmware-atheros || exit 1
    apt purge firmware-atheros || exit 1
    apt -yq install firmware-misc-nonfree || exit 1
    apt-mark hold raspberrypi-kernel
    # Install libraspberrypi-dev before apt-get update
    DEBIAN_FRONTEND=noninteractive apt -yq install libraspberrypi-doc libraspberrypi-dev libraspberrypi-dev libraspberrypi-bin libraspberrypi0 || exit 1
    apt-mark hold libraspberrypi-dev libraspberrypi-bin libraspberrypi0 libraspberrypi-doc libcamera-apps-lite
    apt purge raspberrypi-kernel
    apt remove nfs-common
    PLATFORM_PACKAGES="openhd-linux-pi mavsdk gst-plugins-good openhd-qt-pi-bullseye qopenhd libsodium-dev libpcap-dev git nano libcamera0 openssh-server libboost1.74-dev libboost-thread1.74-dev meson"
fi


if [[ "${OS}" == "armbian" ]]; then
    echo "OS is armbian"
    PLATFORM_PACKAGES=""
fi


if [[ "${OS}" == "ubuntu" ]]; then
    echo "OS is ubuntu"

    rm /etc/apt/sources.list.d/nvidia-l4t-apt-source.list || true
    echo "deb https://repo.download.nvidia.com/jetson/common r32.6 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source2.list
    echo "deb https://repo.download.nvidia.com/jetson/t210 r32.6 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source.list

    echo "update gcc and libboost to something usable"
    sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
    sudo add-apt-repository ppa:mhier/libboost-latest -y
    sudo add-apt-repository ppa:git-core/ppa -y
    
    #clean up jetson-image
    sudo apt remove ubuntu-desktop
    sudo apt remove libreoffice-writer chromium-browser chromium* yelp unity thunderbird rhythmbox nautilus gnome-software
    sudo apt remove ubuntu-artwork ubuntu-sounds ubuntu-wallpapers ubuntu-wallpapers-bionic
    sudo apt remove vlc-data lightdm
    sudo apt remove unity-settings-daemon packagekit wamerican mysql-common libgdm1
    sudo apt remove ubuntu-release-upgrader-gtk ubuntu-web-launchers
    sudo apt remove --purge libreoffice* gnome-applet* gnome-bluetooth gnome-desktop* gnome-sessio* gnome-user* gnome-shell-common gnome-control-center gnome-screenshot
    sudo apt autoremove
    
    PLATFORM_PACKAGES="openhd-linux-jetson gstreamer1.0-qt5 openhd-qt-jetson-nano-bionic qopenhd "

fi


if [[ "${HAS_CUSTOM_KERNEL}" == "true" ]]; then
    echo "-----------------------has a custom kernel----------------------------------"
    PLATFORM_PACKAGES="${PLATFORM_PACKAGES}"
fi

echo "-------------------------GETTING FIRST UPDATE------------------------------------"

apt update --allow-releaseinfo-change || exit 1  
echo "-------------------------Debug-Consti;)------------------------------------------"

mkdir -p /home/consti10/openhd

if [[ "${OS}" == "raspbian" ]]; then
    echo "OS is raspbian"
fi

apt install -y apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-1/cfg/gpg/gpg.0AD501344F75A993.key' | apt-key add -
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-1-testing/cfg/gpg/gpg.58A6C96C088A96BF.key' | apt-key add -
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-1-alpha/gpg.9D1C80E55B50390B.key' | apt-key add -
sudo apt-get install -y apt-utils

if [[ "${TESTING}" == "testing" ]]; then
    echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1-testing/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1-testing.list
    echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1.list
elif [[ "${TESTING}" == "milestone" ]]; then
    echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1-alpha/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1-testing.list
    echo "cloning Qopenhd and Openhd github repositories"
    cd /opt
    git clone --recursive https://github.com/OpenHD/Open.HD
    git checkout 2.1-milestones
    git clone --recursive https://github.com/OpenHD/QOpenHD
    git checkout 2.1-milestones
    echo "installing build dependencies"
    bash /opt/QOpenHD/install_dep.sh 
    bash /opt/Open.HD/install_dep.sh 

else
    echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1.list
fi

echo "-------------------------GETTING SECOND UPDATE------------------------------------"

apt update --allow-releaseinfo-change || exit 1

echo "-------------------------DONE GETTING SECOND UPDATE------------------------------------"
echo "Purge packages that interfer/we dont need..."

PURGE="wireless-regdb avahi-daemon curl iptables man-db logrotate"

export DEBIAN_FRONTEND=noninteractive

echo "install openhd version-${OPENHD_PACKAGE}"
if [[ "${OS}" == "ubuntu" ]]; then
    sudo apt install -y git nano python-pip libelf-dev 
    sudo -H pip install -U jetson-stats
fi

apt update && apt upgrade -y
apt -y -o Dpkg::Options::="--force-overwrite" --no-install-recommends install \
${OPENHD_PACKAGE} \
${PLATFORM_PACKAGES} \
${GNUPLOT} || exit 1

echo "-------------------------INSTALL QT-PATCHES-------------------------------"
#linking QT and it's libraries so the system can detect them
            touch /etc/ld.so.conf.d/qt.conf
            echo "/opt/Qt5.15.4/lib/" >/etc/ld.so.conf.d/qt.conf
            sudo ldconfig
            export PATH="$PATH:/opt/Qt5.15.4/bin/"
            cd /usr/bin
            sudo ln -s /opt/Qt5.15.4/bin/qmake qmake

apt -yq purge ${PURGE} || exit 1
apt -yq clean || exit 1
apt -yq autoremove || exit 1

if [ ${APT_CACHER_NG_ENABLED} == "true" ]; then
    rm /etc/apt/apt.conf.d/10cache
fi


MNT_DIR="${STAGE_WORK_DIR}/mnt"

#
# Write the openhd package version back to the base of the image and
# in the work dir so the builder can use it in the image name
export OPENHD_VERSION=$(dpkg -s openhd | grep "^Version" | awk '{ print $2 }')

echo ${OPENHD_VERSION} > /openhd_version.txt
echo ${OPENHD_VERSION} > /boot/openhd_version.txt
