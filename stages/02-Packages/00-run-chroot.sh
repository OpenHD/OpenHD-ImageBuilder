# # This runs in context if the image (CHROOT)
# # Do not use log here, it will end up in the image
# # This stage will install and remove packages which are required to get OpenHD to work
# # If anything fails here the script is failing!
#!/bin/bash

set -e

# X20 specific code
function prepare_x20 {
    ldd /usr/lib/arm-linux-gnueabihf/libLLVM-11.so.1
    sudo apt update
    sudo apt install deborphan -y
    sudo apt remove --purge $(deborphan --guess-all) -y
    sudo apt remove --purge deborphan -y
    sudo apt autoremove -y
    echo "____________________________"
    rm -Rf /etc/apt/sources.list.d/*
    rm -Rf /etc/apt/sources.list
    cd /usr/lib/arm-linux-gnueabihf/dri
    rm -Rf kms_swrast_dri.so mediatek_dri.so armada-drm_dri.so mxsfb-drm_dri.so panfrost_dri.so st7735r_dri.so etnaviv_dri.so lima_dri.so pl111_dri.so stm_dri.so exynos_dri.so mcde_dri.so r200_dri.so hx8357d_dri.so ili9225_dri.so r300_dri.so r600_dri.so radeon_dri.so radeonsi_dri.so v3d_dri.so imx-dcss_dri.so imx-drm_dri.so msm_dri.so tegra_dri.so repaper_dri.so virtio_gpu_dri.so ingenic-drm_dri.so nouveau_dri.so nouveau_vieux_dri.so rockchip_dri.so zink_dri.so kgsl_dri.so st7586_dri.so vc4_dri.so
    rm -Rf /usr/share/locale/*
    rm -Rf /usr/local/share/openhd/video/sunxisrc_h264.json
    touch /etc/apt/sources.list
    apt update
    sed -i '17,35d' /etc/rc.local
    find / -type f -exec du -h {} + | sort -rh | head -n 10
}
function install_x20_packages {
    BASE_PACKAGES="openhd-x20"
    PLATFORM_PACKAGES_REMOVE="*boost* locales guile-2.2-libs "
    PLATFORM_PACKAGES=""
}

# Raspbian-specific code
function install_raspbian_packages {
    BASE_PACKAGES="openhd apt-transport-https apt-utils open-hd-web-ui"
    PLATFORM_PACKAGES_HOLD="raspberrypi-kernel libraspberrypi-dev libraspberrypi-bin libraspberrypi0 libraspberrypi-doc raspberrypi-bootloader"
    PLATFORM_PACKAGES_REMOVE="locales gdb librsvg2-2 guile-2.2-libs firmware-libertas gcc-10 nfs-common libcamera* raspberrypi-kernel"
    PLATFORM_PACKAGES="firmware-atheros openhd-userland openhd-linux-pi libseek-thermal libcamera-openhd openhd-qt openssh-server"
}
# Ubuntu-Rockship-specific code
function install_radxa-ubuntu_packages {
    BASE_PACKAGES="openhd apt-transport-https apt-utils open-hd-web-ui"
    PLATFORM_PACKAGES="rsync qopenhd procps gstreamer1.0-plugins-bad gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-tools gstreamer1.0-rockchip1 gstreamer1.0-gl mali-g610-firmware malirun rockchip-multimedia-config librist4 librist-dev rist-tools libv4l-0 libv4l2rds0 libv4lconvert0 libv4l-dev libv4l-rkmpp qv4l2 v4l-utils librockchip-mpp1 librockchip-mpp-dev librockchip-vpu0 rockchip-mpp-demos librga2 librga-dev libegl-mesa0 libegl1-mesa-dev libgbm-dev libgl1-mesa-dev libgles2-mesa-dev libglx-mesa0 mesa-common-dev mesa-vulkan-drivers mesa-utils libwidevinecdm"
}

function install_radxa-debian_packages {
    BASE_PACKAGES="openhd apt-transport-https apt-utils open-hd-web-ui"
    PLATFORM_PACKAGES_HOLD="8852be-dkms task-rockchip radxa-system-config-rockchip linux-image-rock-5a linux-image-5.10.110-6-rockchip linux-image-5.10.110-11-rockchip"
    PLATFORM_PACKAGES_REMOVE="dkms sddm plymouth plasma-desktop kde*"
    PLATFORM_PACKAGES="rockchip-iq-openhd linux-headers-5.10.110-99-rockchip-g9c3b92612 linux-image-5.10.110-99-rockchip-g9c3b92612 rsync procps mpv camera-engine-rkaiq"
}
function install_radxa-debian_packages_cm3 {
    PLATFORM_PACKAGES="net-tools isc-dhcp-client network-manager glances rockchip-iq-openhd librga2=2.2.0-1 linux-image-5.10.160-radxa-rk356x-rk356x linux-headers-5.10.160-radxa-rk356x-rk356x linux-libc-dev-5.10.160-radxa-rk356x-rk356x procps camera-engine-rkaiq"
    PLATFORM_PACKAGES_REMOVE="firefox* dkms sddm plymouth plasma-desktop kde*"
}
function install_packages-core3566 {
    PLATFORM_PACKAGES="net-tools isc-dhcp-client network-manager glances rockchip-iq-openhd librga2=2.2.0-1 linux-image-5.10.160-core3566-rk356x linux-headers-5.10.160-core3566-rk356x linux-libc-dev-5.10.160-core3566-rk356x procps camera-engine-rkaiq"
    PLATFORM_PACKAGES_REMOVE="firefox* dkms sddm plymouth plasma-desktop kde*"
}


# Ubuntu-x86-specific code
function install_ubuntu_x86_packages {
        if [[ "${DISTRO}" == "jammy" ]]; then
        PLATFORM_PACKAGES_HOLD="dkms initramfs-tools grub-pc linux-image-5.15.0-57-generic grub-efi-amd64-signed linux-generic linux-headers-generic linux-image-generic linux-generic-hwe-22.04 linux-image-generic-hwe-22.04 linux-headers-generic-hwe-22.04"
        else
        PLATFORM_PACKAGES_HOLD="grub-efi-amd64-bin grub-efi-amd64-signed linux-generic linux-headers-generic linux-image-generic linux-libc-dev"
        fi
    BASE_PACKAGES="openhd apt-transport-https apt-utils open-hd-web-ui"
    PLATFORM_PACKAGES="gnome-disk-utility openssh-server gnome-terminal qopenhd python3-pip htop libavcodec-dev libavformat-dev libelf-dev libboost-filesystem-dev libspdlog-dev build-essential libfontconfig1-dev libdbus-1-dev libfreetype6-dev libicu-dev libinput-dev libxkbcommon-dev libsqlite3-dev libssl-dev libpng-dev libjpeg-dev libglib2.0-dev libgles2-mesa-dev libgbm-dev libdrm-dev libwayland-dev pulseaudio libpulse-dev flex bison gperf libre2-dev libnss3-dev libdrm-dev libxml2-dev libxslt1-dev libminizip-dev libjsoncpp-dev liblcms2-dev libevent-dev libprotobuf-dev protobuf-compiler libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev libxkbcommon-x11-dev libgtk2.0-dev libgtk-3-dev libfuse2 mono-complete mono-runtime libmono-system-windows-forms4.0-cil libmono-system-core4.0-cil libmono-system-management4.0-cil libmono-system-xml-linq4.0-cil libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly gstreamer1.0-plugins-bad libgstreamer-plugins-bad1.0-dev gstreamer1.0-pulseaudio gstreamer1.0-tools gstreamer1.0-alsa gstreamer1.0-qt5 openhdimagewriter"
    PLATFORM_PACKAGES_REMOVE=""
}

function clone_github_repos {
    cd /opt
    git clone --recursive --depth 1 https://github.com/OpenHD/OpenHD
    git clone --recursive --depth 1 https://github.com/OpenHD/QOpenHD
    chmod -R 777 /opt
}

# Main function
 if [[ "${OS}" == "debian-X20" ]]; then
    prepare_x20
    install_x20_packages
 elif [[ "${OS}" == "raspbian" ]]; then
    install_raspbian_packages
 elif [[ "${OS}" == "radxa-ubuntu-rock5b" ]] || [[ "${OS}" == "radxa-ubuntu-rock5a" ]] ; then
    sudo add-apt-repository -r "deb https://ppa.launchpadcontent.net/jjriek/rockchip/ubuntu jammy main"
    install_radxa-ubuntu_packages
 elif [[ "${OS}" == "radxa-debian-rock5a" ]] || [[ "${OS}" == "radxa-debian-rock5b" ]]  ; then
    install_radxa-debian_packages
 elif [[ "${OS}" == "radxa-debian-rock-cm3" ]] ; then
    install_radxa-debian_packages_cm3
 elif [[ "${OS}" == "radxa-debian-rock-cm3-core3566" ]] ; then
    install_packages-core3566
 elif [[ "${OS}" == "ubuntu-x86" ]] ; then
    install_ubuntu_x86_packages
 elif [[ "${OS}" == "ubuntu" ]] ; then
    fix_jetson_apt
    install_jetson_packages
 fi

 # Add OpenHD Repository platform-specific packages
 apt install -y curl
 curl -1sLf 'https://dl.cloudsmith.io/public/openhd/release/setup.deb.sh'| sudo -E bash
 curl -1sLf 'https://dl.cloudsmith.io/public/openhd/dev-release/setup.deb.sh'| sudo -E bash
 curl -1sLf 'https://dl.cloudsmith.io/public/openhd/release/setup.deb.sh'| sudo -E bash
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
 #cleanup before installing packages
 apt autoremove -y


 # Hold platform-specific packages
 echo "Holding back platform-specific packages..."
 for package in ${PLATFORM_PACKAGES_HOLD}; do
     echo "Holding ${package}..."
     apt-mark hold ${package} || true
     if [ $? -ne 0 ]; then
         echo "Failed to hold ${package}!"
     fi
 done
 #Cleapup
 apt autoremove -y
 apt upgrade -y --allow-downgrades

 # Install platform-specific packages
 echo "Installing platform-specific packages..."
 for package in ${BASE_PACKAGES} ${PLATFORM_PACKAGES}; do
     echo "Installing ${package}..."
     apt install -y -o Dpkg::Options::="--force-overwrite" --no-install-recommends --allow-downgrades ${package}
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
