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

# Make files executable
cd /etc/init.d/
sudo chmod +x raspi-config 
cd
cd /root/wifibroadcast_misc/
sudo chmod +x gpio-config.py
sudo chmod +x wbcconfig.sh

#enable txpower from command line and RemoteSettings app
sudo chmod 755 /usr/local/bin/txpower_atheros
sudo chmod 755 /usr/local/bin/txpower_ralink

#disable sync option for usbmount
sudo sed -i 's/sync,//g' /etc/usbmount/usbmount.conf

#change hostname
CURRENT_HOSTNAME=`sudo cat /etc/hostname | sudo tr -d " \t\n\r"`
NEW_HOSTNAME="wbc"
if [ $? -eq 0 ]; then
  sudo sh -c "echo '$NEW_HOSTNAME' > /etc/hostname"
  sudo sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
fi

