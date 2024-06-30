#!/bin/bash

wget https://fra1.digitaloceanspaces.com/openhd-images/Downloader/release/2.6/OpenHD-image-radxa-zero3w--release-06-26-2024-00-28-55.img.xz
unxz OpenHD-image
rm -Rf *.xz
mv *.img /opt/emmc.img
curl -1sLf \
  'https://dl.cloudsmith.io/public/openhd/release/setup.deb.sh' \
  | sudo -E bash

sudo apt install -y openhd-sys-utils
rm -Rf /usr/lib/armbian/armbian-firstrun
echo "______________________--DONE-______________________"