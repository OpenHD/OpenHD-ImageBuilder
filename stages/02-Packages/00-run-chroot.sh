# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image
# This stage will install and remove packages which are required to get OpenHD to work

#!/bin/bash
if [[ "${OS}" != "ubuntu" ]]; then
    # Remove bad and unnecessary symlinks if system is not ubuntu
    rm /lib/modules/*/build || true
    rm /lib/modules/*/source || true
fi

if [[ "${OS}" == "raspbian" ]] || [[ "${OS}" == "raspbian-legacy" ]]; then
    echo "OS is raspbian"
    # Remove atheros firmware, which will be replaced by our kernel, hold raspberry kernel, so it will not be updated anymore
    mkdir -p /home/openhd
    apt purge -y firmware-atheros || exit 1
    apt-mark hold firmware-atheros || exit 1
    apt -yq install firmware-misc-nonfree || exit 1
    apt-mark hold raspberrypi-kernel
    # Install libraspberrypi-dev before apt-get update
    #Remove current kernel and nfs(bloat)
    DEBIAN_FRONTEND=noninteractive apt -yq install libraspberrypi-doc libraspberrypi-dev libraspberrypi-dev libraspberrypi-bin libraspberrypi0 || exit 1
    apt-mark hold libraspberrypi-dev libraspberrypi-bin libraspberrypi0 libraspberrypi-doc libcamera-apps-lite
    apt purge -y raspberrypi-kernel
    apt remove -y nfs-common
        if [[ "${OS}" == "raspbian" ]]; then
        echo "Enabling h265 Hardware Decoding"
        #list packages which will be installed later in Second update
        PLATFORM_PACKAGES="openhd-linux-pi mavsdk gst-plugins-good openhd-qt-pi-bullseye qopenhd libsodium-dev libpcap-dev git nano libcamera0 openssh-server libboost1.74-dev libboost-thread1.74-dev meson"
        #libcamera may fail, since it isn't really supported yet
        else
        echo "Building legacy Version"
        echo "Disabling h265 Hardware Decoding"
        #list packages which will be installed later in Second update
        PLATFORM_PACKAGES="openhd-linux-pi mavsdk gst-plugins-good openhd-qt-pi-bullseye-legacy qopenhd libsodium-dev libpcap-dev git nano libcamera0 openssh-server libboost1.74-dev libboost-thread1.74-dev meson"
        #libcamera may fail, since it isn't really supported yet
            #the only difference currently is that a different build qt needs to be installed
        OS="raspbian" 
        echo "after this we'll do everything like on normal"
        echo ${OS}
        fi
fi
    if [[ "${OS}" == "ubuntu" ]]; then
        echo "OS is ubuntu"
        #The version we use as Base has messed up sources (by nvidia), we're correcting this now
        rm /etc/apt/sources.list.d/nvidia-l4t-apt-source.list || true
        echo "deb https://repo.download.nvidia.com/jetson/common r32.6 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source2.list
        echo "deb https://repo.download.nvidia.com/jetson/t210 r32.6 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
        echo "update gcc and libboost to something usable"
        #Since about everything on Jetson is not updated for ages and we need more modern build tools we'll add repositories which supply the right packages.
        sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
        sudo add-apt-repository ppa:mhier/libboost-latest -y
        sudo add-apt-repository ppa:git-core/ppa -y
        #clean up jetson-image, to decrease the size, this step is optional
        sudo apt remove -y ubuntu-desktop gdm3
        sudo apt-get purge -y gnome-*
        sudo apt remove -y libreoffice-writer chromium-browser chromium* yelp unity thunderbird rhythmbox nautilus gnome-software
        sudo apt remove -y ubuntu-artwork ubuntu-sounds ubuntu-wallpapers ubuntu-wallpapers-bionic
        sudo apt remove -y vlc-data lightdm
        sudo apt remove -y unity-settings-daemon packagekit wamerican mysql-common libgdm1
        sudo apt remove -y ubuntu-release-upgrader-gtk ubuntu-web-launchers
        sudo apt remove -y --purge libreoffice* gnome-applet* gnome-bluetooth gnome-desktop* gnome-sessio* gnome-user* gnome-shell-common gnome-control-center gnome-screenshot
        sudo apt autoremove -y
        #list packages which will be installed later in Second update
        PLATFORM_PACKAGES="openhd-linux-jetson gstreamer1.0-qt5 openhd-qt-jetson-nano-bionic qopenhd nano python-pip libelf-dev"
fi



if [[ "${HAS_CUSTOM_KERNEL}" == "true" ]]; then
    echo "-----------------------has a custom kernel----------------------------------"
    #Just linking the packages above to the variable
    PLATFORM_PACKAGES="${PLATFORM_PACKAGES}"
fi

echo "-------------------------GETTING FIRST UPDATE------------------------------------"

apt update --allow-releaseinfo-change || exit 1  
echo "-------------------------Debug-Consti;)------------------------------------------"

if [[ "${OS}" == "raspbian" ]]; then
    echo "OS is raspbian"
fi
#Include our own repository-keys and add dependencies for the install-script of cloudsmith
apt install -y apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-1/cfg/gpg/gpg.0AD501344F75A993.key' | apt-key add -
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-1-testing/cfg/gpg/gpg.58A6C96C088A96BF.key' | apt-key add -
sudo apt-get install -y apt-utils

#We use different repositories for milestone and testing branches, milestone includes ALL needed files and have everything build exactly for milestone images
if [[ "${TESTING}" == "testing" ]]; then
    echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1-testing/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1-testing.list
    echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1.list
elif [[ "${TESTING}" == "evo" ]]; then
    curl -1sLf \
    'https://dl.cloudsmith.io/public/openhd/openhd-2-2-evo/setup.deb.sh' \
    | sudo -E bash
    echo "cloning Qopenhd and Openhd github repositories"
    #For development ease we clone the most important repositories and install all their dependencies
    cd /opt
    apt install git
    git clone --recursive https://github.com/OpenHD/Open.HD
    cd Open.HD
    git checkout 2.1-milestones
    cd /opt
    git clone --recursive https://github.com/OpenHD/QOpenHD
    cd QOpenHD
    git checkout 2.1-milestones
    cd /opt
    echo "installing build dependencies"
    bash /opt/QOpenHD/install_dep.sh 
    bash /opt/Open.HD/install_dep.sh 

    #Raspi-OS does not include the videocore libraries, so we need to install and link them to get rpi(legacy) to start EGLFS (does not hurt pi4 and up)
    git clone --depth=1 https://github.com/OpenHD/rpi-firmware
    cd rpi-firmware
    cp -r opt/vc /opt/vc
    cd /opt
    sudo ln -s /opt/vc/lib/libbrcmGLESv2.so /usr/lib/arm-linux-gnueabihf/libbrcmGLESv2.so
    sudo ln -s /opt/vc/lib/libbrcmEGL.so /usr/lib/arm-linux-gnueabihf/libbrcmEGL.so 
    echo "linked broadcom EGL libraries"


else
    #if no milestone or testing is build, just write the standart openhd-source 
    echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1.list
fi

echo "-------------------------GETTING SECOND UPDATE------------------------------------"
#after getting our repositories inside the image we need to apply them and update the sources
apt update --allow-releaseinfo-change || exit 1

echo "-------------------------DONE GETTING SECOND UPDATE------------------------------------"
echo "Purge packages that interfer/we dont need..."

#write packages that will be removed into PURGE
PURGE="wireless-regdb avahi-daemon curl iptables man-db logrotate"

#this is needed, so that every install script is forced to use the default values and can't open windows or other interactive stuff
export DEBIAN_FRONTEND=noninteractive
echo "install openhd version-${OPENHD_PACKAGE}"

#Now we're installing all those Packages, we need force-overwrite to overwrite some libraries and files which are supplied by other .deb-files, when we build them ourselves (like the kernel)
apt update && apt upgrade -y
apt -y -o Dpkg::Options::="--force-overwrite" --no-install-recommends install \
${OPENHD_PACKAGE} \
${PLATFORM_PACKAGES} \
${GNUPLOT} || exit 1

#This is optional and installs a htop like jetson-task-monitor
if [[ "${OS}" == "ubuntu" ]]; then
    sudo -H pip install -U jetson-stats
fi

echo "-------------------------INSTALL QT-PATCHES-------------------------------"
#linking QT and it's libraries so the system can detect them
#since we build QT by ourself we need to link the libraries and binaries, so that the system knows where to look for
            touch /etc/ld.so.conf.d/qt.conf
            echo "/opt/Qt5.15.4/lib/" >/etc/ld.so.conf.d/qt.conf
            sudo ldconfig
            export PATH="$PATH:/opt/Qt5.15.4/bin/"
            cd /usr/bin
            sudo ln -s /opt/Qt5.15.4/bin/qmake qmake

#Now we purge/remove stuff that isn't needed andor was written in PURGE
apt -yq purge ${PURGE} || exit 1
apt -yq clean || exit 1
apt -yq autoremove || exit 1

MNT_DIR="${STAGE_WORK_DIR}/mnt"

#
# Write the openhd package version back to the base of the image and
# in the work dir so the builder can use it in the image name
export OPENHD_VERSION=$(dpkg -s openhd | grep "^Version" | awk '{ print $2 }')

echo ${OPENHD_VERSION} > /openhd_version.txt
echo ${OPENHD_VERSION} > /boot/openhd_version.txt