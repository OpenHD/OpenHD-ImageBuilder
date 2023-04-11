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

#Disable does not work on PLYMOUTH
sudo systemctl mask plymouth-start.service
sudo systemctl mask plymouth-read-write.service
sudo systemctl mask plymouth-quit-wait.service
sudo systemctl mask plymouth-quit.service
if [[ "${OS}" != "ubuntu" ]] || [[ "${OS}" != "ubuntu-x86" ]]; then
    echo "OS is NOT ubuntu..disabling journald flush"
    sudo systemctl disable systemd-journal-flush.service
fi

if [[ "${OS}" == "radxa-ubuntu" ]] ; then
       systemctl enable fan-control
       systemctl disable openhd
fi

if [[ "${OS}" == "ubuntu" ]]; then
       systemctl disable nv-oem-config-gui.service
       systemctl enable getty@tty1.service
fi

if [[ "${OS}" == "debian" ]]; then
       systemctl disable lightdm
fi


