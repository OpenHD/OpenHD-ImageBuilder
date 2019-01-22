#!/bin/bash


on_chroot << EOF

# Install OpenVG and flir stuff
cd /home/pi
sudo mkdir /home/pi/flir
sudo mv v4l2loopback /home/pi/flir

cd flir
cd v4l2loopback

# for V6 architecture
sudo make KERNELRELEASE=$KERNEL_VERSION
sudo make KERNELRELEASE=$KERNEL_VERSION install
sudo depmod -a -w $KERNEL_VERSION

# for V7 architecture
sudo make KERNELRELEASE=$KERNEL_VERSION_V7
sudo make KERNELRELEASE=$KERNEL_VERSION_V7 install
sudo depmod -a -w $KERNEL_VERSION_V7

# FLIR ONE
sudo mv /home/pi/flirone-v4l2 /home/pi/flir/flirone-v4l2
cd /home/pi/flir/flirone-v4l2
sudo make

EOF
