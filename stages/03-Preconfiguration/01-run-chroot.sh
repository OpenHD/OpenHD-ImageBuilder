#!/bin/bash

# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image
# Here we configue all our services

sudo systemctl enable NetworkManager
sudo systemctl enable openhd_sys_utils.service

if [[ "${OS}" == "raspian" ]] ; then
#We now use NetworkManager
rm -f /etc/init.d/dnsmasq
rm -f /etc/init.d/dhcpcd
sudo systemctl disable dnsmasq.service
sudo systemctl disable dhcpcd.service
sudo systemctl disable triggerhappy.service
sudo systemctl disable avahi-daemon.service
sudo systemctl disable ser2net.service
sudo systemctl disable hciuart.service
sudo systemctl disable anacron.service
sudo systemctl disable exim4.service
sudo systemctl mask hostapd.service
#remove every last bit of crap
apt clean
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s
rm -Rf /usr/share/locale/*
rm -Rf /usr/share/man/*
rm -Rf /var/swap


#Disable plymoth (boot animation)
sudo systemctl mask plymouth-start.service
sudo systemctl mask plymouth-read-write.service
sudo systemctl mask plymouth-quit-wait.service
sudo systemctl mask plymouth-quit.service

fi

if [[ "${OS}" == "debian-X20" ]]; then
echo "removed for now"
# sudo systemctl disable hostapd
# sudo systemctl disable sshd
# sudo systemctl disable networkmanager
# sudo systemctl disable networking
# sudo systemctl disable nfs-client
# sudo systemctl disable ssh
# sudo systemctl disable rsync
# sudo systemctl disable systemd-journald.service
# sudo systemctl enable temperature_guardian
ls /usr/local/bin
modprobe 88XXau_ohd
fi

if [[ "${OS}" == "radxa-debian-rock-cm3" ]]; then
sudo systemctl disable rknpu2.service
sudo systemctl disable h264_decode.service
fi

#disable network-logging
sudo systemctl disable syslog.service

#enable ssh for debug connections
sudo systemctl enable ssh

#Debug message
echo "The image now is this big"
df -h