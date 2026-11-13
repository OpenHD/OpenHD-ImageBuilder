#!/usr/bin/env bash
set -euo pipefail

kernel=5.10.160-radxa-rk356x
headers="/usr/src/linux-headers-$kernel"
overlay=/boot/dtbo/radxa-zero3-imx708.dtbo
[[ -f "$headers/Module.symvers" && -d "/lib/modules/$kernel" ]]
[[ "$(dpkg-query -W -f='${Version}' camera-engine-rkaiq)" == 5.0x1.2-rc2 ]]

binary=/usr/local/libexec/openhd-zero3w
if [[ ! -x "$binary" ]]; then
    echo 'The installed arm64 OpenHD package lacks the Zero 3W native MPP executable.' >&2
    exit 1
fi
needed=$(readelf -d "$binary")
grep -Fq '[librockchip_mpp.so.1]' <<<"$needed"
if grep -Eq 'NEEDED.*libgst' <<<"$needed"; then
    echo 'The Zero 3W executable links GStreamer.' >&2
    exit 1
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
printf 'obj-m += imx708.o dw9817.o\n' > Makefile
make -C "$headers" ARCH=arm64 CROSS_COMPILE= M="$work" modules
install -d "/lib/modules/$kernel/updates/openhd"
install -m 0644 imx708.ko dw9817.ko "/lib/modules/$kernel/updates/openhd/"
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
[ "${version:-}" = 5.10.160-radxa-rk356x ] || exit 0
. /usr/share/initramfs-tools/hook-functions
force_load dw9817
force_load imx708
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
PY
ln -sfn "$iq_profiles/imx708-color-lift.json" /etc/iqfiles/imx708_uhq_default.json

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
# The built-in ISP otherwise clears its async wait list before initramfs
# can load the external sensor module.
if ! grep -q 'initcall_blacklist=rkisp_clr_unready_dev,rkcif_clr_unready_dev' /etc/kernel/cmdline; then
    sed -i '1s/$/ initcall_blacklist=rkisp_clr_unready_dev,rkcif_clr_unready_dev/' /etc/kernel/cmdline
fi
u-boot-update
for dtb in /usr/lib/linux-image-"$kernel"/rockchip/rk3566-radxa-zero-3w-*.dtb; do
    fdtoverlay -i "$dtb" -o merged.dtb imx708.dtbo
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
install -d /etc/systemd/system/rkaiq_3A.service.d
cat >/etc/systemd/system/rkaiq_3A.service.d/40-openhd-imx708.conf <<'EOF'
[Service]
ExecStartPre=/usr/local/libexec/openhd-zero3w-imx708-media
EOF
systemctl enable rkaiq_3A.service openhd-sys-utils.service
