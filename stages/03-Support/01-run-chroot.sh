# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image

#!/bin/bash

# Install mavlink library
cd /home/pi
cd mavlink
./rebuild_mavlink.sh
cd ..
rsync -av ./mavlink_generated/include/mavlink/v2.0/ /usr/local/include/mavlink/
cd ..
rm -rf mavlink || true
rm -rf mavlink_generated || true

cd /home/pi/veye_raspberrypi/veye_raspcam/source
chmod +x buildme
./buildme
cp veye_* /usr/local/bin/
cp /home/pi/veye_raspberrypi/i2c_cmd/bin/* /usr/local/bin/
chmod -R +x /usr/local/bin/*

cd /home/pi
