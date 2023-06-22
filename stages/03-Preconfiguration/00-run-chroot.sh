# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image
# Here we create users and set our hostname and do additional platform stuff

#!/bin/bash
# create a use account that should be the same on all platforms
USERNAME="openhd"
PASSWORD="openhd"

adduser --shell /bin/bash --ingroup sudo --disabled-password --gecos "" "$USERNAME" && echo "$USERNAME:$PASSWORD" | chpasswd
chown -R $USERNAME:$PASSWORD /home/$USERNAME
mkdir -p /boot/openhd/

# On platforms that already have a separate boot partition we just put the config files on there, but some
# platforms don't have or need a boot partition, so on those we have a separate /conf partition. All
# openhd components look to /conf, so a symlink works well here. We may end up using separate /conf on everything.
if [[ "${HAVE_CONF_PART}" == "false" ]] && [[ "${HAVE_BOOT_PART}" == "true" ]]; then
    ln -s /boot /conf
fi

# We copy the motd to display a custom OpenHD message in the Terminal
cd /opt/additionalFiles
cp motd /etc/motd

 if [[ "${OS}" == "radxa-ubuntu" ]] || [[ "${OS}" == "radxa-debian" ]]; then
    systemctl disable gdm3
    systemctl disable gdm
    sudo systemctl set-default multi-user.target
    touch /boot/openhd/rock5.txt
    rm -Rf /lib/modules/5.10.66-27-rockchip-gea60d388902d/kernel/drivers/net/wireless/realtek
    rm -Rf /lib/modules/5.10.110-5-rockchip/kernel/drivers/net/wireless/realtek
    mv /etc/motd /etc/motd2
    cp /opt/additionalFiles/motd2 /etc/motd
    mkdir -p /boot/openhd/
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    touch /boot/openhd/rock5.txt
    touch /boot/openhd/ground.txt
    rm /boot/openhd/before.txt
    rm /boot/openhd/config.txt
    cp /opt/additionalFiles/before.txt /boot/openhd/before.txt
    cp /opt/additionalFiles/config.txt /boot/openhd/config.txt
    mv /boot/dtbo/rock-5a-radxa-camera-4k.dtbo.disabled /boot/dtbo/rock-5a-radxa-camera-4k.dtbo
    mv /boot/dtbo/rock-5b-radxa-camera-4k.dtbo.disabled /boot/dtbo/rock-5b-radxa-camera-4k.dtbo
    #sudo sed -i 's/rock-5a-radxa-display-8hd.dtbo/rock-5a-radxa-camera-4k.dtbo/g' /boot/extlinux/extlinux.conf


    # #FIXING DISPLAY DETECTION to 1080/60hz
    #     # Search for lines containing "append" in the extlinux.conf file
    #     lines=$(grep -n "append" /boot/extlinux/extlinux.conf | cut -d':' -f1)

    #     # Loop through each line number and check for the presence of "video"
    #     for line in $lines
    #     do
    #         if grep -n "video" /boot/extlinux/extlinux.conf | cut -d: -f1 | grep -q $line
    #         then
    #             echo "Line $line: video already present"
    #         else
    #             # Add "video" to the end of the line
    #             sed -i "${line}s/$/ video=1920x1080@60/" /boot/extlinux/extlinux.conf
    #             echo "Line $line: video added"
    #         fi
    #     done
 
#     #Enable Radxa-4K-camera-Overlay
#     kernel_versions=$(grep -o 'fdtdir' /boot/extlinux/extlinux.conf | wc -l)
#     for ((i=1; i<=kernel_versions; i++)); do
#     file="/boot/extlinux/extlinux.conf"
#     # use grep to find lines with "fdtdir" in the file
#     # and print the line numbers
#     grep -n "fdtdir" "$file" | cut -d: -f1 | while read line_num; do
#         # print the line(s) immediately following the matching line
#         line="$(sed -n "$((line_num+1))p" "$file")"
#         if [[ "$line" == *"rock-5b-radxa-camera-4k"* ]]; then
#             echo "$line_num is already patched"
#         else
#             sed -i "$((line_num+1))i \        fdtoverlays  /boot/dtbo/rock-5b-radxa-camera-4k.dtbo" "$file"
#             echo "Camera-Config $line_num"
#             # Set flag to break out of while loop
#             break_while=true
#         fi
#         # Check flag to break out of while loop
#         if [[ "$break_while" == true ]]; then
#             break_while=false
#             break
#         fi
#     done
# done


 fi

 if [[ "${OS}" == "raspbian" ]] ; then
     touch /boot/openhd/rpi.txt
     #allow autologin and remove the raspberryos first boot menu
     cp /opt/additionalFiles/userconf.txt /boot/userconf.txt
     cp /opt/additionalFiles/getty@.service /usr/lib/systemd/system/getty@.service
     cp /opt/additionalFiles/default_raspi_config.txt /boot/config.txt
     #remove serial console
     sed -i /boot/cmdline.txt -e "s/console=ttyAMA0,[0-9]\+ //"
     sed -i /boot/cmdline.txt -e "s/console=serial0,[0-9]\+ //"
     # enable dualcam-csi this file is the one from the Ochin board, but should work on most carrier boards
     rm -Rf /boot/dt-blob.bin
     wget https://openhd-images.fra1.cdn.digitaloceanspaces.com/Downloader/dt-blob.bin -P /boot/
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
       #this script needs to be executable by every user
       chmod +777 /etc/profile.d/desktop-truster.sh
       git clone https://github.com/OpenHD/OpenHD-ImageBuilder --branch 2.4-evo
       cd OpenHD-ImageBuilder
       chmod a+x  shortcuts/OpenHD.desktop
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
       wget https://github.com/iNavFlight/inav-configurator/releases/download/6.0.0/INAV-Configurator_linux64_6.0.0.tar.gz
       tar -zxvf INAV-Configurator_linux64_6.0.0.tar.gz
       rm INAV-Configurator_linux64_6.0.0.tar.gz
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
       mkdir -p /boot/openhd_old
       sudo mv -v /boot/openhd/* /boot/openhd_old/
       sudo echo -e "UUID=099D-7546\t/boot/openhd\tvfat\tumask=0000\t0\t1" | sudo tee -a /etc/fstab

fi

#Install Update-Service
cp /opt/additionalFiles/update.service /etc/systemd/system/
cp /opt/additionalFiles/updateOpenHD.sh /usr/local/bin/
chmod +x /usr/local/bin/updateOpenHD.sh
systemctl enable update.service

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