#!/bin/bash

# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image
# Here we configue all our services

#remove networking stuff
rm -f /etc/init.d/dnsmasq
rm -f /etc/init.d/dhcpcd

#disable unneeded services
sudo systemctl disable dnsmasq.service
sudo systemctl disable syslog.service
echo "disabling journald"

#replace dhcpcd with network manager
sudo systemctl disable dhcpcd.service
sudo systemctl enable NetworkManager

sudo systemctl disable triggerhappy.service
sudo systemctl disable avahi-daemon.service
sudo systemctl disable ser2net.service
sudo systemctl disable hciuart.service
sudo systemctl disable anacron.service
sudo systemctl disable exim4.service
sudo systemctl mask hostapd.service
sudo systemctl enable ssh #we have ssh constantly enabled

#Install Update-Service
cp /opt/additionalFiles/update.service /etc/systemd/system/
cp /opt/additionalFiles/updateOpenHD.sh /usr/local/bin/
chmod +x /usr/local/bin/updateOpenHD.sh
systemctl enable update.service


#Disable does not work on PLYMOUTH
sudo systemctl mask plymouth-start.service
sudo systemctl mask plymouth-read-write.service
sudo systemctl mask plymouth-quit-wait.service
sudo systemctl mask plymouth-quit.service
if [[ "${OS}" != "ubuntu" ]] || [[ "${OS}" != "ubuntu-x86" ]]; then
    echo "OS is NOT ubuntu..disabling journald flush"
    sudo systemctl disable systemd-journal-flush.service

fi

if [[ "${OS}" == "ubuntu" ]]; then
       mkdir -p /boot/openhd/
       mkdir -p /etc/systemd/system/getty@tty1.service.d
       touch /boot/openhd/jetson.txt
       touch /boot/openhd/air.txt
       cp /opt/additionalFiles/override.conf /etc/systemd/system/getty@tty1.service.d/
       systemctl disable nv-oem-config-gui.service
       systemctl enable getty@tty1.service
fi

if [[ "${OS}" == "debian" ]]; then
       systemctl disable lightdm
fi

if [[ "${OS}" == "ubuntu-x86" ]] ; then
       sudo usermod -a -G dialout openhd
       sudo apt remove modemmanager
       cp /opt/additionalFiles/desktop-truster.sh /etc/profile.d/desktop-truster.sh
       #this script needs to be executable by every user
       chmod +777 /etc/profile.d/desktop-truster.sh
       mkdir -p /boot/openhd/
       git clone https://github.com/OpenHD/OpenHD-ImageBuilder
       cd OpenHD-ImageBuilder
       chmod a+x  shortcuts/OpenHD-Air.desktop
       chmod a+x  shortcuts/OpenHD-Ground.desktop
       chmod a+x  shortcuts/QOpenHD.desktop
       chmod a+x  shortcuts/INAV.desktop
       chmod a+x  shortcuts/MissionPlanner.desktop
       chmod a+x  shortcuts/qgroundcontrol.desktop
       chmod a+x  shortcuts/OpenHD-ImageWriter.desktop
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
       cd /opt
       mkdir MissionPlanner
       cd MissionPlanner
       wget https://firmware.ardupilot.org/Tools/MissionPlanner/MissionPlanner-latest.zip
       unzip MissionPlanner-latest.zip
       rm MissionPlanner-latest.zip
       cd /opt
       wget https://github.com/iNavFlight/inav-configurator/releases/download/6.0.0-FP2/INAV-Configurator_linux64_6.0.0-FP2.tar.gz
       tar -zxvf INAV-Configurator_linux64_6.0.0-FP2.tar.gz
       rm INAV-Configurator_linux64_6.0.0-FP2.tar.gz
       mv INAV\ Configurator/ INAV
       cd INAV
       chmod +x inav-configurator
       chmod +x chrome_crashpad_handler
       cd /opt
       mkdir QGC
       cd QGC
       wget https://github.com/mavlink/qgroundcontrol/releases/download/v4.2.4/QGroundControl.AppImage
       chmod a+x QGroundControl.AppImage
       chown openhd:openhd QGroundControl.AppImage


fi

#change hostname to openhd
CURRENT_HOSTNAME=`sudo cat /etc/hostname | sudo tr -d " \t\n\r"`
NEW_HOSTNAME="openhd"
if [ $? -eq 0 ]; then
  sudo sh -c "echo '$NEW_HOSTNAME' > /etc/hostname"
  sudo sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
fi

if [[ "${HAVE_CONF_PART}" == "false" ]] && [[ "${HAVE_BOOT_PART}" == "true" ]]; then
    # the system expects things to be in /conf now, but on some platforms we use the boot
    # partition instead of making another one, we may change this in the future
    ln -s /boot /conf
fi

apt -y autoremove
apt -y clean

