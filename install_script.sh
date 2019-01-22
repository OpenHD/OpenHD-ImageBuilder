#!/bin/bash

set -e
set -u

# disable dhcpcd service
sudo systemctl stop dhcpcd.service
sudo systemctl disable dhcpcd.service

# Latest package source
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get clean
sudo apt-get update

# Remove all X related (2,3 Gb of Disk space freed...) 
# Should be fixed with lite image
#sudo apt-get -y remove --auto-remove --purge libx11-.*

# Install essentials
#export DEBIAN_FRONTEND=noninteractive
#untill we find a way for noniteractive
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install python-pip
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install aircrack-ng
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gnuplot
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install udhcpd
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install socat
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install tshark
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install ser2net
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-tools
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-plugins-bad
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install gstreamer1.0-plugins-good
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libtool
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install autoconf
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libsdl1.2-dev
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libboost-all-dev cmake libconfig++-dev libreadline-dev
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install git libpcap-dev wiringpi iw usbmount
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libjpeg8-dev indent libfreetype6-dev ttf-dejavu-core
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install python-m2crypto
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install dos2unix
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install hostapd
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install pump
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libpng12-dev
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install python-future python-attr
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libfontconfig1-dev 
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libsdl2-dev
DEBIAN_FRONTEND=noninteractive sudo apt-get -yq install libsdl1.2-dev

#sudo apt-get -y install tofrodos
#sudo ln -s /usr/bin/fromdos /usr/bin/dos2unix

# Python essentials for mavlink router autoconf
#sudo easy_install pip
sudo pip install future

# Wifi reg patch
cd /home/pi
sudo wget https://mirrors.edge.kernel.org/pub/software/network/wireless-regdb/wireless-regdb-2018.09.07.tar.xz
sudo tar xf wireless-regdb-2018.09.07.tar.xz
cd wireless-regdb-2018.09.07
sudo sed -i '3cCRDA_PATH ?= /lib/crda' Makefile

# Rewrite db
sudo sh -c "echo -n '' > db.txt"
sudo sh -c "echo 'country 00:' >> db.txt"
sudo sh -c "echo '(2302 - 2742 @ 40), (30)' >> db.txt"
sudo sh -c "echo '(5170 - 5250 @ 80), (30), AUTO-BW' >> db.txt"
sudo sh -c "echo '(5250 - 5330 @ 80), (30), DFS, AUTO-BW' >> db.txt"
sudo sh -c "echo '(5490 - 5730 @ 160), (30), DFS' >> db.txt"
sudo sh -c "echo '(5735 - 5835 @ 80), (30)' >> db.txt"
sudo sh -c "echo '' >> db.txt"
sudo sh -c "echo 'country US: DFS-FCC' >> db.txt"
sudo sh -c "echo '(2302 - 2742 @ 40), (30)' >> db.txt"
sudo sh -c "echo '(5170 - 5250 @ 80), (30), AUTO-BW' >> db.txt"
sudo sh -c "echo '(5250 - 5330 @ 80), (30), DFS, AUTO-BW' >> db.txt"
sudo sh -c "echo '(5490 - 5730 @ 160), (30), DFS' >> db.txt"
sudo sh -c "echo '(5735 - 5835 @ 80), (30)' >> db.txt"

# Now make and install
sudo make
sudo make install
sudo iw reg set US || true
sudo sed -i 's/REGDOMAIN=/REGDOMAIN=US/g' /etc/default/crda

# Install OpenVG
cd /home/pi
#sudo git clone --verbose https://github.com/ajstarks/openvg.git
cd openvg
sudo make clean
sudo make library
sudo make install

# Gets stuck
# Install mavlink-router
cd /home/pi
#sudo git clone --progress https://github.com/intel/mavlink-router.git 
cd mavlink-router
#sudo git submodule update --init --recursive --progress
sudo ./autogen.sh && sudo ./configure CFLAGS='-g -O2' \
        --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib64 \
    --prefix=/usr
sudo make

# Install cmavnode
cd /home/pi
#sudo git clone https://github.com/MonashUAS/cmavnode.git
cd cmavnode
#sudo git submodule update --init
sudo mkdir build && cd build
sudo cmake ..
sudo make
sudo make install

# install wifibroadcast base
cd /home/pi
#sudo git clone https://github.com/RespawnDespair/wifibroadcast-base.git
cd wifibroadcast-base
#sudo git submodule init
#sudo git submodule update
sudo make clean
sudo make

#install wifibroadcast-osd
#cd /home/pi
#cd wifibroadcast-osd
#sudo make clean
#sudo make

#install wifibroadcast-rc
cd /home/pi
#sudo git clone https://github.com/RespawnDespair/wifibroadcast-rc.git
cd wifibroadcast-rc
sudo chmod +x build.sh
#sudo ./build.sh

#install wifibroadcast-status
cd /home/pi
cd wifibroadcast-status
sudo make clean
sudo make

#install wifibroadcast-scripts
cd /home/pi
#sudo git clone https://github.com/RespawnDespair/wifibroadcast-scripts.git
cd wifibroadcast-scripts
# Copy to root so it runs on startup
sudo cp .profile /root/

#install wifibroadcast-misc
cd /home/pi
#sudo git clone https://github.com/RespawnDespair/wifibroadcast-misc.git
cd wifibroadcast-misc
sudo chmod +x ftee
sudo chmod +x raspi2png


#patch hello_video
cd /home/pi
#git clone https://github.com/RespawnDespair/wifibroadcast-hello_video.git
sudo cp wifibroadcast-hello_video/* /opt/vc/src/hello_pi/hello_video/
# REBUILDING DOES NOT WORK, BINARIES INCLUDED IN GIT
cd /opt/vc/src/hello_pi/hello_video
sudo rm hello_video.bin.48-mm 2> /dev/null || echo > /dev/null
sudo rm hello_video.bin.30-mm 2> /dev/null || echo > /dev/null
sudo rm hello_video.bin.240-befi 2> /dev/null || echo > /dev/null

sudo cp video.c.48-mm video.c
cd ..
sudo make
cd /opt/vc/src/hello_pi/hello_video
mv hello_video.bin hello_video.bin.48-mm

sudo cp video.c.30-mm video.c
cd ..
sudo make
cd /opt/vc/src/hello_pi/hello_video
mv hello_video.bin hello_video.bin.30-mm

sudo cp video.c.240-befi video.c
cd ..
sudo make
cd /opt/vc/src/hello_pi/hello_video
mv hello_video.bin hello_video.bin.240-befi


#install new firmware
#sudo cp "patches/AR9271/firmware/htc_9271.fw" "/lib/firmware"

# Make fifos
sudo mkfifo /root/videofifo1
sudo mkfifo /root/videofifo2
sudo mkfifo /root/videofifo3
sudo mkfifo /root/videofifo4
sudo mkfifo /root/telemetryfifo1
sudo mkfifo /root/telemetryfifo2
sudo mkfifo /root/telemetryfifo3
sudo mkfifo /root/telemetryfifo4
sudo mkfifo /root/telemetryfifo5
sudo mkfifo /root/telemetryfifo6
sudo mkfifo /root/mspfifo

# Copy tty autologin stuff
cd /etc/systemd/system/getty.target.wants
sudo cp getty@tty1.service getty@tty2.service
sudo cp getty@tty1.service getty@tty3.service
sudo cp getty@tty1.service getty@tty4.service
sudo cp getty@tty1.service getty@tty5.service
sudo cp getty@tty1.service getty@tty6.service
sudo cp getty@tty1.service getty@tty7.service
sudo cp getty@tty1.service getty@tty8.service
sudo cp getty@tty1.service getty@tty9.service
sudo cp getty@tty1.service getty@tty10.service
sudo cp getty@tty1.service getty@tty11.service
sudo cp getty@tty1.service getty@tty12.service

# raspi-config is not executable after copy
cd /etc/init.d/
sudo chmod +x raspi-config 

#enable /dev/video0
#sudo modprobe bcm2835-v4l2

#disable sync option for usbmount
sudo sed -i 's/sync,//g' /etc/usbmount/usbmount.conf

#change hostname
CURRENT_HOSTNAME=`sudo cat /etc/hostname | sudo tr -d " \t\n\r"`
NEW_HOSTNAME="wbc"
if [ $? -eq 0 ]; then
  sudo sh -c "echo '$NEW_HOSTNAME' > /etc/hostname"
  sudo sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
fi



