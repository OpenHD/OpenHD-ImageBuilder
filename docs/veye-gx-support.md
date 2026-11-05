# Raspberry Pi 4 VEYE GX + USB thermal cameras

The GX/GXC IMX662 selection is camera type 64. ImageWriter already writes this
selection and SysUtils maps it to `dtoverlay=veye_gxcam`. The camera needs its
specified external supply; do not select the raw Arducam IMX662 profile instead.

Legacy Raspbian images install `openhd-veye-gx` alongside `openhd-linux-pi`.
The addon pins the exact compatible kernel package. New kernel builds include
both the GX module and overlay directly. `prepare-veye-image.sh` checks the
installed module and copies the packaged overlay to the active boot partition.
Missing support fails image assembly rather than silently shipping an incomplete
camera setup. The check also runs for cached base images and preserves boot
camera selection.

The OpenHD runtime must include the VEYE/USB device-selection fix: it must find
the Unicam capture node instead of assuming `/dev/video0`, and USB discovery
must exclude CSI capture devices. The GX frame-rate control must use that same
resolved node. A USB thermal camera can occupy the first video device numbers.

SysUtils can restore a missing boot overlay from either the addon directory
`/usr/share/openhd/overlays` or native kernel directory
`/usr/local/share/openhd/kernel/overlays` before applying camera selection.

This path is verified on Pi 4, kernel 6.1.29-v7l+. It does not qualify Pi 5,
two simultaneous CSI receivers, or other kernel versions. A release needs the
updated runtime/SysUtils packages in its selected feed and a full image build.
