# HDMI to CSI on Rock 3 Air images

Choose the adapter in the Air unit's camera settings in QOpenHD or in
ImageWriter. Reboot after changing the adapter, then choose a video mode.
The Air unit advertises the selected mode over EDID. A source with a fixed
output mode must be configured to send the corresponding progressive signal.

| Board and camera connector | TC358743, including Geekworm C790 | Radxa RK628H |
| --- | --- | --- |
| Zero 3W camera connector | 2 or 4 lanes | 2 lanes |
| Radxa CM3 on Raspberry Pi CM4 IO, CAM1 | 2 or 4 lanes | — |
| ROCK 3A / 3B camera connector | 2 lanes | — |
| ROCK 3C camera connector | 2 lanes | 2 lanes |

The two-lane TC358743 profile offers 720p30, 720p60 and 1080p30.
The four-lane TC358743 and RK628H profiles also offer 1080p60.
The Rock 3 encoder profiles use up to 1080p60. For the Radxa adapter use a
two-lane cable wired for the host connector. Connect the adapter's INT and
DET leads to header pins 29 and 31 respectively on Zero 3W and ROCK 3C,
following [Radxa's board overlay](https://github.com/radxa-pkg/radxa-overlays/commit/486008ba378fda3f31b1b7af7fcfe8f585320016).
HDMI audio requires its own I2S wiring and capture setup.

ImageBuilder compiles and checks the overlays against the installed RK356x
device trees. The kernel must include a TC358743 driver. The Zero 3W and
ROCK 3C paths also require the Rockchip RK628 CSI driver. The ROCK 3B and
ROCK 3C installer cases can be used on matching Radxa bases. The ImageBuilder
release matrix currently has a ROCK 3A and a Zero 3W recipe, and the existing
CM3 recipe can be built by target name.
