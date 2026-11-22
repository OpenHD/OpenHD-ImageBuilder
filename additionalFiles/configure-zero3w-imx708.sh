#!/usr/bin/env bash
set -euo pipefail

kernel=${2:-5.10.160-radxa-rk356x}
headers="/usr/src/linux-headers-$kernel"
overlay=/boot/dtbo/radxa-zero3-imx708.dtbo
[[ -f "$headers/Module.symvers" && -d "/lib/modules/$kernel" ]]

if [[ "${1:-}" != --sensors-only ]]; then
    [[ "$(dpkg-query -W -f='${Version}' camera-engine-rkaiq)" == 5.0x1.2-rc2 ]]
    binary=/usr/local/libexec/openhd-zero3w
    if [[ ! -x "$binary" ]]; then
        echo 'The installed arm64 OpenHD package lacks the Zero 3W native MPP executable.' >&2
        exit 1
    fi
    needed=$(readelf -d "$binary")
    if ! grep -Fq '[librockchip_mpp.so.1]' <<<"$needed"; then
        echo 'The Zero 3W executable lacks native MPP video support.' >&2
        exit 1
    fi
    # Match OpenHD packaging: USB microphone capture uses GStreamer appsink.
    if ! grep -Fq '[libgstapp-1.0.so.0]' <<<"$needed"; then
        echo 'The Zero 3W executable lacks GStreamer audio capture support.' >&2
        exit 1
    fi
    if grep -Eq 'NEEDED.*libgst(video|sdp)-' <<<"$needed"; then
        echo 'The Zero 3W executable must use native MPP video.' >&2
        exit 1
    fi
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

download() {
    curl -fsSL --retry 4 "$1" -o "$2"
    printf '%s  %s\n' "$3" "$2" | sha256sum -c -
}

driver_ref=ecbcd280793665594bffc5f9d07a0d673c3e41ad
download "https://raw.githubusercontent.com/armbian/linux-rockchip/$driver_ref/drivers/media/i2c/imx708.c" imx708.c \
    bfc17a23f88f2157ec9078d39f47492b71320c0939ba1dab1ee04d700bf714d5
patch -p0 < /opt/additionalFiles/zero3w-imx708-5.10.patch
focus_ref=35ed3470decc60fc4f326ccb643ede93f7563e9d
download "https://raw.githubusercontent.com/raspberrypi/linux/$focus_ref/drivers/media/i2c/dw9807-vcm.c" dw9817.c \
    497bd8bc84834a38570e9e922444ce7a968ecacb82e4a07a41a1bab5467d0743
patch -p0 < /opt/additionalFiles/zero3w-dw9817-5.10.patch
imx519_ref=54afa27e1439cb2f64fff59508d07eef52382189
download "https://raw.githubusercontent.com/ArduCAM/IMX519_AK7375/$imx519_ref/IMX519/imx519.c" imx519.c \
    65b6b2353150c01012eccea8a82969871c80ce9c980ea7b78e07bb91e5502f9f
patch -p0 < /opt/additionalFiles/zero3w-imx519-5.10.patch
imx290_ref=00aee4108ab9ee72f21d0b1ab83fb0afd5cac134
download "https://raw.githubusercontent.com/OpenHD/luckfox-pico-sdk/$imx290_ref/sysdrv/source/kernel/drivers/media/i2c/imx290.c" imx290.c \
    6bdf19267c9f5fa8a5cd5892fd70bc0480c6346c2ae37db42eac5f98908e6b1a
patch -p0 < /opt/additionalFiles/zero3w-imx290-5.10.patch
pivariety_ref=fbd8b3facb36ce888b1cdcf5f45a78475a8208f2
pivariety_source="https://raw.githubusercontent.com/raspberrypi/linux/$pivariety_ref/drivers/media/i2c"
download "$pivariety_source/arducam-pivariety.c" arducam-pivariety.c \
    a6019afc7975a30516422100d30cc285fcc65d2ff11b6f9999bf515304927a80
download "$pivariety_source/arducam-pivariety.h" arducam-pivariety.h \
    bd3fd7be273c17b29e3552c2f40ae36990c43ed386c9d8a0d53b6db71b5b7a2d
patch -p0 < /opt/additionalFiles/zero3w-pivariety-5.10.patch
if [[ "$kernel" == 6.1.* ]]; then
    patch -p0 < /opt/additionalFiles/rk356x-camera-6.1.patch
fi
printf 'obj-m += imx708.o dw9817.o imx519.o imx290.o arducam-pivariety.o\n' > Makefile
make -C "$headers" ARCH=arm64 CROSS_COMPILE= M="$work" modules
install -d "/lib/modules/$kernel/updates/openhd"
install -m 0644 imx708.ko dw9817.ko imx519.ko imx290.ko arducam-pivariety.ko "/lib/modules/$kernel/updates/openhd/"
depmod -a "$kernel"
# The Devourer stage can regenerate initramfs for both installed kernels.
# Include these drivers only in the initramfs built for the matching ABI.
install -d /etc/initramfs-tools/hooks
cat >/etc/initramfs-tools/hooks/openhd-zero3w-camera <<'EOF'
#!/bin/sh
set -e
if [ "${1:-}" = prereqs ]; then
    exit 0
fi
[ -f "/lib/modules/${version:-}/updates/openhd/imx708.ko" ] || exit 0
. /usr/share/initramfs-tools/hook-functions
force_load dw9817
force_load imx708
force_load imx519
force_load imx290
force_load arducam_pivariety
EOF
chmod 0755 /etc/initramfs-tools/hooks/openhd-zero3w-camera
update-initramfs -u -k "$kernel"

iq_ref=1fc5d49c5fcf926320d48437de72d7edaaef5d2f
download "https://raw.githubusercontent.com/avafinger/rockchip-iqfiles/$iq_ref/Rock3/imx708_uhq_default_4096x2592.json_MANUALFOCUS" imx708.json \
    c312c0b5ed4ea404894d1126e7dbe79fc315248ee36951fd048db31991102240
iq_profiles=/usr/share/openhd/iq-profiles/imx708
install -D -m 0644 imx708.json "$iq_profiles/manual-focus.json"
download "https://raw.githubusercontent.com/avafinger/rockchip-iqfiles/$iq_ref/Rock3/imx708_uhq_default_4096x2592.json_AUTOFOCUS" imx708-af.json \
    bb0065ab77c04cc7cb070598abe489ac79943e3cd539c6fe7e3b2056ef33bb5f
install -m 0644 imx708-af.json "$iq_profiles/autofocus.json"
install -d /etc/iqfiles
# The Rockchip IMX708 driver expects linear gain with 1024 as unity.
# Retain the original profiles and use the corrected gain map at runtime.
python3 - "$iq_profiles" <<'PY'
import copy
import json
import sys
from pathlib import Path

folder = Path(sys.argv[1])
for mode, source in (
    ("manual-focus", folder / "manual-focus.json"),
    ("autofocus", folder / "autofocus.json"),
):
    tuning = json.loads(source.read_text())
    gain = tuning["sensor_calib"]["Gain2Reg"]
    gain_range = [1, 16, 1024, 0, 1, 1024, 16384]
    gain.update(
        GainMode="EXPGAIN_MODE_LINEAR",
        GainRange=gain_range,
        GainRange_len=len(gain_range),
    )
    (folder / f"{mode}-openhd.json").write_text(json.dumps(tuning, indent=2) + "\n")
# Retain IMX708 exposure and focus tuning with the RK3566 reference ISP21 processing.
fallback = json.loads((folder / "manual-focus-openhd.json").read_text())
reference = json.loads(Path("/etc/iqfiles/imx219_RADXA-CAMERA-8M_default.json").read_text())
processing = reference["main_scene"][0]["sub_scene"][0]["scene_isp21"]
for scene in fallback["main_scene"]:
    for sub_scene in scene["sub_scene"]:
        original = sub_scene["scene_isp21"]
        sub_scene["scene_isp21"] = copy.deepcopy(processing)
        for key in ("ae_calib", "af", "wb_v21", "ccm_calib"):
            sub_scene["scene_isp21"][key] = original[key]
        # The IMX708 startup hook selects the 1080p sensor readout.
        # Keep automatic exposure within that readout's 60 fps frame budget.
        fps_mode = sub_scene["scene_isp21"]["ae_calib"]["CommCtrl"]["AecFrameRateMode"]
        fps_mode.update(isFpsFix=1, FpsValue=60)
        # Lift shadows for the low-light Air preview while preserving white.
        gamma = sub_scene["scene_isp21"]["agamma_calib_v10"]["GammaTuningPara"]
        gamma["Gamma_curve"] = [
            round(4095 * (max(0, min(4095, value)) / 4095) ** 0.55)
            for value in gamma["Gamma_curve"]
        ]
(folder / "imx708-color-lift.json").write_text(json.dumps(fallback, indent=2) + "\n")
for scene in fallback["main_scene"]:
    for sub_scene in scene["sub_scene"]:
        fps_mode = sub_scene["scene_isp21"]["ae_calib"]["CommCtrl"]["AecFrameRateMode"]
        fps_mode.update(isFpsFix=1, FpsValue=30)
(folder / "imx708-color-lift-30.json").write_text(json.dumps(fallback, indent=2) + "\n")
for scene in fallback["main_scene"]:
    for sub_scene in scene["sub_scene"]:
        isp = sub_scene["scene_isp21"]
        fps_mode = isp["ae_calib"]["CommCtrl"]["AecFrameRateMode"]
        fps_mode.update(FpsValue=120)
        # The reference lens shading table makes the cropped readout black on ISP21.
        isp["lsc_v2"]["common"]["enable"] = 0
(folder / "imx708-color-lift-120.json").write_text(json.dumps(fallback, indent=2) + "\n")
PY
ln -sfn "$iq_profiles/imx708-color-lift.json" /etc/iqfiles/imx708_uhq_default.json

python3 /opt/additionalFiles/zero3w-imx519-iq.py "$iq_profiles/imx708-color-lift.json"
download "https://raw.githubusercontent.com/avafinger/rockchip-iqfiles/$iq_ref/Rock5/imx290_imx290_default.json" imx290-iq.json \
    da5fd58fcf041542287bce6faa402ae54bc1e0f55b0236178af13f0c85a4d1a6
python3 /opt/additionalFiles/zero3w-imx290-iq.py imx290-iq.json
pivariety_iq_ref=e4b941ec100589076a06c8cbaa0bdc3ae6fb98ae
download "https://raw.githubusercontent.com/OpenHD/rockchip-iq-files/$pivariety_iq_ref/rockchip-iqfiles-rk356x/pivariety_IMX462_default.json" pivariety-iq.json \
    4747957d35043b3b57a69179549c13436fefc3fbb935f0a82bbbdbd25e1f3351
python3 /opt/additionalFiles/zero3w-pivariety-iq.py pivariety-iq.json /etc/iqfiles/pivariety_IMX462_default.json

# The built-in ISP otherwise clears its async wait list before initramfs
# can load the external sensor module.
if ! grep -q 'initcall_blacklist=rkisp_clr_unready_dev,rkcif_clr_unready_dev' /etc/kernel/cmdline; then
    sed -i '1s/$/ initcall_blacklist=rkisp_clr_unready_dev,rkcif_clr_unready_dev/' /etc/kernel/cmdline
fi
if [[ "${1:-}" == --sensors-only ]]; then
    u-boot-update
    exit 0
fi

# Reuse the board's CSI routing. The CAM_PWDN regulator already owns the
# enable GPIO. Use the module name expected by the matching IQ file.
if [[ ! -f "$overlay.disabled.openhd-original" ]]; then
    cp "$overlay.disabled" "$overlay.disabled.openhd-original"
fi
install -m 0644 "$overlay.disabled.openhd-original" imx708.dtbo
fdtput -d imx708.dtbo /fragment@1/__overlay__/imx708@1a reset-gpios
fdtput -t s imx708.dtbo /__fixups__ gpio3 '/fragment@0/__overlay__/camera-pwdn-gpio:gpio:0'
fdtput -t s imx708.dtbo /fragment@1/__overlay__/imx708@1a rockchip,camera-module-name uhq
# Camera Module 3 uses the DW9817 actuator at I2C address 0x0c.
bus=/fragment@1/__overlay__
lens="$bus/dw9817@c"
fdtput -c imx708.dtbo "$lens"
fdtput -t s imx708.dtbo "$lens" compatible dongwoon,dw9817-vcm
fdtput -t x imx708.dtbo "$lens" reg c
# Reserve a local phandle and let libfdt relocate it with the other references.
fdtput -t x imx708.dtbo "$lens" phandle 100
fdtput -t x imx708.dtbo "$bus/imx708@1a" lens-focus 100
fdtput -p -c imx708.dtbo "/__local_fixups__$bus/imx708@1a"
fdtput -t x imx708.dtbo "/__local_fixups__$bus/imx708@1a" lens-focus 0
install -m 0644 imx708.dtbo "$overlay.disabled"

# Derive the IMX519 overlay from the same board routing without the IMX708 lens node.
install -m 0644 imx708.dtbo imx519.dtbo
fdtput -r imx519.dtbo "$lens"
fdtput -d imx519.dtbo "$bus/imx708@1a" lens-focus
fdtput -d imx519.dtbo "/__local_fixups__$bus/imx708@1a" lens-focus
fdtput -d imx519.dtbo /__fixups__ gpio1
fdtput -t s imx519.dtbo /metadata title 'Enable Arducam IMX519 on Zero 3W'
fdtput -t s imx519.dtbo /metadata description 'Enable Arducam IMX519 on CAM0.'
fdtput -t s imx519.dtbo "$bus/imx708@1a" compatible sony,imx519
fdtput -t s imx519.dtbo "$bus/imx708@1a" rockchip,camera-module-name arducam
fdtput -t x imx519.dtbo "$bus/imx708@1a/port/endpoint" link-frequencies 0 1d6a3660
# Rename the sensor node and its symbol paths together with the local fixup path.
dtc -I dtb -O dts imx519.dtbo > imx519.dts
sed -i 's/imx708/imx519/g' imx519.dts
dtc -I dts -O dtb -o imx519.dtbo imx519.dts
install -m 0644 imx519.dtbo /boot/dtbo/radxa-zero3-arducam-pivariety-imx519.dtbo.disabled


# Use the direct sensor on CAM0 under the existing Zero 3W IMX462 selection.
dtc -I dtb -O dts imx519.dtbo > imx290.dts
sed -i 's/imx519/imx290/g' imx290.dts
dtc -I dts -O dtb -o imx290.dtbo imx290.dts
sensor="$bus/imx290@1a"
fdtput -t s imx290.dtbo /metadata title 'Enable IMX290-compatible sensor on Zero 3W'
fdtput -t s imx290.dtbo /metadata description 'Enable the direct IMX290-compatible sensor on CAM0.'
fdtput -t x imx290.dtbo /fragment@0/__overlay__/external-camera-clock-24m clock-frequency 2367b88
fdtput -t x imx290.dtbo "$sensor" clock-frequency 2367b88
fdtput -t s imx290.dtbo "$sensor" rockchip,camera-module-name imx290
fdtput -t x imx290.dtbo "$sensor/port/endpoint" link-frequencies 0 1a8dca60
install -m 0644 imx290.dtbo /boot/dtbo/radxa-zero3-arducam-pivariety-imx462.dtbo.disabled


dtc -I dtb -O dts imx519.dtbo > pivariety.dts
sed -i 's/imx519@1a/arducam-pivariety@c/g' pivariety.dts
dtc -I dts -O dtb -o pivariety.dtbo pivariety.dts
sensor="$bus/arducam-pivariety@c"
fdtput -t s pivariety.dtbo /metadata title 'Enable IMX462 Pivariety on Zero 3W'
fdtput -t s pivariety.dtbo /metadata description 'Enable Arducam IMX462 Pivariety on CAM0.'
fdtput -t s pivariety.dtbo "$sensor" compatible arducam,arducam-pivariety
fdtput -t x pivariety.dtbo "$sensor" reg c
fdtput -t x pivariety.dtbo "$sensor" clock-frequency 16e3600
fdtput -t x pivariety.dtbo "$bus" clock-frequency 2710
fdtput -t s pivariety.dtbo "$sensor" rockchip,camera-module-name IMX462
fdtput -t x pivariety.dtbo "$sensor/port/endpoint" link-frequencies 0 1a8dca60
install -m 0644 pivariety.dtbo /boot/dtbo/radxa-zero3-imx462-pivariety.dtbo.disabled

u-boot-update
for dtb in /usr/lib/linux-image-"$kernel"/rockchip/rk3566-radxa-zero3.dtb \
    /usr/lib/linux-image-"$kernel"/rockchip/rk3566-radxa-zero-3w-*.dtb; do
    [[ -f "$dtb" ]] || continue
    fdtoverlay -i "$dtb" -o merged.dtb imx708.dtbo
    fdtoverlay -i "$dtb" -o merged.dtb imx519.dtbo
    fdtoverlay -i "$dtb" -o merged.dtb imx290.dtbo
    fdtoverlay -i "$dtb" -o merged.dtb pivariety.dtbo
done

mpp_ref=20959ec3dabb313b8c33ca0b7b09c06ffd2a9caa
download "https://codeload.github.com/HermanChen/mpp/tar.gz/$mpp_ref" mpp.tar.gz \
    345148b74b8a5e5dd329d58163113756581102685fe9d3d657621960d04172f4
tar -xf mpp.tar.gz
cmake -S "mpp-$mpp_ref" -B mpp-build \
    -DCMAKE_C_FLAGS=-mno-outline-atomics -DCMAKE_CXX_FLAGS=-mno-outline-atomics \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_TEST=OFF -DBUILD_SHARED_LIBS=ON
cmake --build mpp-build --parallel "${OPENHD_BUILD_JOBS:-4}"
DESTDIR="$work/mpp-install" cmake --install mpp-build

# Use the MPP revision pinned by the X21B production manifest.
install -d /usr/local/lib/openhd-mpp /usr/local/share/doc/openhd-mpp
cp -a mpp-install/usr/local/lib/librockchip_{mpp,vpu}.so.* /usr/local/lib/openhd-mpp/
install -m 0644 "mpp-$mpp_ref/LICENSES/"{Apache-2.0,MIT} /usr/local/share/doc/openhd-mpp/
printf '%s\n' "$mpp_ref" >/usr/local/share/doc/openhd-mpp/source-revision
printf '%s\n' /usr/local/lib/openhd-mpp >/etc/ld.so.conf.d/00-openhd-mpp.conf
ldconfig
dependencies=$(LD_LIBRARY_PATH=/usr/local/lib/openhd-mpp ldd -r "$binary" 2>&1)
printf '%s\n' "$dependencies"
grep -Fq "librockchip_mpp.so.1 => /usr/local/lib/openhd-mpp/" <<<"$dependencies"
if grep -Eq 'not found|undefined symbol' <<<"$dependencies"; then
    exit 1
fi

# OpenHD carries a distro-library RUNPATH. Select the image's MPP runtime.
install -d /etc/systemd/system/openhd.service.d
cat >/etc/systemd/system/openhd.service.d/40-zero3w-air.conf <<'EOF'
[Unit]
After=rkaiq_3A.service

[Service]
ExecStart=
ExecStart=/usr/local/libexec/openhd-zero3w
Environment=LD_LIBRARY_PATH=/usr/local/lib/openhd-mpp
EOF

install -D -m 0755 /opt/additionalFiles/zero3w-imx708-media.sh /usr/local/libexec/openhd-zero3w-imx708-media
install -D -m 0755 /opt/additionalFiles/zero3w-imx519-media.sh /usr/local/libexec/openhd-zero3w-imx519-media
install -D -m 0755 /opt/additionalFiles/zero3w-imx290-media.sh /usr/local/libexec/openhd-zero3w-imx290-media
install -d /etc/systemd/system/rkaiq_3A.service.d
cat >/etc/systemd/system/rkaiq_3A.service.d/40-openhd-imx708.conf <<'EOF'
[Service]
ExecStartPre=/usr/local/libexec/openhd-zero3w-imx708-media
ExecStartPre=/usr/local/libexec/openhd-zero3w-imx519-media
ExecStartPre=/usr/local/libexec/openhd-zero3w-imx290-media
EOF
systemctl enable rkaiq_3A.service openhd-sys-utils.service
