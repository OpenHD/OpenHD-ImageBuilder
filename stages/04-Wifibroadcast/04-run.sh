#!/bin/bash


on_chroot << EOF

#Move Raspi2png to wifibroadcast-misc
cd /home/pi
cd raspi2png
chmod 755 raspi2png
sudo mv raspi2png /home/pi/wifibroadcast-misc

chmod 775 /home/pi/wifibroadcast-misc/raspi2raspi


EOF
