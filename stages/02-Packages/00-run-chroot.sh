# This runs in context if the image (CHROOT)
# Any native compilation can be done here, but should be moved into an own repository.
# Do not use log here, it will end up in the image
# This stage will install and remove packages which are required to get OpenHD to work

#!/bin/bash
if [[ "${OS}" != "ubuntu" ]]; then
    # Remove bad and unnecessary symlinks if system is not ubuntu
    rm /lib/modules/*/build || true
    rm /lib/modules/*/source || true
fi

if [[ "${OS}" == "raspbian" ]]; then
    echo "OS is raspbian"
    # Remove atheros firmware, which will be replaced by our kernel, hold raspberry kernel, so it will not be updated anymore
    mkdir -p /home/openhd
    chown -R openhd:openhd /home/openhd
    apt purge -y firmware-atheros || exit 1
    apt-mark hold firmware-atheros || exit 1
    apt -yq install firmware-misc-nonfree || exit 1
    apt-mark hold raspberrypi-kernel
    # Install libraspberrypi-dev before apt-get update
    #Remove current kernel and nfs(bloat)
    apt-mark hold libraspberrypi-dev libraspberrypi-bin libraspberrypi0 libraspberrypi-doc
    apt purge -y raspberrypi-kernel
    apt remove -y nfs-common libcamera*
    PLATFORM_PACKAGES="veye-raspberrypi openhd-linux-pi libsdl2-dev libspdlog-dev libcamera-openhd libavcodec-dev libavformat-dev mavsdk gst-plugins-good openhd-qt qopenhd libsodium-dev libpcap-dev git nano openssh-server libboost-filesystem1.74-dev meson"
fi

 if [[ "${OS}" == "ubuntu-x86" ]] ; then
        echo "OS is ubuntu, we're building for x86"
        sudo apt update
        sudo apt upgrade
        sudo apt install -y git
        PLATFORM_PACKAGES="nano python3-pip htop libavcodec-dev libavformat-dev libelf-dev"
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
        PLATFORM_PACKAGES="openhd-linux-jetson nano libgstreamer-plugins-base1.0-dev python-pip libelf-dev"
fi

echo "-------------------------GETTING FIRST UPDATE------------------------------------"

#adding config folder
mkdir -p /boot/openhd
apt update --allow-releaseinfo-change || exit 1  

if [[ "${OS}" == "raspbian" ]]; then
    echo "OS is raspbian"
fi
#add dependencies for our cloudsmith repository install-scripts
apt install -y apt-transport-https curl apt-utils

#We use different repositories for milestone and testing branches, milestone includes ALL needed files and have everything build exactly for milestone images
if [[ "${TESTING}" == "testing" ]] ; then
    curl -1sLf \
    'https://dl.cloudsmith.io/public/openhd/openhd-2-2-evo/setup.deb.sh' \
    | sudo -E bash
    curl -1sLf \
    'https://dl.cloudsmith.io/public/openhd/openhd-2-2-dev/setup.deb.sh' \
    | sudo -E bash
    echo "cloning Qopenhd and Openhd github repositories"
    apt update 
    cd /opt
    apt install git
    git clone --recursive https://github.com/OpenHD/OpenHD
    cd OpenHD
    cd /opt
    git clone --recursive https://github.com/OpenHD/QOpenHD
     echo "installing build dependencies"
    if [[ "${OS}" == "ubuntu" ]]; then
    cd /opt/OpenHD
    bash /opt/OpenHD/install_dep_jetson.sh || exit 1
    elif [[ "${OS}" == "raspbian" ]]; then
    cd /opt/QOpenHD
    bash /opt/QOpenHD/install_dep_rpi.sh || exit 1
    cd /opt/OpenHD
    bash /opt/OpenHD/install_dep_rpi.sh || exit 1
    fi

    
      if [[ "${OS}" == "ubuntu-x86" ]] ; then
      echo "x86-compiling stuff"
      cd /opt
      mkdir -p /opt/X86/
      sudo apt install -y openhd-qt-x86-focal qopenhd
      sudo apt install -y xinit net-tools libxcb-xinerama0 libxcb-util1 libgstreamer-plugins-base1.0-dev
      #sudo apt install -y dkms nvidia-driver-510 nvidia-dkms-510
      sudo apt install -y network-manager libspdlog-dev network-manager-gnome openhd-linux-x86 qopenhd 
      fi

else
    curl -1sLf \
    'https://dl.cloudsmith.io/public/openhd/openhd-2-2-evo/setup.deb.sh' \
    | sudo -E bash
fi

echo "-------------------------GETTING SECOND UPDATE------------------------------------"
#after getting our repositories inside the image we need to apply them and update the sources
apt update --allow-releaseinfo-change || exit 1

echo "-------------------------DONE GETTING SECOND UPDATE------------------------------------"
echo "Purge packages that interfer/we dont need..."

#write packages that will be removed into PURGE
PURGE="wireless-regdb avahi-daemon iptables man-db logrotate"

#this is needed, so that every install script is forced to use the default values and can't open windows or other interactive stuff
export DEBIAN_FRONTEND=noninteractive
echo "install openhd version-${OPENHD_PACKAGE}"

#Now we're installing all those Packages, we need force-overwrite to overwrite some libraries and files which are supplied by other .deb-files, when we build them ourselves (like the kernel)
apt update
apt upgrade -y
apt -y -o Dpkg::Options::="--force-overwrite" --no-install-recommends install \
${OPENHD_PACKAGE} \
${PLATFORM_PACKAGES} \
${GNUPLOT} || exit 1

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
