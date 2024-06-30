#!/bin/bash

wget https://fra1.digitaloceanspaces.com/openhd-images/Downloader/release/2.6/OpenHD-image-radxa-zero3w--release-06-26-2024-00-28-55.img.xz
ls -a
unxz *.xz
rm -Rf *.xz
mv *.img /opt/emmc.img
curl -1sLf \
  'https://dl.cloudsmith.io/public/openhd/release/setup.deb.sh' \
  | sudo -E bash

sudo apt install -y openhd-sys-utils
#Remove firstrun scripts
rm -Rf /usr/lib/armbian/armbian-firstrun
rm -Rf /root/.not_logged_in_yet
sudo echo "flash_emmc.sh" >> /root/.bashrc
#Autologin
sudo sed -i 's/^ExecStart=.*/ExecStart=-\/sbin\/agetty --autologin root --noclear %I $TERM/' /lib/systemd/system/getty@.service

echo "______________________--DONE-______________________"