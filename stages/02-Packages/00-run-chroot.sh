#!/bin/bash

wget -nv https://fra1.digitaloceanspaces.com/openhd-images/Downloader/release/2.6/OpenHD-image-radxa-zero3w--release-06-26-2024-00-28-55.img.xz
ls -a
unxz *.xz
rm -Rf *.xz
mv *.img /opt/additionalFiles/emmc.img
curl -1sLf \
  'https://dl.cloudsmith.io/public/openhd/release/setup.deb.sh' \
  | sudo -E bash
sudo apt update
sudo apt install -y openhd-sys-utils
sudo echo "openhd_emmc_util.sh flash debug" >> /etc/profile
sudo sed -i 's/^ExecStart=.*/ExecStart=-\/sbin\/agetty --autologin root --noclear %I $TERM/' /lib/systemd/system/getty@.service
echo "______________________--DONE-______________________"