# Raspberry Pi 5 Qt 6 ground image

The standalone builder uses the official Raspberry Pi OS Lite arm64 Trixie
image dated 2026-10-06. It verifies the uncompressed image against the SHA-256
published in Raspberry Pi's Imager catalog. The stock Pi 5 kernel, firmware,
Mesa/vc4 KMS stack and partition identifiers are retained.

Run on a Linux host with Python 3, Git, Docker, QEMU user binfmt, curl, rsync, xz, parted,
dosfstools and e2fsprogs:

```sh
sudo bash scripts/build-pi5-ground.sh /path/to/QOpenHD /path/to/OpenHD-SysUtils /path/to/work
```

The OpenHD checkout defaults to QOpenHD's parent directory. Set
`PI5_OPENHD_SOURCE` for a different checkout and `PI5_OPENHD_REVISION` to pin
its committed revision (default: `HEAD`). Its build submodules must be present.

Allow at least 12 GB of host storage. The script operates only on its image's
loop devices; it does not select or flash physical drives. Failed dependency
and compilation stages can be resumed using the same work directory.

QOpenHD uses Qt 6 from Trixie. The compositor is built from the same pinned
Weston 9.0.0 source and scanout-fence patch as the native NXP runtime, using
the Pi image's GBM/EGL/DRM libraries. No NXP Vivante or Hantro libraries are
installed. The compositor launcher selects the vc4 KMS card rather than
assuming that card0 is the display device.

The Pi decoder uses FFmpeg with slice threading and exports converted linear
NV12 frames through DMA heaps. Primary video reuses the independent Wayland
DMA-BUF subsurface; secondary and boot video use Qt 6's native external-OES
texture wrapper. Display frame leases are bounded and retained until their
Wayland/GPU use completes. H.264 and HEVC currently use software decoding;
there is no claim of hardware HEVC acceleration or measured display latency.

Qt 6 QML resources are generated separately from Qt 5 sources. This includes
compiled Qt 6 map/color-wheel shaders, unversioned imports, and Qt 6 Map pointer
handlers. The existing Qt 5 NXP/Rockchip build options remain available.

OpenHD's newest indexed dev-release portable arm64 packages are installed from
its Bookworm feed; OS packages remain on Trixie. SysUtils is rebuilt from the
supplied checkout with native Pi display ownership. OpenHD is explicitly
launched with `--ground`, and the initial SysUtils role is ground. Air camera
integration is outside this recipe.

The Web UI package needs the parallel ICU 72 runtime from Debian's signed
Bookworm archive; other Bookworm packages are pinned out except compatibility
runtimes. OpenHD itself is rebuilt with `ENABLE_AIR=OFF`, excluding the Air
camera stack and Rockchip MPP entirely. The source snapshot records committed
revisions, including every submodule, and excludes unrelated working edits.
Qt and the operating system use Trixie packages.

Outputs are `OpenHD-RPi5-Ground-Trixie.img.xz`, its SHA-256 file,
`image-manifest.txt`, and runtime/filesystem validation logs. The manifest
records component package versions, source revisions, source input hashes,
and runtime binary hashes. The image uses the existing OpenHD login convention
`openhd` / `openhd` and generates SSH host keys on the target's first boot.

Build, ELF dependency checks and filesystem checks do not prove Pi 5 boot,
HDMI output, touch input, RF reception, thermal stability or latency. Those
require testing the resulting image on an actual Pi 5.
