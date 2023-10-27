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

if [[ "${OS}" == "radxa-debian-rock5a" ]] || [[ "${OS}" == "radxa-debian-rock5b" ]]; then
    rm /conf/before.txt
    cp /opt/additionalFiles/before.txt /conf/before.txt
    #allow offline auto detection of image format
    cp /opt/additionalFiles/issue.txt /conf/issue.txt
    mkdir -p /conf/openhd
    cp /opt/additionalFiles/initRock.sh /usr/local/bin/initRock.sh
    touch /conf/config.txt
    #mounting config partition
    ls -a /conf
    cp -rv /boot/openhd/* /conf/openhd/
    rm -Rf /boot/openhd
    ln -s /config/openhd /boot/openhd
    #copy overlays from linux kernel into the correct folder
    package_name=$(dpkg -l | awk '/^ii/ && $2 ~ /^linux-image-5\.10\.110-99-rockchip-/{print $2}')
    version=$(echo "$package_name" | cut -d '-' -f 4-)
    source_dirA="/usr/lib/$package_name/rockchip/overlay/rock-5a-*"
    source_dirB="/usr/lib/$package_name/rockchip/overlay/rock-5b-*"

    sudo cp -r $source_dirA "/boot/dtbo/"
    sudo cp -r $source_dirB "/boot/dtbo/"
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


#DO NOT TOUCH THE SYNTAX HERE
if [[ "${OS}" == "radxa-debian-rock-cm3" ]] || [[ "${OS}" == "radxa-debian-rock5a" ]] || [[ "${OS}" == "radxa-debian-rock5b" ]]; then
    touch /etc/systemd/system/usb.service
    SERVICE_CONTENT="[Unit]
Description=Enable USB
[Service]
ExecStart=/bin/sh -c \"echo host > /sys/devices/platform/fe8a0000.usb2-phy/otg_mode\"
[Install]
WantedBy=multi-user.target"

# Create the systemd service unit file
echo "$SERVICE_CONTENT" > /etc/systemd/system/usb.service
systemctl enable usb
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
       wget https://github.com/iNavFlight/inav-configurator/releases/download/6.1.0/INAV-Configurator_linux64_6.1.0.tar.gz
       tar -zxvf INAV-Configurator_linux64_6.1.0.tar.gz
       rm INAV-Configurator_linux64_6.1.0.tar.gz
       mv INAV\ Configurator/ INAV
       cd INAV
       chmod +x inav-configurator
       chmod +x chrome_crashpad_handler
       cd /opt
       mkdir QGC
       cd QGC
       wget https://github.com/mavlink/qgroundcontrol/releases/download/v4.2.8/QGroundControl.AppImage
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
        ln -s /config/openhd /boot/openhd

fi

#Install openhd_sys_utils_service
cp /opt/additionalFiles/openhd_sys_utils.service /etc/systemd/system/
cp /opt/additionalFiles/openhd_sys_utils.sh /usr/local/bin/
chmod +x /usr/local/bin/openhd_sys_utils.sh
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