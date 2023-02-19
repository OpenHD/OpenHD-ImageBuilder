#!/bin/bash


echo ""
n=" ██████╗ ██████╗ ███████╗███╗   ██╗   ██╗  ██╗██████╗   " && echo "${n::${COLUMNS:-$(tput cols)}}" # some magic to cut the end on smaller terminals
n="██╔═══██╗██╔══██╗██╔════╝████╗  ██║   ██║  ██║██╔══██╗  " && echo "${n::${COLUMNS:-$(tput cols)}}"
n="██║   ██║██████╔╝█████╗  ██╔██╗ ██║   ███████║██║  ██║  " && echo "${n::${COLUMNS:-$(tput cols)}}"
n="██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║   ██╔══██║██║  ██║  " && echo "${n::${COLUMNS:-$(tput cols)}}"
n="╚██████╔╝██║     ███████╗██║ ╚████║██╗██║  ██║██████╔╝  " && echo "${n::${COLUMNS:-$(tput cols)}}"
n=" ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═════╝   " && echo "${n::${COLUMNS:-$(tput cols)}}"
echo ""

NoInt=$1

prepareOpenHD()
{
	apt update 
	apt install -y git dkms curl
	mkdir -p /opt/X86
	cd /opt/X86
	rm -Rf *
	git clone https://github.com/OpenHD/OpenHD-ImageBuilder
	cd OpenHD-ImageBuilder
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
	cd /opt/X86
	mkdir -p /boot/openhd/
	touch /boot/openhd/x86.txt
	touch /boot/openhd/ground.txt
	git clone https://github.com/OpenHD/rtl88x2bu /usr/src/rtl88x2bu-git
	git clone https://github.com/OpenHD/rtl8812au
	git clone https://github.com/aircrack-ng/rtl8188eus  
}


if ((EUID == 0))
then
	if [ $# -eq 0 ]
	then
	zenity --info --title="OpenHD Installer" --text="This Tool will install OpenHD on your Linux-System" --no-wrap
	zenity --warning --title="OpenHD Warning" --text="OpenHD may interfere with your normal Linux-System, it also allows to use frequencies and power settings, which might not be allowed in your country \nPlease note that you're the only one responsible for setting allowed values." --no-wrap

		if zenity --question --title="Confirm" --text="Do you want to install OpenHD Drivers ? \nThis will install custom drivers and services needed to run OpenHD! \nPlease remember turning off your wireless Network or switch it to another Band then OpenHD " --no-wrap 
		then	
	
			prepareOpenHD
			cd /opt/X86/rtl8812au
				if ./dkms-install.sh
				then
					zenity --info --title="Success" --text="8812AU is successfully installed." --no-wrap
				else
					zenity --warning --title="OpenHD Error" --text="Error while installing driver 8812au" --no-wrap
					zenity --warning --title="OpenHD Error" --text="When not installing OpenHD drivers, you need to install them yourself, this might cause some issues." --no-wrap
					exit
				fi
			cd /opt/X86/rtl88x2bu
			sed -i 's/PACKAGE_VERSION="@PKGVER@"/PACKAGE_VERSION="5.13.1"/g' /usr/src/rtl88x2bu-git/dkms.conf
			dkms add -m rtl88x2bu -v 5.13.1
				if dkms autoinstall 
				then
					zenity --info --title="Success" --text="88x2bu is successfully installed." --no-wrap
				else
					zenity --warning --title="OpenHD Error" --text="Error while installing driver 88x2bu" --no-wrap
					zenity --warning --title="OpenHD Error" --text="When not installing OpenHD drivers, you need to install them yourself, this might cause some issues." --no-wrap
				fi
			cd /opt/X86/rtl8188eus
			if ./dkms-install.sh 
			then
				zenity --info --title="Success" --text="rtl8188eus is successfully installed." --no-wrap
			else
				zenity --warning --title="OpenHD Error" --text="Error while installing driver rtl8188eus" --no-wrap
				zenity --warning --title="OpenHD Error" --text="When not installing OpenHD drivers, you need to install them yourself, this might cause some issues." --no-wrap
			fi
		else			
			zenity --warning --title="OpenHD Error" --text="When not installing OpenHD drivers, you need to install them yourself, this might cause some issues." --no-wrap
		fi
		
		zenity --info --title="Success" --text=" OpenHD will now install it's ubuntu repositories." --no-wrap
		curl -1sLf \
		'https://dl.cloudsmith.io/public/openhd/openhd-2-3-evo/setup.deb.sh' \
		| sudo -E bash
		echo "cloning Qopenhd and Openhd github repositories"
		apt update 
		cd /opt
		git clone --recursive https://github.com/OpenHD/OpenHD
		cd OpenHD
		./install_dep_ubuntu20.sh
		cd ..
		git clone https://github.com/OpenHD/QOpenHD
		cd QOpenHD
		chmod +x install_dep_ubuntu20_release.sh
		chmod +x install_dep_extra.sh
		./install_dep_ubuntu20_release.sh
		./install_dep_extra.sh
		sudo apt install -y openhd-qt-x86-focal mavsdk
		sudo apt install -y xinit net-tools libxcb-xinerama0 libxcb-util1 libgstreamer-plugins-base1.0-dev
		sudo apt install -y network-manager libspdlog-dev network-manager-gnome 
		sudo apt install -y openhd qopenhd
		systemctl disable openhd
		systemctl disable qopenhd
		zenity --info --title="Success" --text="OpenHD is now installed, please reboot" --no-wrap
	else
		echo "Starting in No interaction mode \n"
		echo "This Tool will install OpenHD on your Linux-System \n"
		echo "When not installing OpenHD drivers, you need to install them yourself, this might cause some issues. \n"
		prepareOpenHD
		cd /opt/X86/rtl8812au
			if ./dkms-install.sh
			then
			echo "8812AU is successfully installed.\n"
			else
					echo "Error while installing driver 8812au \n" --no-wrap
					echo "When not installing OpenHD drivers, you need to install them yourself, this might cause some issues.\n"
					exit
			fi
			
			cd /opt/X86/rtl88x2bu
			sed -i 's/PACKAGE_VERSION="@PKGVER@"/PACKAGE_VERSION="5.13.1"/g' /usr/src/rtl88x2bu-git/dkms.conf
			dkms add -m rtl88x2bu -v 5.13.1
				if dkms autoinstall
				then
					zenity --info --title="Success" --text="88x2bu is successfully installed." --no-wrap
				else
					echo "Error while installing driver 88x2bu \n" --no-wrap
					echo "When not installing OpenHD drivers, you need to install them yourself, this might cause some issues. \n"
				fi

			cd /opt/X86/rtl8188eus
				if ./dkms-install.sh
				then
					echo "rtl8188eus is successfully installed. \n"
				else
					echo "Error while installing driver rtl8188eus \n"
					echo "When not installing OpenHD drivers, you need to install them yourself, this might cause some issues. \n"
				fi
					
			echo "OpenHD will now install it's ubuntu repositories. \n"
			curl -1sLf \
			'https://dl.cloudsmith.io/public/openhd/openhd-2-2-evo/setup.deb.sh' \
			| sudo -E bash
			curl -1sLf \
			'https://dl.cloudsmith.io/public/openhd/openhd-2-2-dev/setup.deb.sh' \
			| sudo -E bash
			echo "cloning Qopenhd and Openhd github repositories"
			apt update 
			cd /opt
			git clone --recursive https://github.com/OpenHD/OpenHD
			cd OpenHD
			./install_dep_ubuntu20.sh
			cd ..
			git clone https://github.com/OpenHD/QOpenHD
			cd QOpenHD
			chmod +x install_dep_ubuntu20_release.sh
			chmod +x install_dep_extra.sh
			./install_dep_ubuntu20_release.sh
			./install_dep_extra.sh
			sudo apt install -y openhd-qt-x86-focal mavsdk
			sudo apt install -y xinit net-tools libxcb-xinerama0 libxcb-util1 libgstreamer-plugins-base1.0-dev
			sudo apt install -y network-manager libspdlog-dev network-manager-gnome 
			sudo apt install -y openhd qopenhd
			systemctl disable openhd
			systemctl disable qopenhd
			echo "OpenHD is now installed, please reboot \n"
	fi
else
	zenity --warning --title="OpenHD Warning" --text="You need to run this as root, please restart the script!" --no-wrap
	echo "You need to run this as root, please restart the script!"
	exit
fi



