#!/bin/bash

#dirty hack to rotate steamdeck
if grep -q "AMD Custom APU 0405" /proc/cpuinfo; then
    echo "Running on a Steam Deck."
else
    echo "Not running on a Steam Deck."
fi

depmod -a
touch /boot/openhd/resize.txt
sudo bash /usr/local/bin/openhd_resize_util.sh 53aa3d65-1043-49fa-8740-148cba90bbae 3
rm /boot/openhd/resize.txt
