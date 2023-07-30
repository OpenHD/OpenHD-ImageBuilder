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

if [[ "${OS}" == "radxa-debian-rock5a" ]] || [[ "${OS}" == "radxa-debian-rock5b" ]] || [[ "${OS}" == "radxa-debian" ]]; then
    mkdir -p /config/openhd
    cp -r /boot/openhd/* /config/openhd
    rm -Rf /boot/openhd
    sudo ln -s /config/openhd/ /boot/openhd
    touch /boot/openhd/rock5.txt
    mkdir -p /boot/openhd/
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    touch /boot/openhd/rock5.txt
    touch /boot/openhd/ground.txt
    rm /boot/before.txt
    cp /opt/additionalFiles/before.txt /boot/before.txt

    cp -r /usr/lib/linux-image-5.10.110-99-rockchip-g1bbc04113/rockchip/* /boot/dtbo/
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

fi

ls -a /
ls -a /config

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

apt -y autoremove
apt -y clean