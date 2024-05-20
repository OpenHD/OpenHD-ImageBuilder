#!/bin/bash

echo "Starting OpenHD installation..."
echo ""
n=" ██████╗ ██████╗ ███████╗███╗   ██╗██╗  ██╗██████╗   " && echo "${n::${COLUMNS:-$(tput cols)}}" # some magic to cut the end on smaller terminals
n="██╔═══██╗██╔══██╗██╔════╝████╗  ██║██║  ██║██╔══██╗  " && echo "${n::${COLUMNS:-$(tput cols)}}"
n="██║   ██║██████╔╝█████╗  ██╔██╗ ██║███████║██║  ██║  " && echo "${n::${COLUMNS:-$(tput cols)}}"
n="██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██╔══██║██║  ██║  " && echo "${n::${COLUMNS:-$(tput cols)}}"
n="╚██████╔╝██║     ███████╗██║ ╚████║██║  ██║██████╔╝  " && echo "${n::${COLUMNS:-$(tput cols)}}"
n=" ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═════╝   " && echo "${n::${COLUMNS:-$(tput cols)}}"
echo ""

prepareOpenHD()
{
    echo "Preparing OpenHD..."
    mkdir -p /opt/X86
    cp -rv * /opt/X86/
    current_dir=$(pwd)
    cd ..
    rm -Rf $current_dir
    apt update || { echo "Failed to update package lists"; exit 1; }
    mkdir -p /boot/openhd/
    touch /boot/openhd/x86.txt
    touch /boot/openhd/ground.txt
    git clone https://github.com/OpenHD/rtl88x2bu /usr/src/rtl88x2bu-5.13.1 || { echo "Failed to clone rtl88x2bu repository"; exit 1; }
    git clone https://github.com/OpenHD/rtl8812au /usr/src/rtl8812au-git || { echo "Failed to clone rtl8812au repository"; exit 1; }
    echo "OpenHD preparation completed successfully."
}

installShortcuts()
{
    echo "Installing shortcuts..."
    cd /opt/X86/
    cp desktop-truster.sh /etc/profile.d/desktop-truster.sh || { echo "Failed to copy desktop-truster.sh"; exit 1; }
    chmod +777 /etc/profile.d/desktop-truster.sh
    chmod a+x /etc/profile.d/desktop-truster.sh
    chmod a+x shortcuts/OpenHD-Air.desktop
    chmod a+x shortcuts/OpenHD-Ground.desktop
    chmod a+x shortcuts/QOpenHD.desktop
    rm -Rf shortcuts/MissionPlanner.desktop
    rm -Rf shortcuts/INAV.desktop
    rm -Rf shortcuts/qgroundcontrol.desktop
    rm -Rf shortcuts/QOpenHD2.desktop
    rm -Rf shortcuts/OpenHD.desktop
    rm -Rf shortcuts/nm-tray-autostart.desktop
    rm -Rf shortcuts/steamdeck.desktop
    rm -Rf shortcuts/OpenHD-ImageWriter.desktop
    for homedir in /home/*; do sudo cp shortcuts/*.desktop "$homedir"/Desktop/; done
    for homedir in /home/*; do gio set /home/$homedir/Desktop/OpenHD-Air.desktop metadata::trusted true; done
    for homedir in /home/*; do gio set /home/$homedir/Desktop/OpenHD-Ground.desktop metadata::trusted true; done
    for homedir in /home/*; do gio set /home/$homedir/Desktop/QOpenHD.desktop metadata::trusted true; done
    echo "Service and GIO ERRORS CAN BE IGNORED"
    sudo cp shortcuts/* /usr/share/applications/
    sudo cp shortcuts/OpenHD.ico /opt/
    echo "Shortcuts installed successfully."
}

installRtl8812au()
{
    echo "Installing RTL8812AU..."
    cd /usr/src/rtl8812au-git
    ./dkms-install.sh || { echo "Failed to install RTL8812AU"; exit 1; }
    echo "RTL8812AU installed successfully."
}

installRtl8812bu()
{
    echo "Installing RTL8812BU..."
    cd /usr/src/rtl88x2bu-5.13.1
    sed -i 's/PACKAGE_VERSION="@PKGVER@"/PACKAGE_VERSION="5.13.1"/g' /usr/src/rtl88x2bu-5.13.1/dkms.conf
    dkms add -m rtl88x2bu -v 5.13.1 || { echo "Failed to install RTL8812BU"; exit 1; }
    echo "RTL8812BU installed successfully."
}

installOpenHDRepositories()
{
    echo "Installing OpenHD repositories..."
    apt install -y git dkms curl || { echo "Failed to install required packages"; exit 1; }
    curl -1sLf 'https://dl.cloudsmith.io/public/openhd/release/setup.deb.sh' | sudo -E bash || { echo "Failed to clone OpenHD repositories"; exit 1; }
    echo "OpenHD repositories installed successfully."
}

installOpenHD()
{
    echo "Installing OpenHD..."
    sudo apt update || { echo "Failed to update package lists"; exit 1; }
    sudo apt install -y openhd qopenhd open-hd-web-ui || { echo "Failed to install OpenHD packages"; exit 1; }
    systemctl disable openhd
    systemctl disable qopenhd
    echo "OpenHD installed successfully."
}

cleanup()
{
    echo "Cleaning up..."
    rm -Rf /opt/X86
    echo "Installer finished"
    echo "Please reboot now"
}

# Main Setup

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Aborting."
    exit 1
fi

installOpenHDRepositories
prepareOpenHD
installRtl8812au
installRtl8812bu
installOpenHD || { echo "Failed to install OpenHD"; exit 1; }
installShortcuts
cleanup
