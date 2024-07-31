curl -1sLf \
  'https://dl.cloudsmith.io/public/openhd/dev-release/setup.deb.sh' \
  | sudo -E bash
curl -1sLf \
  'https://dl.cloudsmith.io/public/openhd/release/setup.deb.sh' \
  | sudo -E bash
sudo apt update 
sudo mkdir -p /boot/openhd/scripts/
sudo touch /boot/openhd/scripts/custom_unmanaged_camera.sh
sudo apt download openhd
sudo dpkg --force-overwrite --ignore-depends=ALL -i *.deb
rm *.deb
sudo apt download openhd-sys-utils
sudo dpkg --force-overwrite --ignore-depends=ALL -i *.deb
rm *.deb
