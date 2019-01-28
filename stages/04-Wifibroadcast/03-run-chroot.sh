# On chroot

# Make fifos
sudo mkfifo /root/videofifo1
sudo mkfifo /root/videofifo2
sudo mkfifo /root/videofifo3
sudo mkfifo /root/videofifo4
sudo mkfifo /root/telemetryfifo1
sudo mkfifo /root/telemetryfifo2
sudo mkfifo /root/telemetryfifo3
sudo mkfifo /root/telemetryfifo4
sudo mkfifo /root/telemetryfifo5
sudo mkfifo /root/telemetryfifo6
sudo mkfifo /root/mspfifo

# Enable gpio service
sudo systemctl enable wbcconfig.service
sudo systemctl start wbcconfig.service

#disable unneeded services
sudo systemctl disable anacron.service
sudo systemctl disable syslog.service
sudo systemctl disable triggerhappy.service
sudo systemctl disable ser2net.service
sudo systemctl disable systemd-timesyncd.service
sudo systemctl disable hciuart.service
sudo systemctl disable exim4.service

#Mask difficult to disable services
systemctl stop systemd-journald.service
systemctl disable systemd-journald.service
systemctl mask systemd-journald.service

systemctl stop systemd-login.service
systemctl disable systemd-login.service
systemctl mask systemd-login.service

systemctl stop dbus.service
systemctl disable dbus.service
systemctl mask dbus.service

# Copy tty autologin stuff
cd /etc/systemd/system/getty.target.wants
sudo cp getty@tty1.service getty@tty2.service
sudo cp getty@tty1.service getty@tty3.service
sudo cp getty@tty1.service getty@tty4.service
sudo cp getty@tty1.service getty@tty5.service
sudo cp getty@tty1.service getty@tty6.service
sudo cp getty@tty1.service getty@tty7.service
sudo cp getty@tty1.service getty@tty8.service
sudo cp getty@tty1.service getty@tty9.service
sudo cp getty@tty1.service getty@tty10.service
sudo cp getty@tty1.service getty@tty11.service
sudo cp getty@tty1.service getty@tty12.service

# Make files executable
cd /etc/init.d/
sudo chmod +x raspi-config 
cd
cd /root/wifibroadcast_misc/
sudo chmod +x gpio-config.py
sudo chmod +x wbcconfig.sh

#enable /dev/video0
#sudo modprobe bcm2835-v4l2

#disable sync option for usbmount
sudo sed -i 's/sync,//g' /etc/usbmount/usbmount.conf

#disable unneeded services
sudo systemctl disable cron.service
sudo systemctl disable syslog.service
sudo systemctl disable journald.service
sudo systemctl disable logind.service
sudo systemctl disable triggerhappy.service
sudo systemctl disable avahi-daemon.service
sudo systemctl disable ser2net.service
sudo systemctl disable dbus.service
sudo systemctl disable systemd-timesyncd.service
sudo systemctl disable hciuart.service

#change hostname
CURRENT_HOSTNAME=`sudo cat /etc/hostname | sudo tr -d " \t\n\r"`
NEW_HOSTNAME="wbc"
if [ $? -eq 0 ]; then
  sudo sh -c "echo '$NEW_HOSTNAME' > /etc/hostname"
  sudo sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
fi

#enable txpower from command line and RemoteSettings app
sudo chmod 755 /usr/local/bin/txpower_atheros
sudo chmod 755 /usr/local/bin/txpower_ralink


