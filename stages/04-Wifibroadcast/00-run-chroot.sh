# On chroot

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

#disable sync option for usbmount
sudo sed -i 's/sync,//g' /etc/usbmount/usbmount.conf

#change hostname
CURRENT_HOSTNAME=`sudo cat /etc/hostname | sudo tr -d " \t\n\r"`
NEW_HOSTNAME="openhd"
if [ $? -eq 0 ]; then
  sudo sh -c "echo '$NEW_HOSTNAME' > /etc/hostname"
  sudo sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
fi

apt -y autoremove
apt -y clean
