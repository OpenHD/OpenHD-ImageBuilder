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

if [[ "${OS}" == "raspbian" ]]; then
    echo "OS is raspbian"
    rm /boot/config.txt
    rm /boot/cmdline.txt
    apt-mark hold firmware-atheros || exit 1
    apt purge firmware-atheros || exit 1
    apt -yq install firmware-misc-nonfree || exit 1
    apt-mark hold raspberrypi-kernel
    # Install libraspberrypi-dev before apt-get update
    DEBIAN_FRONTEND=noninteractive apt -yq install libraspberrypi-doc libraspberrypi-dev libraspberrypi-dev libraspberrypi-bin libraspberrypi0 || exit 1
    apt-mark hold libraspberrypi-dev libraspberrypi-bin libraspberrypi0 libraspberrypi-doc libcamera-apps-lite libcamera0
    apt purge raspberrypi-kernel
    PLATFORM_PACKAGES=""
fi


if [[ "${OS}" == "armbian" ]]; then
    echo "OS is armbian"
    PLATFORM_PACKAGES=""
fi


if [[ "${OS}" == "ubuntu" ]]; then
    echo "OS is ubuntu"
    PLATFORM_PACKAGES=""

    echo "-------------------------SHOW nvideo source list-------------------------------"
    #it appears some variable for source list gets missed when building images like this.. 
    #by deleting and rewriting source list entry it fixes it.
    rm /etc/apt/sources.list.d/nvidia-l4t-apt-source.list || true
    echo "deb https://repo.download.nvidia.com/jetson/common r32.6 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source2.list
    echo "deb https://repo.download.nvidia.com/jetson/t210 r32.6 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
    sudo cat /etc/apt/sources.list.d/nvidia-l4t-apt-source.list

    #remove some nvidia packages... if building from nvidia base image 

    sudo apt remove ubuntu-desktop
    sudo apt remove libreoffice-writer chromium-browser chromium* yelp unity thunderbird rhythmbox nautilus gnome-software
    sudo apt remove ubuntu-artwork ubuntu-sounds ubuntu-wallpapers ubuntu-wallpapers-bionic
    sudo apt remove vlc-data lightdm
    sudo apt remove unity-settings-daemon packagekit wamerican mysql-common libgdm1
    sudo apt remove ubuntu-release-upgrader-gtk ubuntu-web-launchers
    sudo apt remove --purge libreoffice* gnome-applet* gnome-bluetooth gnome-desktop* gnome-sessio* gnome-user* gnome-shell-common gnome-control-center gnome-screenshot
    sudo apt autoremove
    
fi


if [[ "${HAS_CUSTOM_KERNEL}" == "true" ]]; then
    echo "-----------------------has a custom kernel----------------------------------"
    PLATFORM_PACKAGES="${PLATFORM_PACKAGES} ${KERNEL_PACKAGE}"
fi

echo "-------------------------GETTING FIRST UPDATE------------------------------------"

apt update --allow-releaseinfo-change || exit 1  

echo "-------------------------DONE GETTING FIRST UPDATE-------------------------------"

apt install -y apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-1/cfg/gpg/gpg.0AD501344F75A993.key' | apt-key add -
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-1-testing/cfg/gpg/gpg.58A6C96C088A96BF.key' | apt-key add -
sudo apt-get install -y apt-utils

echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1.list

if [[ "${TESTING}" == "testing" ]]; then
    echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1-testing/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1-testing.list
fi

echo "-------------------------GETTING SECOND UPDATE------------------------------------"

apt update --allow-releaseinfo-change || exit 1

echo "-------------------------DONE GETTING SECOND UPDATE------------------------------------"

echo "Purge packages that interfer/we dont need..."

PURGE="wireless-regdb cron avahi-daemon curl iptables man-db logrotate"

export DEBIAN_FRONTEND=noninteractive

echo "install openhd version-${OPENHD_PACKAGE}"
if [[ "${OS}" == "ubuntu" ]]; then
    echo "Install some Jetson essential libraries and patched rtl8812au driver"
    sudo apt install -y git nano python-pip build-essential libelf-dev
    sudo apt remove linux-firmware nvidia-l4t-kernel nvidia-l4t-kernel-headers
    sudo apt install openhd-linux-jetson 
    sudo -H pip install -U jetson-stats
    cd /lib/modules/4.9.253/kernel/drivers/net/wireless
    cp -r 88XXau.ko /lib/modules/4.9.253-tegra/kernel/drivers/net/wireless/realtek/rtl8812au/
    cd /lib/modules/4.9.253-tegra/kernel/drivers/net/wireless/realtek/rtl8812au/
    mv rtl8812au.ko rtl8812au.ko.bak
    mv 88XXau.ko rtl8812au.ko
    echo "Downloading Atheros parched drivers"
    wget www.nurse.teithe.gr/htc_9271.fw
    mv /lib/firmware/htc_9271.fw /lib/firmware/htc_9271.fw.bak
    mv /lib/firmware/ath9k_htc/htc_9271-1.4.0.fw /lib/firmware/ath9k_htc/htc_9271-1.4.0.fw.bak
    cp htc_9271.fw /lib/firmware/
    cp htc_9271.fw /lib/firmware/ath9k_htc/
    mv /lib/firmware/ath9k_htc/htc_9271.fw /lib/firmware/ath9k_htc/htc_9271-1.4.0.fw
    echo '#!/bin/bash' >> /usr/local/bin/video.sh && printf "\nsudo nvpmodel -m 0 | sudo jetson_clocks\nsudo iw wlan0 set freq 5320\nsudo iw wlan0 set txpower fixed 3100\necho \"nameserver 1.1.1.1\" > /etc/resolv.conf" >> /usr/local/bin/video.sh
    printf "[Unit]\nDescription=\"Jetson Nano clocks\"\nAfter=openhdinterface.service\n[Service]\nExecStart=/usr/local/bin/video.sh\n[Install]\nWantedBy=multi-user.target\nAlias=video.service" >> /etc/systemd/system/video.service
    sudo chmod u+x /usr/local/bin/video.sh
    sudo systemctl enable networking.service
    sudo systemctl enable video.service
    wget https://www.arducam.com/downloads/Jetson/Camera_overrides.tar.gz
    tar zxvf Camera_overrides.tar.gz
    cp camera_overrides.isp /var/nvidia/nvcam/settings/
    chmod 664 /var/nvidia/nvcam/settings/camera_overrides.isp
    chown root:root /var/nvidia/nvcam/settings/camera_overrides.isp
fi

apt update && apt upgrade -y
apt -y --no-install-recommends --focre-overwrite install \
${OPENHD_PACKAGE} \
${PLATFORM_PACKAGES} \
${GNUPLOT} || exit 1
apt install -y libsodium-dev libpcap-dev git nano build-essential
git clone https://github.com/Consti10/wifibroadcast.git
cd wifibroadcast
make
mv /usr/local/bin/wfb_tx /usr/local/bin/wfb_tx.bak
mv /usr/local/bin/wfb_rx /usr/local/bin/wfb_rx.bak
mv /usr/local/bin/wfb_keygen /usr/local/bin/wfb_keygen.bak
cp wfb_tx /usr/local/bin/
cp wfb_rx /usr/local/bin/
cp wfb_keygen /usr/local/bin/

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
