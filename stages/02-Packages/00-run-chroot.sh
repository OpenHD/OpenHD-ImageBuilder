# # This runs in context if the image (CHROOT)
# # Any native compilation can be done here, but should be moved into an own repository.
# # Do not use log here, it will end up in the image
# # This stage will install and remove packages which are required to get OpenHD to work
#!/bin/bash


 if [[ "${OS}" == "raspbian" ]]; then
    # Remove bad and unnecessary symlinks if system is not ubuntu
     rm /lib/modules/*/build || true
     rm /lib/modules/*/source || true
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
     PLATFORM_PACKAGES="open-hd-web-ui openhd-linux-pi openhd-linux-pi-headers libsdl2-dev libspdlog-dev libcamera-openhd libavcodec-dev libavformat-dev mavsdk gst-plugins-good openhd-qt openhd qopenhd libsodium-dev libpcap-dev git nano openssh-server libboost-filesystem1.74-dev meson"
 fi

 if [[ "${OS}" == "ubuntu-x86" ]] ; then
         echo "OS is ubuntu, we're building for x86"
         sudo apt update
         sudo apt upgrade
         sudo apt install -y git curl
         PLATFORM_PACKAGES="nano python3-pip htop libavcodec-dev libavformat-dev libelf-dev libboost-filesystem-dev openhd libspdlog-dev openhd-qt qopenhd"
         cd /opt
        #install all qt-dependencies (needs to be cleaned in the future)
            apt -y install build-essential libfontconfig1-dev libdbus-1-dev libfreetype6-dev libicu-dev libinput-dev libxkbcommon-dev libsqlite3-dev libssl-dev libpng-dev libjpeg-dev libglib2.0-dev \
            libgles2-mesa-dev libgbm-dev libdrm-dev libwayland-dev pulseaudio libpulse-dev flex bison gperf libre2-dev libnss3-dev libdrm-dev libxml2-dev libxslt1-dev libminizip-dev libjsoncpp-dev liblcms2-dev libevent-dev libprotobuf-dev protobuf-compiler \
            libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly gstreamer1.0-plugins-bad libgstreamer-plugins-bad1.0-dev gstreamer1.0-pulseaudio gstreamer1.0-tools gstreamer1.0-alsa \
            libdrm-dev libxcb-xfixes0-dev ibx11-dev libxcb1-dev  libxext-dev libxi-dev libxcomposite-dev libxcursor-dev libxtst-dev libxrandr-dev libfontconfig1-dev libfreetype6-dev libx11-xcb-dev libxext-dev libxfixes-dev libxi-dev libxrender-dev libxcb1-dev  libxcb-glx0-dev  libxcb-keysyms1-dev libxcb-image0-dev  libxcb-shm0-dev libxcb-icccm4-dev libxcb-sync-dev libxcb-xfixes0-dev libxcb-shape0-dev  libxcb-randr0-dev  libxcb-render-util0-dev  libxcb-util0-dev  libxcb-xinerama0-dev  libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev
            apt -y install '^libxcb.*-dev' libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev libxkbcommon-dev libxkbcommon-x11-dev libglib2.0-dev libgtk2.0-dev libssl-dev libgles2-mesa-dev libgbm-dev libgtk-3-dev libfontconfig-dev
         mkdir -p /opt/X86/
         curl -1sLf \
         'https://dl.cloudsmith.io/public/openhd/openhd-2-2-dev/setup.deb.sh' \
     |   sudo -E bash
 fi
   
 if [[ "${OS}" == "ubuntu" ]]; then
         echo "OS is ubuntu"
         #The version we use as Base has messed up sources (by nvidia), we're correcting this now
          rm /etc/apt/sources.list.d/nvidia-l4t-apt-source.list || true
         echo "deb https://repo.download.nvidia.com/jetson/common r32.6 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source2.list
         echo "deb https://repo.download.nvidia.com/jetson/t210 r32.6 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
         echo "update gcc and libboost to something usable"
         apt update
         echo "Nvidia apparently doesn't like to fix code for Jetson devices"
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
         PLATFORM_PACKAGES="nano mingetty libgstreamer-plugins-base1.0-dev python-pip libelf-dev libboost1.74-dev openhd-linux-jetson openhd"
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
 #We use different repositories for regular and testing branches. Ubuntu has not enough space to clone and build everything, the user must do this on himself if he wants that (needs at least 20gb space)
 if [[ "${TESTING}" == "testing" ]] && [[ "${OS}" != "ubuntu-x86" ]]; then
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
        if [[ "${OS}" == "raspbian" ]]; then
        cd /opt/QOpenHD
        bash /opt/QOpenHD/install_dep_rpi.sh || exit 1
        cd /opt/OpenHD
        bash /opt/OpenHD/install_dep_rpi.sh || exit 1
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

# #this is needed, so that every install script is forced to use the default values and can't open windows or other interactive stuff
 export DEBIAN_FRONTEND=noninteractive
 echo "install openhd version-${OPENHD_PACKAGE}"

# #Now we're installing all those Packages, we need force-overwrite to overwrite some libraries and files which are supplied by other .deb-files, when we build them ourselves (like the kernel)
 apt update
 apt upgrade -y
 apt -y -o Dpkg::Options::="--force-overwrite" --no-install-recommends install ${PLATFORM_PACKAGES} || exit 1

# #Now we purge/remove stuff that isn't needed andor was written in PURGE
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
