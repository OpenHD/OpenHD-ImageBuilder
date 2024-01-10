#!/bin/bash
# create a user account that should be the same on all platforms
USERNAME="openhd"
PASSWORD="openhd"

adduser --shell /bin/bash --ingroup sudo --disabled-password --gecos "" "$USERNAME" && echo "$USERNAME:$PASSWORD" | chpasswd
chown -R $USERNAME:$PASSWORD /home/$USERNAME
mkdir -p /boot/openhd/

# We copy the motd to display a custom OpenHD message in the Terminal
cd /opt/additionalFiles
cp motd /etc/motd
cp motd-unsupported /etc/motd-unsupported


if [[ "${OS}" == "radxa-debian-rock5a" ]] || [[ "${OS}" == "radxa-debian-rock5b" ]] || [[ "${OS}" == "radxa-debian-rock-cm3" ]]; then
    cat /etc/fstab
    #rm /conf/before.txt
    cp /opt/additionalFiles/before.txt /conf/before.txt
    cp /opt/additionalFiles/before.txt /config/before.txt
    #allow offline auto detection of image format
    cp /opt/additionalFiles/issue.txt /conf/issue.txt
    cp /opt/additionalFiles/issue.txt /config/issue.txt
    mkdir -p /conf/openhd
    mkdir -p /config/openhd
    mkdir -p /boot/openhd
    cp /opt/additionalFiles/initRock.sh /usr/local/bin/initRock.sh
    touch /conf/config.txt
    touch /config/config.txt
    #mounting config partition
    cp -rv /boot/openhd/* /conf/openhd/
    cp -rv /boot/openhd/* /config/openhd/
    #rm -Rf /boot/openhd
    ln -s /config/openhd /boot/openhd
    #copy overlays from linux kernel into the correct folder
    package_name=$(dpkg -l | awk '/^ii/ && $2 ~ /^linux-image-5\.10\.110-99-rockchip-/{print $2}')
    version=$(echo "$package_name" | cut -d '-' -f 4-)
    source_dirA="/usr/lib/$package_name/rockchip/overlay/rock-5a-*"
    source_dirB="/usr/lib/$package_name/rockchip/overlay/rock-5b-*"
    source_dirC="/usr/lib/$package_name/rockchip/overlay/radxa-cm3-rpi*"
    source_dirC="/usr/lib/$package_name/rockchip/overlay/radxa-zero3*"

    sudo cp -r $source_dirA "/boot/dtbo/"
    sudo cp -r $source_dirB "/boot/dtbo/"
    sudo cp -r $source_dirC "/boot/dtbo/"
    sudo cp -r $source_dirD "/boot/dtbo/"

fi

if [[ "${OS}" == "radxa-ubuntu-rock5b" ]]; then
    sed -i 's/\(overlays=\)/\1rock-5b-radxa-camera-4k/' /boot/firmware/ubuntuEnv.txt
    depmod -a
fi

if [[ "${OS}" == "radxa-ubuntu-rock5a" ]]; then
    tree /boot
    sed -i 's/\(overlays=\)/\1rock-5a-radxa-camera-4k/' /boot/firmware/ubuntuEnv.txt
    depmod -a
fi


if [[ "${OS}" == "radxa-debian-rock-cm3" ]]; then
    systemctl disable dnsmasq
    sed -i 's/loglevel=4/loglevel=0/g' /boot/extlinux/extlinux.conf
    cd /opt/additionalFiles/
    ls -a
    echo 'echo "0" > /sys/class/leds/board-led/brightness' >> /root/.bashrc
    if [ ! -e emmc ]; then
    echo "no need"
    touch /boot/openhd/ground.txt
    sudo sed -i 's/^ExecStart=.*/ExecStart=-\/sbin\/agetty --autologin root --noclear %I $TERM/' /lib/systemd/system/getty@.service
    else
    #autologin as root
    sudo sed -i 's/^ExecStart=.*/ExecStart=-\/sbin\/agetty --autologin root --noclear %I $TERM/' /lib/systemd/system/getty@.service
    #autocopy to emmc
    echo "0" > /sys/class/leds/board-led/brightness
    echo "1" > /sys/class/leds/board-led/brightness
    echo -e '\nexport NEWT_COLORS='\''\nroot=,black\nwindow=black,black\nborder=black,black\ntextbox=white,black\nbutton=white,black\nemptyscale=,black\nfullscale=,white\n'\'' \\\n\n(pv -n /opt/additionalFiles/emmc.img | dd of=/dev/mmcblk0 bs=128M conv=notrunc,noerror) 2>&1 | whiptail --gauge "Flashing OpenHD to EMMC, please wait..." 10 70 0\necho "please reboot or powerdown the system now"' >> /root/.bashrc
    echo "0" > /sys/class/leds/board-led/brightness
    echo 'whiptail --msgbox "Please reboot your system now" 10 40' >> /root/.bashrc
    fi
fi



 if [[ "${OS}" == "raspbian" ]] ; then
     touch /boot/openhd/rpi.txt
     #allow autologin and remove the raspberryos first boot menu
     cp /opt/additionalFiles/userconf.txt /boot/userconf.txt
     cp /opt/additionalFiles/getty@.service /usr/lib/systemd/system/getty@.service
     cp /opt/additionalFiles/default_raspi_config.txt /boot/config.txt
     cp /opt/additionalFiles/initPi.sh /usr/local/bin/initPi.sh
     #remove serial console
     sed -i /boot/cmdline.txt -e "s/console=ttyAMA0,[0-9]\+ //"
     sed -i /boot/cmdline.txt -e "s/console=serial0,[0-9]\+ //"
     # enable dualcam-csi this file is the one from the Ochin board, but should work on most carrier boards
     rm -Rf /boot/dt-blob.bin
     wget https://openhd-images.fra1.cdn.digitaloceanspaces.com/Downloader/dt-blob.bin -P /boot/
     # remove preexisting wifi driver for 88xxxu
     rm -Rf /lib/modules/6.1.29-v7l+/kernel/drivers/net/wireless/realtek/rtl8xxxu*
     rm -Rf /lib/modules/6.1.29-v7l/kernel/drivers/net/wireless/realtek/rtl8xxxu*
 fi

 if [[ "${OS}" == "ubuntu" ]]; then
       mkdir -p /boot/openhd/
       mkdir -p /etc/systemd/system/getty@tty1.service.d
       touch /boot/openhd/jetson.txt
       touch /boot/openhd/air.txt
       cp /opt/additionalFiles/override.conf /etc/systemd/system/getty@tty1.service.d/
fi

if [[ "${OS}" == "ubuntu-x86" ]] ; then
       sudo usermod -a -G dialout openhd
       sudo apt remove modemmanager
       cp /opt/additionalFiles/desktop-truster.sh /etc/profile.d/desktop-truster.sh
       cp /opt/additionalFiles/steamdeck.sh /usr/local/bin/steamdeck.sh
       #this script needs to be executable by every user
       chmod +777 /etc/profile.d/desktop-truster.sh
       chmod +x /etc/profile.d/steamdeck.sh
       git clone https://github.com/OpenHD/OpenHD-ImageBuilder --branch dev-release
       cd OpenHD-ImageBuilder
       chmod a+x  shortcuts/OpenHD.desktop
       chmod a+x  shortcuts/steamdeck.desktop
       chmod a+x  shortcuts/nm-tray-autostart.desktop
       chmod a+x  shortcuts/QOpenHD2.desktop
       chmod a+x  shortcuts/OpenHD-Air.desktop
       chmod a+x  shortcuts/OpenHD-Ground.desktop
       chmod a+x  shortcuts/QOpenHD.desktop
       chmod a+x  shortcuts/INAV.desktop
       chmod a+x  shortcuts/MissionPlanner.desktop
       chmod a+x  shortcuts/qgroundcontrol.desktop
       chmod a+x  shortcuts/OpenHD-ImageWriter.desktop
       sudo mv shortcuts/OpenHD.desktop /etc/xdg/autostart/
       sudo mv shortcuts/QOpenHD2.desktop /etc/xdg/autostart/
       sudo mv shortcuts/steamdeck.desktop /etc/xdg/autostart/
       sudo mv shortcuts/nm-tray-autostart.desktop /etc/xdg/autostart/
       sudo cp shortcuts/* /usr/share/applications/
       sudo cp shortcuts/*.desktop /home/openhd/Desktop/
       sudo cp shortcuts/*.ico /opt/
       gio set /home/openhd/Desktop/OpenHD-Air.desktop metadata::trusted true
       gio set /home/openhd/Desktop/OpenHD-Ground.desktop metadata::trusted true
       gio set /home/openhd/Desktop/QOpenHD.desktop metadata::trusted true
       gio set /home/openhd/Desktop/INAV.desktop metadata::trusted true
       gio set /home/openhd/Desktop/MissionPlanner.desktop metadata::trusted true
       gio set /home/openhd/Desktop/qgroundcontrol.desktop metadata::trusted true
       echo "openhd ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/openhd
       sudo add-apt-repository ppa:obsproject/obs-studio
       sudo apt install -y obs-studio
       cd /opt
       mkdir MissionPlanner
       cd MissionPlanner
       wget https://firmware.ardupilot.org/Tools/MissionPlanner/MissionPlanner-latest.zip
       unzip MissionPlanner-latest.zip
       rm MissionPlanner-latest.zip
       cd /opt
       wget https://github.com/iNavFlight/inav-configurator/releases/download/7.0.1/INAV-Configurator_linux64_7.0.1.tar.gz
       tar -zxvf INAV-Configurator_linux64_7.0.1.tar.gz
       rm INAV-Configurator_linux64_7.0.1.tar.gz
       mv INAV\ Configurator/ INAV
       cd INAV
       chmod +x inav-configurator
       chmod +x chrome_crashpad_handler
       cd /opt
       mkdir QGC
       cd QGC
       wget https://github.com/mavlink/qgroundcontrol/releases/download/v4.3.0/QGroundControl.AppImage
       chmod a+x QGroundControl.AppImage
       chown openhd:openhd QGroundControl.AppImage

        #mounting config partition
        sudo echo "UUID=4A7B-3DF7  /boot/openhd  auto  defaults  0  2" | sudo tee -a /etc/fstab
        cp /opt/additionalFiles/issue.txt /conf/issue.txt
        touch /conf/config.txt
        ls -a /conf
        mkdir -p /conf/openhd
        cp -rv /boot/openhd/* /conf/openhd/
        rm -Rf /boot/openhd
        touch /conf/openhd/resize.txt
        touch /boot/openhd/x86.txt
        ln -s /config/openhd /boot/openhd

fi

if [[ "${OS}" == "debian-X20" ]]; then
 mkdir /emmc/
 sudo echo "/dev/mmcblk1p1  /emmc  auto  defaults  0  2" | sudo tee -a /etc/fstab
 touch /boot/openhd/hardware_vtx_v20.txt
 touch /boot/openhd/air.txt
 rm -Rf /var/log/*
 sudo apt update
 sudo apt list --installed
 sudo sed -i '13,17d' /etc/oh-my-zsh/tools/uninstall.sh
 sudo bash ./etc/oh-my-zsh/tools/uninstall.sh
 rm -Rf /home/openhd/vencoderDemo
 rm -Rf /usr/lib/firmware/rkwifi
 rm -Rf /usr/lib/firmware/ath11k
 rm -Rf /usr/lib/firmware/brcm
 rm -Rf /etc/oh-my-zsh
 cd /usr/lib/arm-linux-gnueabihf/dri
 rm -Rf kms_swrast_dri.so mediatek_dri.so armada-drm_dri.so mxsfb-drm_dri.so panfrost_dri.so st7735r_dri.so etnaviv_dri.so lima_dri.so pl111_dri.so stm_dri.so exynos_dri.so mcde_dri.so r200_dri.so hx8357d_dri.so ili9225_dri.so r300_dri.so r600_dri.so radeon_dri.so radeonsi_dri.so v3d_dri.so imx-dcss_dri.so imx-drm_dri.so msm_dri.so tegra_dri.so repaper_dri.so virtio_gpu_dri.so ingenic-drm_dri.so nouveau_dri.so nouveau_vieux_dri.so rockchip_dri.so zink_dri.so kgsl_dri.so st7586_dri.so vc4_dri.so
 rm -Rf /usr/share/locale/*
 rm -Rf /usr/local/share/openhd/video/sunxisrc_h264.json
 touch /etc/apt/sources.list
 apt update
 sed -i '17,35d' /etc/rc.local
 find / -type f -exec du -h {} + | sort -rh | head -n 10
 echo "none /run tmpfs defaults,size=20M 0 0" >> /etc/fstab
fi

#Install openhd_sys_utils_service
cp /opt/additionalFiles/openhd_sys_utils.service /etc/systemd/system/
cp /opt/additionalFiles/*.sh /usr/local/bin/
chmod +x /usr/local/bin/*.sh
systemctl enable openhd_sys_utils.service

#change hostname to openhd
CURRENT_HOSTNAME=`sudo cat /etc/hostname | sudo tr -d " \t\n\r"`
NEW_HOSTNAME="openhd"
if [ $? -eq 0 ]; then
  sudo sh -c "echo '$NEW_HOSTNAME' > /etc/hostname"
  sudo sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
fi

apt -y autoremove
apt -y clean