curl -1sLf \
  'https://dl.cloudsmith.io/public/openhd/dev-release/setup.deb.sh' \
  | sudo -E bash
sudo apt update 
sudo apt-get install -y -o Dpkg::Options::="--force-depends" openhd
