# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image

#!/bin/bash

#Install Raspi2png
cd /home/pi
cd raspi2png
sudo make
sudo make install

# Install OpenVG
cd /home/pi
cd openvg
sudo make clean
sudo make library
sudo make install

# Install OMX
#cd /home/pi
#cd gst-omx
#sudo make clean
#sudo ./autogen.sh
#sudo make 
#sudo make install

# Gets stuck
# Install mavlink-router
cd /home/pi
cd mavlink-router
sudo ./autogen.sh && sudo ./configure CFLAGS='-g -O2' \
        --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib64 \
    --prefix=/usr
sudo make

# Install cmavnode
cd /home/pi
cd cmavnode
sudo mkdir build && cd build
sudo cmake ..
sudo make
sudo make install

# install wifibroadcast base
cd /home/pi
cd wifibroadcast-base
sudo make clean
sudo make

#install wifibroadcast-rc
cd /home/pi
cd wifibroadcast-rc
sudo chmod +x build.sh

#install wifibroadcast-status
cd /home/pi
cd wifibroadcast-status
sudo make clean
sudo make

#install wifibroadcast-scripts
cd /home/pi
cd wifibroadcast-scripts
# Copy to root so it runs on startup
sudo cp .profile /root/

#install wifibroadcast-misc
cd /home/pi
cd wifibroadcast-misc
sudo chmod +x ftee
#raspi2png was not working and had to be compiled
#sudo chmod +x raspi2png

#install wifibroadcast-splash
cd /home/pi
cd wifibroadcast-splash
sudo make

#patch hello_video
cd /home/pi
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

#install JoystickIn
apt-get --yes --force-yes install libsodium-dev
cd /home/pi
cd JoystickIn/JoystickIn
wget --no-check-certificate https://mirror.wheel.sk/raspbian/raspbian/pool/main/libs/libsodium/libsodium-dev_1.0.11-2_armhf.deb
dpkg -i libsodium-dev_1.0.11-2_armhf.deb
make clean
make
mv processUDP ../processUDP


#Configure scripts
chmod 755 -R /home/pi/RemoteSettings

apt-get --yes --force-yes install gstreamer1.0-alsa

#install cameracontrol

chmod 755 /home/pi/cameracontrol/cameracontrolUDP.py
pip install psutil

cd /home/pi/cameracontrol/RCParseChSrc

make clean
make RCParseCh
cp RCParseCh /home/pi/cameracontrol/RCParseCh
chmod 755 /home/pi/cameracontrol/RCParseCh


cd /home/pi/cameracontrol/IPCamera/svpcom_wifibroadcast
chmod 755 version.py
make
./wfb_keygen

sudo chmod 775 /home/pi/wifibroadcast-rc-Ath9k/rctxUDP.sh
sudo chmod 775 /home/pi/wifibroadcast-rc-Ath9k/rctxUDP_IN

sudo chmod 775 /home/pi/wifibroadcast-rc/rctxUDP.sh
sudo chmod 775 /home/pi/wifibroadcast-rc/rctxUDP_IN
