# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image

#!/bin/bash

# create a use account that should be the same on all platforms
useradd openhd
echo "openhd:openhd" | chpasswd
adduser openhd sudo

#add debug script and cronjob
cd /opt
git clone https://github.com/OpenHD/OpenHD-debug
cd OpenHD-debug
chmod +x debug.sh
crontab -l > mycron
echo "@reboot /opt/OpenHD-debug/debug.sh" >> mycron
crontab mycron
rm mycron
systemctl enable cron.service



# On platforms that already have a separate boot partition we just put the config files on there, but some
# platforms don't have or need a boot partition, so on those we have a separate /conf partition. All
# openhd components look to /conf, so a symlink works well here. We may end up using separate /conf on everything.
if [[ "${HAVE_CONF_PART}" == "false" ]] && [[ "${HAVE_BOOT_PART}" == "true" ]]; then
    ln -s /boot /conf
fi


if [[ "${OS}" == "raspbian" ]]; then
    echo "disabling first run script"
    git clone https://github.com/OpenHD/firstrun
    cd firstrun
    cp firstrun.sh /boot/conf

fi

#Ensure the runlevel is multi-target (3) could possibly be lower...
sudo systemctl set-default multi-user.target


rm /etc/init.d/dnsmasq
rm /etc/init.d/dhcpcd


#disable unneeded services
sudo systemctl disable dhcpcd.service
sudo systemctl disable dnsmasq.service
sudo systemctl disable syslog.service
if [[ "${OS}" != "testing" ]] || [[ "${OS}" != "milestone" ]]; then
    echo "disabling journald"
    sudo systemctl disable journald.service
fi
sudo systemctl disable triggerhappy.service
sudo systemctl disable avahi-daemon.service
sudo systemctl disable ser2net.service
sudo systemctl disable hciuart.service
sudo systemctl disable anacron.service
sudo systemctl disable exim4.service
sudo systemctl mask hostapd.service
sudo systemctl mask wpa_supplicant.service

#Disable does not work on PLYMOUTH
sudo systemctl mask plymouth-start.service
sudo systemctl mask plymouth-read-write.service
sudo systemctl mask plymouth-quit-wait.service
sudo systemctl mask plymouth-quit.service
if [[ "${OS}" != "ubuntu" ]]; then
    echo "OS is NOT ubuntu..disabling journald flush"
    sudo systemctl disable systemd-journal-flush.service
fi
#this service updates runlevel changes. Set desired runlevel prior to this being disabled
sudo systemctl disable systemd-update-utmp.service
sudo systemctl disable networking.service

sudo rm /etc/init.d/resize2fs_once

# Disable ZeroTier service
#sudo systemctl disable zerotier-one

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

