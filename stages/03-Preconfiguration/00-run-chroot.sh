# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image

#!/bin/bash

if [[ "${OS}" == "raspbian" && "${DISTRO}" == "stretch" ]]; then
    # fix broadcom opengl  library names without breaking anything else
    ln -sf /opt/vc/lib/libbrcmEGL.so /opt/vc/lib/libEGL.so
    ln -sf /opt/vc/lib/libEGL.so /opt/vc/lib/libEGL.so.1
    ln -sf /opt/vc/lib/libbrcmGLESv2.so /opt/vc/lib/libGLESv2.so
    ln -sf /opt/vc/lib/libbrcmGLESv2.so /opt/vc/lib/libGLESv2.so.2
    ln -sf /opt/vc/lib/libbrcmOpenVG.so /opt/vc/lib/libOpenVG.so
    ln -sf /opt/vc/lib/libbrcmWFC.so /opt/vc/lib/libWFC.so

    ln -sf /opt/vc/lib/pkgconfig/brcmegl.pc    /opt/vc/lib/pkgconfig/egl.pc
    ln -sf /opt/vc/lib/pkgconfig/brcmglesv2.pc /opt/vc/lib/pkgconfig/glesv2.pc
    ln -sf /opt/vc/lib/pkgconfig/brcmvg.pc     /opt/vc/lib/pkgconfig/vg.pc
fi



# On platforms that already have a separate boot partition we just put the config files on there, but some
# platforms don't have or need a boot partition, so on those we have a separate /conf partition. All
# openhd components look to /conf, so a symlink works well here. We may end up using separate /conf on everything.
if [[ "${HAVE_CONF_PARTITION}" == "false" ]] && [[ "${HAVE_BOOT_PARTITION}" == "true" ]]; then
    ln -s /boot /conf
fi


#Ensure the runlevel is multi-target (3) could possibly be lower...
sudo systemctl set-default multi-user.target


rm /etc/init.d/dnsmasq
rm /etc/init.d/dhcpcd


#disable unneeded services
sudo systemctl disable dhcpcd.service
sudo systemctl disable dnsmasq.service
sudo systemctl disable cron.service
sudo systemctl disable syslog.service
sudo systemctl disable journald.service
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
sudo systemctl disable systemd-journal-flush.service
#this service updates runlevel changes. Set desired runlevel prior to this being disabled
sudo systemctl disable systemd-update-utmp.service
sudo systemctl disable networking.service

#Mask difficult to disable services
systemctl stop systemd-journald.service
systemctl disable systemd-journald.service
systemctl mask systemd-journald.service



#enable /dev/video0
#sudo modprobe bcm2835-v4l2




sudo rm /etc/init.d/resize2fs_once

# Disable ZeroTier service
#sudo systemctl disable zerotier-one

# Copy tty autologin stuff
systemctl enable getty@tty1.service
systemctl enable getty@tty2.service
systemctl enable getty@tty3.service
systemctl enable getty@tty4.service
systemctl enable getty@tty5.service
systemctl enable getty@tty6.service
systemctl enable getty@tty7.service
systemctl enable getty@tty8.service
systemctl enable getty@tty9.service
systemctl enable getty@tty10.service
systemctl enable getty@tty11.service
systemctl enable getty@tty12.service

#change hostname
CURRENT_HOSTNAME=`sudo cat /etc/hostname | sudo tr -d " \t\n\r"`
NEW_HOSTNAME="openhd"
if [ $? -eq 0 ]; then
  sudo sh -c "echo '$NEW_HOSTNAME' > /etc/hostname"
  sudo sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
fi

apt -y autoremove
apt -y clean

