#!/bin/bash


echo ""
n=" ██████╗ ██████╗ ███████╗███╗   ██╗   ██╗  ██╗██████╗   " && echo "${n::${COLUMNS:-$(tput cols)}}" # some magic to cut the end on smaller terminals
n="██╔═══██╗██╔══██╗██╔════╝████╗  ██║   ██║  ██║██╔══██╗  " && echo "${n::${COLUMNS:-$(tput cols)}}"
n="██║   ██║██████╔╝█████╗  ██╔██╗ ██║   ███████║██║  ██║  " && echo "${n::${COLUMNS:-$(tput cols)}}"
n="██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║   ██╔══██║██║  ██║  " && echo "${n::${COLUMNS:-$(tput cols)}}"
n="╚██████╔╝██║     ███████╗██║ ╚████║██╗██║  ██║██████╔╝  " && echo "${n::${COLUMNS:-$(tput cols)}}"
n=" ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═════╝   " && echo "${n::${COLUMNS:-$(tput cols)}}"
echo ""

prepareOpenHD()
{
	apt update 
	apt install -y git dkms curl
	mkdir -p /boot/openhd/
	touch /boot/openhd/x86.txt
	touch /boot/openhd/ground.txt
	git clone https://github.com/OpenHD/rtl88x2bu /usr/src/rtl88x2bu-git
	git clone https://github.com/OpenHD/rtl8812au
	git clone https://github.com/aircrack-ng/rtl8188eus  
}
installShortcuts()
{
cd OpenHD-ImageBuilder
	cd /opt/X86
	rm -Rf *
	git clone https://github.com/OpenHD/OpenHD-ImageBuilder
	cp desktop-truster.sh /etc/profile.d/desktop-truster.sh
	chmod +777 /etc/profile.d/desktop-truster.sh
	chmod a+x  /etc/profile.d/desktop-truster.sh
	chmod a+x  shortcuts/OpenHD-Air.desktop
	chmod a+x  shortcuts/OpenHD-Ground.desktop
	chmod a+x  shortcuts/QOpenHD.desktop
	for homedir in /home/*; do sudo cp shortcuts/*.desktop "$homedir"; done
	for homedir in /home/*; do gio set /home/$homedir/Desktop/OpenHD-Air.desktop metadata::trusted true; done
	for homedir in /home/*; do gio set /home/$homedir/Desktop/OpenHD-Ground.desktop metadata::trusted true; done
	for homedir in /home/*; do gio set /home/$homedir/Desktop/QOpenHD.desktop metadata::trusted true; done
	sudo cp shortcuts/* /usr/share/applications/
	sudo cp shortcuts/OpenHD.ico /opt/
}
installRtl8812au()
{
cd /opt/X86/rtl8812au
./dkms-install.sh
echo "Installed RTL8812AU"
}
installRtl8812bu()
{
cd /usr/src/rtl88x2bu-git
sed -i 's/PACKAGE_VERSION="@PKGVER@"/PACKAGE_VERSION="5.13.1"/g' /usr/src/rtl88x2bu-git/dkms.conf
dkms add -m rtl88x2bu -v 5.13.1
echo "Installed RTL8812BU"
}
installOpenHDRepositories()
{
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-3-evo/setup.deb.sh'	| sudo -E bash
echo "Cloned Qopenhd and Openhd github repositories"
}
installOpenHD()
{
sudo apt install -y openhd qopenhd open-hd-web-ui 
systemctl disable openhd
systemctl disable qopenhd
}

#Main Setup

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Aborting."
  exit 1
fi

prepareOpenHD
installRtl8812au
installRtl8812bu
installOpenHD



