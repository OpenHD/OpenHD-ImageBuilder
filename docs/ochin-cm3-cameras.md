# Radxa CM3 Air cameras on OCHIN V1 and V2

The two carriers use the same camera control wiring. This configuration is
for the RK3566 Radxa CM3. Build `ochin-v1` or `ochin-v2` using ImageBuilder's
full image mode, or select the corresponding target in its image workflow.
The recipes use the existing Radxa CM3 boot image. Use a component feed
with the matching OpenHD, SysUtils and QOpenHD builds.

| OCHIN connector | CM3 module CSI pins | RK3566 D-PHY | FFC pins 20/21 | Kernel capture path |
| --- | --- | --- | --- | --- |
| CAM0, J5 | Data 128/130 and 134/136, clock 140/142 | Physical D2/D3, CLK1, `csi2_dphy2` | SCL0/SDA0 on CM3 pins 80/82, `i2c0` | `mipi_csi2` → CIF MIPI LVDS → CIF SDITF → `rkisp_vir1` |
| CAM1, J6 | Data 115/117 and 121/123, clock 127/129 | Physical D0/D1, CLK0, `csi2_dphy1` | I2C10 on CM3 pins 35/37, `i2c2` M1 | `rkisp_vir0` |

Each endpoint uses local clock lane 0 and data lanes 1 and 2. The two D-PHY
instances select the physical lane pairs. Both FFCs share CAM_GPIO on pin 17,
from CM3 pin 97 (`GPIO4_C1`). One always-on node holds the shared enable
high. Pin 18 is unconnected. There is no carrier MCLK or independent reset.
CAM0 shares the module's I²C0 PMIC bus, so its overlay preserves the bus
timing and pinmux. Check the CAM0 control wiring on modified carriers.

| Module profile | I²C address | On-module reference clock |
| --- | --- | --- |
| IMX219 | 0x10 | 24 MHz |
| IMX708 | 0x1a, DW9817 at 0x0c | 24 MHz |
| IMX519 | 0x1a | 24 MHz |
| IMX462, IMX290-compatible module | 0x1a | 37.125 MHz |
| IMX462 Pivariety | 0x0c | 24 MHz |

The last four profiles use the Zero 3W driver and RKISP tuning bundle.
ImageBuilder builds the drivers for the installed OpenHD 5.10 RK356x or
Radxa 6.1 RK2410 kernel when present. It also installs the advanced profiles
for stock CM3 on Raspberry Pi CM4 IO using that carrier's CAM1 control bus.
The OCHIN profiles offer 720p30 and 1080p30 per stream. Use a camera module
matching the selected clock and I²C address.

Sources for connector wiring and media routing are the
[OCHIN V1 schematic](https://github.com/ochin-space/ochin-CM4/blob/master/schematics/Ochin_CM4_sch.pdf),
[OCHIN V2 schematic](https://github.com/ochin-space/ochin-CM4v2/blob/master/schematics/OchinCM4v2_0_1_sch.pdf),
[Radxa CM3 schematic](https://dl.radxa.com/cm3/docs/v1.32a/radxa_cm3_v1.32a_schematic.pdf),
and [Firefly's RK3566 split-mode configuration](https://community.t-firefly.com/en/docs/products/motherboard/ROC-RK3566-PC/hardware-usage/driver-camera).

## Activate or roll back

In ImageWriter, select the OCHIN image and Air mode. Pick a sensor named
for the FFC it is plugged into. Leave the second camera disabled for a
single stream, or select a sensor on the other port for dual capture.
QOpenHD can change the same profiles on a running Air unit. SysUtils applies
the selected overlays and OpenHD reboots after the boot configuration succeeds.

For a board already using the CM3 boot image, install the updated
components and overlay files from the OCHIN image recipe. The carrier marker
is `/boot/openhd/ochin-cm3.txt`, containing `v1` or `v2`. Before switching
carriers in software, disable any existing CM3 camera overlay targeting the
same ports. SysUtils manages `/boot/dtbo/ochin-cam0.dtbo` and
`/boot/dtbo/ochin-cam1.dtbo` as links to the selected `.dtbo.disabled` files.

To roll back, choose a non-CSI primary camera and disable the secondary
camera in QOpenHD. For a manual recovery, remove the two active OCHIN links
from the mounted boot filesystem, restore the previous extlinux configuration,
and clear the OCHIN camera choices from the provisioned settings before boot.
Retain the carrier marker if the image will still be used on OCHIN.

## Build and overlay validation

Compiled and applied all ten OCHIN overlays individually and all 25
two-camera combinations in both orders. The reciprocal endpoint and
lane checks passed on the active CM3 base DTB from the OpenHD
5.10.160-radxa-rk356x image and on Radxa's 6.1.84-17 CM3 DTB. The four
stock CM3 advanced overlays also passed the apply checks. The OpenHD
6.1.84-16-rk2410-nocsf kernel package omits this carrier DTB.

Cross-built the IMX708, DW9817, IMX519, IMX290 and Arducam Pivariety
modules against the 5.10.160 base image headers and the 6.1.84-16 and
6.1.84-17 headers. SysUtils profile selection and rollback checks and the
ImageWriter camera-profile tests passed. A complete image build, boot
and live camera validation are pending.

## Hardware checks

Run once with each port alone, then with both selected. Find the device
numbers by topology since they can change between boots.

```sh
sudo dmesg | grep -Ei 'imx219|imx708|imx519|imx290|pivariety|csi2|rkcif|rkisp|i2c'
for media in /dev/media*; do
    media-ctl -d "$media" -p
    media-ctl -d "$media" -e rkisp_mainpath 2>/dev/null || true
done
v4l2-ctl --list-devices
```

Verify the sensor chip identifies on its expected I²C controller. The
CAM0 sensor can appear on a separate CIF media device. The CAM0 mainpath
belongs to `rkisp-vir1`; CAM1 belongs to `rkisp-vir0`. Stop the Air capture
service during direct V4L2 checks. Keep the ISP tuning service running.
Set `CAM0` and `CAM1` to the corresponding mainpath device filenames.

```sh
sudo systemctl stop openhd
capture() {
    v4l2-ctl -d "$1" --set-fmt-video=width=1920,height=1080,pixelformat=NV12 \
        --stream-mmap=4 --stream-count=120 --stream-to=/dev/null
}
capture "$CAM0"                 # With only CAM0 enabled
capture "$CAM1"                 # With only CAM1 enabled
capture "$CAM0" & p0=$!         # With both enabled
capture "$CAM1" & p1=$!
wait "$p0"; status0=$?
wait "$p1"; status1=$?
test "$status0" -eq 0 && test "$status1" -eq 0
sudo systemctl start openhd
```

Confirm two independent Air streams in QOpenHD after the raw capture test.
Sensor probing, physical capture, simultaneous streaming and live tuning
require a board and connected modules.
