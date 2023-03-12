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

 if [[ "${OS}" == "debian" ]] ; then
 touch /boot/openhd/rock5.txt
 mv /usr/sbin/login /usr/sbin/nologin
 rm -Rf /lib/modules/5.10.66-27-rockchip-gea60d388902d/kernel/drivers/net/wireless/realtek
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
     wget https://openhdfpv.org/wp-content/Downloader/dt-blob.bin -P /boot/
 fi
