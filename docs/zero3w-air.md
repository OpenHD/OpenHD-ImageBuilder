# Zero 3W Air with Raspberry Pi Camera Module 3

Build the full image from a Linux host with the standard ImageBuilder dependencies.

```bash
touch additionalFiles/dev-build
sudo ./build.sh radxa-zero3w false false true
```

The image uses the existing OpenHD Bullseye base with kernel
`5.10.160-radxa-rk356x` and RKAIQ `5.0x1.2-rc2`. The build installs the
IMX708 and DW9817 modules, and stages the Zero 3W CSI overlay. In ImageWriter, select Air, IMX708 and 1920x1080@60. SysUtils activates the overlay on first boot. The IMX708 startup hook applies 3× sensor digital gain. It also installs the native RK3566 QOpenHD
package for Ground mode.

The active profile combines IMX708 exposure and focus settings with the RK3566 reference ISP21 processing and the corrected gain scale. Both of Avaf's profiles produced black
ISP output on the tested Zero 3W and are available for further tuning under
`/usr/share/openhd/iq-profiles/imx708/`. For
manual focus, identify the DW9817 subdevice with `media-ctl -p` and set
its `focus_absolute` V4L2 control.

The bench test should check that the sensor and lens appear in the media
graph, RKAIQ selects the `uhq` profile, OpenHD opens `rkisp_mainpath` and
encodes with MPP, and Ground receives stable video through the intended
radio. Check focus and exposure against a real scene before calling the
profile validated.

OpenHD reports the selected codec in `OPENHD_CAMERA_STATUS_AIR`. QOpenHD
uses that telemetry to select the decoder on its native Rockchip backend.
An RTP-only receiver needs a
matching SDP or explicit codec configuration because both codecs use dynamic
payload type 96.

The startup hook defaults to the 1920x1080 readout and a 60 fps exposure budget. OpenHD selects the cropped 1536x864 readout and its matching RKAIQ profile for 720p120. The image requires
the arm64 OpenHD package with the MPP-only Zero 3W executable and configures
the OpenHD service to launch it. The runtime uses MPP revision
`20959ec3dabb313b8c33ca0b7b09c06ffd2a9caa`, matching the X21B production
manifest. In QOpenHD, select H.264 or H.265 under OpenHD > Camera > Stream.
Check both capture and encoded frame rates on the live unit.

720p120 selects the cropped sensor readout, but remains experimental on the
5.10 RK3566 image. Verify the actual capture and encoded rates and inspect the
picture. Bench tests observed a stall with the fixed-120 RKAIQ profile and a
very low bitrate when the cropped readout did produce frames. Select a 60 fps
mode for normal operation.

[Avaf's tuning and compatibility table](https://github.com/avafinger/rockchip-iqfiles)

## Other Sony profiles

The Rock 5 image carries the OpenHD IMX477 profile and its IMX577 alias.
Avaf's Rock 5 RKAIQ 6 IMX290 profile is also available under
`/usr/share/openhd/iq-profiles/rock5-rkaiq6/`, with aliases for IMX327 and
IMX462. To try it on an IMX462 with RKAIQ `6.0x6.1` and ISP `2.4.0`,
use the filename expected by that camera's overlay. For example, for
module `imx462` and lens `default`:

```bash
sudo ln -sfn /usr/share/openhd/iq-profiles/rock5-rkaiq6/imx462_imx462_default.json \
    /etc/iqfiles/imx462_imx462_default.json
sudo systemctl restart rkaiq_3A
```

The Zero 3W uses RKAIQ 5. Its existing RK3566 profiles and the two
IMX708 profiles are staged independently of the Rock 5 files.
