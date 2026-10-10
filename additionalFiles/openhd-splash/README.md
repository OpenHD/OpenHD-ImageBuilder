The logo is the existing OpenHD `QOpenHD/icons/round.png` asset. Plymouth draws
the logo and three pulsing blue dots directly on the display. QOpenHD's
`BootSplash.qml` uses the same layout in the permanent Qt window, before font
and model initialization and while the flight UI loads. Its opacity animators
run on the render thread. The supplied six-second `qml/boot-video.mp4` plays
once in QOpenHD before constructing the HUD, so UI construction cannot
interrupt playback. Its last frame stays rendered while the HUD loads and
prepares its first frames. The video is never looped or skipped mid-playback.

`configure-rpi-splash.sh` applies this to legacy Raspberry Pi images only.
It starts Plymouth in early userspace, without adding an initramfs or a fixed
animation delay. The vc4 driver is initialized before Plymouth selects its framebuffer.
QOpenHD releases Plymouth before opening EGLFS. The last
Plymouth frame is retained where the display driver supports it; the firmware
or EGLFS mode transition can still briefly blank the display.

OpenHD service output goes to `journalctl -u openhd`; manual console launches
remain available. Kernel output is moved off the HDMI console to tty3.

To disable the splash on a device, remove the `20-boot-splash.conf` drop-ins for
OpenHD and QOpenHD, remove `20-openhd-display.conf` from the Plymouth-start
service drop-ins, disable the Plymouth sysinit symlink, and restore the saved
`cmdline.txt` and `config.txt`. The live test device's original boot files are
in `/root/openhd-boot-backup/`.

The image installer requires a QOpenHD binary with the startup-video handoff
before enabling Plymouth. On success it writes `/boot/openhd-boot-splash.version`
with version `1`. ImageWriter uses that capability marker to restore the quiet
kernel flags and global `disable_splash=1` during flashing and existing-card
configuration. It preserves root partition, display mode and dynamic settings.
Unmarked images, including Pi 5/Glide and other SBC images, are left unchanged.
