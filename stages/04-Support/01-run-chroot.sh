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
        --sysconfdir=/etc --localstatedir=/var --libdir=/usr/local/lib64 \
    --prefix=/usr/local || exit 1
sudo make install || exit 1
cd ..
rm -rf mavlink-router

# Install mavlink library
cd /home/pi
cd mavlink
./rebuild_mavlink.sh
cd ..
rsync -av ./mavlink_generated/include/mavlink/v2.0/ /usr/local/include/mavlink/
cd ..
rm -rf mavlink || true
rm -rf mavlink_generated || true

# Install cmavnode
cd /home/pi
cd cmavnode
sudo mkdir build && cd build
sudo cmake .. || exit 1
sudo make || exit 1
sudo make install || exit 1
cd /home/pi/ && rm -r cmavnode

cd /home/pi/
cd LiFePO4wered-Pi
mkdir -p build/DAEMON
mkdir -p build/CLI
mkdir -p build/SO
gcc -c lifepo4wered-access.c -o build/DAEMON/lifepo4wered-access.o -std=c99 -Wall -O2
gcc -c lifepo4wered-data.c -o build/DAEMON/lifepo4wered-data.o -std=c99 -Wall -O2
gcc -c lifepo4wered-daemon.c -o build/DAEMON/lifepo4wered-daemon.o -std=c99 -Wall -O2
gcc -c lifepo4wered-access.c -o build/SO/lifepo4wered-access.o -std=c99 -Wall -O2 -fpic
gcc -c lifepo4wered-data.c -o build/SO/lifepo4wered-data.o -std=c99 -Wall -O2 -fpic
gcc -c lifepo4wered-access.c -o build/CLI/lifepo4wered-access.o -std=c99 -Wall -O2
gcc -c lifepo4wered-data.c -o build/CLI/lifepo4wered-data.o -std=c99 -Wall -O2
gcc -c lifepo4wered-cli.c -o build/CLI/lifepo4wered-cli.o -std=c99 -Wall -O2
gcc build/DAEMON/lifepo4wered-access.o build/DAEMON/lifepo4wered-data.o build/DAEMON/lifepo4wered-daemon.o -o build/DAEMON/lifepo4wered-daemon
gcc build/SO/lifepo4wered-access.o build/SO/lifepo4wered-data.o -o build/SO/liblifepo4wered.so -shared
gcc build/CLI/lifepo4wered-access.o build/CLI/lifepo4wered-data.o build/CLI/lifepo4wered-cli.o -o build/CLI/lifepo4wered-cli
./INSTALL.sh
cp lifepo4wered-data.h /usr/local/include/
# the lifepo4wered-pi build scripts start the daemon, which we dont want as it causes issues with losetup
systemctl stop lifepo4wered-daemon
killall -9 lifepo4wered-daemon
cd ..

# install OpenHDMicroservice
cd /home/pi
cd OpenHDMicroservice
git submodule update --init || exit 1
make install || exit 1

# install OpenHDRouter
cd /home/pi
cd OpenHDRouter
git submodule update --init --recursive || exit 1
make install || exit 1

cd /home/pi
