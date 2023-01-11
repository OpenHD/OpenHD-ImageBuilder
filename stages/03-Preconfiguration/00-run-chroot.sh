# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image
# Here we disable services, create users, put debug stuff in and set our hostname

#!/bin/bash
# create a use account that should be the same on all platforms
useradd openhd
mkdir -p /home/openhd
echo "openhd:openhd" | chpasswd
adduser openhd sudo
chown -R openhd:openhd /home/openhd


# On platforms that already have a separate boot partition we just put the config files on there, but some
# platforms don't have or need a boot partition, so on those we have a separate /conf partition. All
# openhd components look to /conf, so a symlink works well here. We may end up using separate /conf on everything.
if [[ "${HAVE_CONF_PART}" == "false" ]] && [[ "${HAVE_BOOT_PART}" == "true" ]]; then
    ln -s /boot /conf
fi

#Clone misc Scripts and Files
 cd /opt
 git clone https://github.com/OpenHD/Overlay
#Enable autologin
 cd Overlay
 cp motd /etc/motd

 if [[ "${OS}" == "raspbian" ]] ; then
     echo "adding openhd user"
     touch /boot/openhd/rpi.txt
     cd /opt
     cd Overlay
     cp userconf.txt /boot/userconf.txt
     cp getty@.service /usr/lib/systemd/system/getty@.service
     cp default_raspi_config.txt /boot/config.txt
     #remove serial console
    sed -i /boot/cmdline.txt -e "s/console=ttyAMA0,[0-9]\+ //"
    sed -i /boot/cmdline.txt -e "s/console=serial0,[0-9]\+ //"

     # enable dualcam-csi
     cd /boot/
     wget https://github.com/ochin-space/ochin-CM4/blob/master/files/dt-blob.bin
        
 fi

#Ensure the runlevel is multi-target (3) could possibly be lower...
#sudo systemctl set-default multi-user.target

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
       cp /opt/Overlay/override.conf /etc/systemd/system/getty@tty1.service.d/
       systemctl disable nv-oem-config-gui.service
       systemctl enable getty@tty1.service
fi

if [[ "${OS}" == "ubuntu-x86" ]] ; then
       cp /opt/Overlay/desktop-truster.sh /etc/profile.d/desktop-truster.sh
       #this script needs to be executable by every user
       chmod +777 /etc/profile.d/desktop-truster.sh
       mkdir -p /boot/openhd/
       touch /boot/openhd/x86.txt
       touch /boot/openhd/ground.txt
       systemctl disable openhd
       systemctl disable qopenhd
       git clone https://github.com/OpenHD/OpenHD-ImageBuilder
       cd OpenHD-ImageBuilder
       chmod a+x  shortcuts/OpenHD-Air.desktop
	   chmod a+x  shortcuts/OpenHD-Ground.desktop
	   chmod a+x  shortcuts/QOpenHD.desktop
	   sudo cp shortcuts/* /usr/share/applications/
       sudo cp shortcuts/*.desktop /home/openhd/Desktop/
	   sudo cp shortcuts/*.ico /opt/
       sudo nmcli connection delete Onair
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
       mv MissionPlanner* MissionPlanner
       cd /opt
       wget https://github.com/iNavFlight/inav-configurator/releases/download/6.0.0-FP2/INAV-Configurator_linux64_6.0.0-FP2.tar.gz
       tar -zxvf INAV-Configurator_linux64_6.0.0-FP2.tar.gz
       rm INAV-Configurator_linux64_6.0.0-FP2.tar.gz
       mv INAV* INAV
       cd INAV
       chmod +x inav-configurator
       chmod +x chrome_crashpad_handler
       cd /opt
       mkdir QGC
       cd QGC
       wget https://github.com/mavlink/qgroundcontrol/releases/download/v4.2.4/QGroundControl.AppImage
       ./QGroundControl.AppImage --appimage-extract
       rm QGroundControl.AppImage
       cd squashfs-root
       mv * ../


fi
#this service updates runlevel changes. Set desired runlevel prior to this being disabled
if [[ "${OS}" != "ubuntu-x86" ]]; then
sudo systemctl disable systemd-update-utmp.service
fi


#change hostname
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

