curl -1sLf \
  'https://dl.cloudsmith.io/public/openhd/dev-release/setup.deb.sh' \
  | sudo -E bash
sudo apt update 
sudo apt download openhd
sudo apt download openhd-sys-utils

sudo dpkg --force-overwrite --ignore-depends=ALL -i *.deb
rm *.deb