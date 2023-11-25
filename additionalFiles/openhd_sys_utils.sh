#!/bin/bash

# This script handles initial configuation, updates and misc features which aren't included in the main OpenHD executable (yet)

# debug mode (shows journaldctl on the screen when logged in)
debug_file="/boot/openhd/debug.txt"
if [ -e "$debug_file" ]; then
    echo "debug mode selected"
    echo "sudo journalctl -f" >> /root/.bashrc
fi

# initialise functions
if [ -f "/boot/openhd/hardware_vtx_v20.txt" ]; then
 sudo bash /usr/local/bin/initX20.sh
 #rm /boot/openhd/hardware_vtx_v20.txt
fi

if [ -f "/boot/openhd/x86.txt" ]; then
 sudo bash /usr/local/bin/initX86.sh
 rm /boot/openhd/x86.txt
fi

if [ -f "/boot/openhd/rock-5a.txt" ]; then
  sudo bash /usr/local/bin/initRock.sh
  rm /boot/openhd/rock-5a.txt
fi

if [ -f "/boot/openhd/rock-5b.txt" ]; then
  sudo bash /usr/local/bin/initRock.sh
  rm /boot/openhd/rock-5b.txt
fi

if [ -f "/boot/openhd/rock-rk3566.txt" ]; then
  sudo bash /usr/local/bin/initRock.sh
  echo "(pv -n /dev/mmcblk1 | dd of=/dev/mmcblk0 bs=128M conv=notrunc,noerror) 2>&1 | whiptail --gauge "Running dd command (cloning), please wait..." 10 70 0" >> /root/.bashrc
  systemctl enable openhd
  rm /boot/openhd/rock-rk3566.txt
  reboot
fi

if [ -f "/boot/openhd/rpi.txt" ]; then
  if [ -f "/boot/openhd/air.txt" ]; then
  sudo bash /usr/local/bin/initPi.sh
  rm /boot/openhd/rpi.txt
  fi
fi
touch /boot/openhd/IRan.txt
