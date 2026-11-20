# Debian x86 OpenHD-OS

The distribution source now lives in [OpenHD/OpenHD-OS](https://github.com/OpenHD/OpenHD-OS).
`openhd-os.revision` pins the revision used by this integration.

On the Linux amd64 builder:

```sh
# Build the initial native root and image from exported component sources.
sudo bash scripts/openhd-os.sh build /opt/openhd-os-work sources.tar.gz

# Apply only new Debian 13 amd64 component/configuration packages to that cached
# root, regenerate the image and run boot/graphical-install validation.
sudo bash scripts/openhd-os.sh update /opt/openhd-os-work /path/to/new-debs

# Keep the installed desktop image near its 2 GiB target:
sudo IMAGE_BYTES=2147483648 bash scripts/openhd-os.sh update /opt/openhd-os-work /path/to/new-debs

# Refresh current desktop apps without rebuilding OpenHD:
sudo bash scripts/openhd-os.sh apps /opt/openhd-os-work
```

Keep the work directory between builds. Package-only updates do not compile
OpenHD/QOpenHD or bootstrap Debian. APT installs the changed packages and needed
dependencies; the image size gate, GPT and Btrfs checks still run. The graphical
installer writes only after the user selects a disk and acknowledges erasure.

Packages are ordinary Debian files: `openhd`, `qopenhd`, `openhd-sys-utils`,
`openhd-installer` and `openhd-os` (distribution services and boot configuration).
Use the OpenHD-OS package workflow to build these against Debian 13. Existing
Ubuntu packages are not compatible inputs.

An explicit local development checkout can be selected using
`OPENHD_OS_CHECKOUT=/path/to/OpenHD-OS`; otherwise the wrapper clones/fetches the
pinned upstream revision. The old local `debian-x86` experiment is superseded by
this separate repository and is not the integration entry point.
