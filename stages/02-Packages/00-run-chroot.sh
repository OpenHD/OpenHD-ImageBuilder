curl -1sLf \
  'https://dl.cloudsmith.io/public/openhd/dev-release/setup.deb.sh' \
  | sudo -E bash
sudo apt update 
sudo apt download openhd

sudo dpkg --ignore-depends=ALL -i *.deb
rm *.deb