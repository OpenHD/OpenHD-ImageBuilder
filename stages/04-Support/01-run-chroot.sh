# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image

#!/bin/bash

#Install Raspi2png
cd /home/pi
cd raspi2png
sudo make
sudo make install

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


apt-get --yes --force-yes install gstreamer1.0-alsa


