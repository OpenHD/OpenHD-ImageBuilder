# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image

#!/bin/bash

# Install OpenVG
cd /home/pi
cd openvg
sudo make clean
sudo make library
sudo make install

# Install FLIROne Driver
cd /home/pi
cd Open.HD_FlirOneDrv
cd flir8p1-gpl
sudo make
sudo chmod +x flir8p1

# install wifibroadcast base
cd /home/pi
cd wifibroadcast-base
sudo make clean
sudo make


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
cd /home/pi
cd JoystickIn/JoystickIn
make clean
make
mv processUDP ../processUDP

#Configure scripts
chmod 755 -R /home/pi/RemoteSettings

#install cameracontrol

chmod 755 /home/pi/cameracontrol/cameracontrolUDP.py
chmod 755 /home/pi/cameracontrol/LoadFlirDriver.sh
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



cd /home/pi/wifibroadcast-rc-Ath9k
sudo chmod 775 /home/pi/wifibroadcast-rc-Ath9k/buildlora.sh
sudo /home/pi/wifibroadcast-rc-Ath9k/buildlora.sh
sudo chmod 775 /home/pi/wifibroadcast-rc-Ath9k/lora
cp /home/pi/wifibroadcast-rc-Ath9k/lora /usr/local/bin/

sudo chmod 775 /home/pi/wifibroadcast-rc-Ath9k/build.sh
sudo /home/pi/wifibroadcast-rc-Ath9k/build.sh
sudo chmod 775 /home/pi/wifibroadcast-rc-Ath9k/rctx
cp /home/pi/wifibroadcast-rc-Ath9k/rctx /usr/local/bin/


cd /home/pi/wifibroadcast-osd
make -j5 || exit 1
cd ..


cd /home/pi/wifibroadcast-misc/LCD
sudo make
chmod 755 /home/pi/wifibroadcast-misc/LCD/MouseListener

 rm /etc/init.d/dnsmasq
 rm /etc/init.d/dhcpcd


#
# this is a temporary step to reduce the image build time just like the qt package.
# in 2.1 we will use real deb packages
cd /home/pi/
QOPENHD_PACKAGE="QOpenHD-${QOPENHD_VERSION}-${IMAGE_ARCH}-${DISTRO}-Qt${QT_VERSION}-${QT_MINOR_RELEASE}.tar.gz"
QOPENHD_PACKAGE_URL="${QOPENHD_REPO%.*}/releases/download/${QOPENHD_VERSION}/${QOPENHD_PACKAGE}"
wget ${QOPENHD_PACKAGE_URL} || exit 1
tar xvf ${QOPENHD_PACKAGE} || exit 1
mv QOpenHD /usr/local/bin/ || exit 1
mv OpenHDBoot /usr/local/bin/ || exit 1
rm ${QOPENHD_PACKAGE} || exit 1

