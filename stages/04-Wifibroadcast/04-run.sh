#!/bin/bash


on_chroot << EOF

# Install OpenVG and flir stuff
#cd /home/pi
#sudo mkdir /home/pi/flir
#sudo mv v4l2loopback /home/pi/flir

#cd flir
#cd v4l2loopback

# for V6 architecture
#sudo make KERNELRELEASE=$KERNEL_VERSION
#sudo make KERNELRELEASE=$KERNEL_VERSION install
#sudo depmod -a -w $KERNEL_VERSION

# for V7 architecture
#sudo make KERNELRELEASE=$KERNEL_VERSION_V7
#sudo make KERNELRELEASE=$KERNEL_VERSION_V7 install
#sudo depmod -a -w $KERNEL_VERSION_V7

# move this to 00 script
#cd /home/pi/flir
#sudo git clone https://github.com/fnoop/flirone-v4l2.git
#cd flirone-v4l2
#sudo make

#Move Raspi2png to wifibroadcast-misc
cd /home/pi
cd raspi2png
chmod 755 raspi2png
sudo mv raspi2png /home/pi/wifibroadcast-misc

chmod 775 /home/pi/wifibroadcast-misc/raspi2raspi


EOF
