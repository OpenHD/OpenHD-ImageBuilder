# On chroot

#Ensure the runlevel is multi-target (3) could possibly be lower...
sudo systemctl set-default multi-user.target

#disable unneeded services
sudo systemctl disable dhcpcd.service
sudo systemctl disable dnsmasq.service
sudo systemctl disable regenerate_ssh_host_keys.service
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
sudo systemctl disable anacron.service
sudo systemctl disable syslog.service
sudo systemctl disable triggerhappy.service
sudo systemctl disable ser2net.service
sudo systemctl disable systemd-timesyncd.service
sudo systemctl disable hciuart.service
sudo systemctl disable exim4.service

#Disable does not work on PLYMOUTH
sudo systemctl mask plymouth-start.service
sudo systemctl mask plymouth-read-write.service
sudo systemctl mask plymouth-quit-wait.service
sudo systemctl mask plymouth-quit.service
sudo systemctl disable systemd-journal-flush.service
#this service updates runlevel changes. Set desired runlevel prior to this being disabled
sudo systemctl disable systemd-update-utmp.service
sudo systemctl disable networking.service

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

#enable /dev/video0
#sudo modprobe bcm2835-v4l2





