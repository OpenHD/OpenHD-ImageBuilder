curl -1sLf \
  'https://dl.cloudsmith.io/public/openhd/dev-release/setup.deb.sh' \
  | sudo -E bash
curl -1sLf \
  'https://dl.cloudsmith.io/public/openhd/release/setup.deb.sh' \
  | sudo -E bash
sudo apt update 
sudo mkdir -p /boot/openhd/scripts/
sudo touch /boot/openhd/scripts/custom_unmanaged_camera.sh
sudo apt download openhd-x20
sudo dpkg --force-overwrite --ignore-depends=ALL -i *.deb
rm *.deb
sudo apt download openhd-sys-utils
sudo dpkg --force-depends --force-overwrite -i openhd-sys-utils_0.4-07-31-2024--17-37-18_armhf.deb
rm *.deb
sudo rm -Rf /config/openhd/hardware.config