#!/bin/bash
# Run inside the cross-builder with the committed backend snapshot in /work/backend-source.
set -euo pipefail
export PKG_CONFIG_SYSROOT_DIR=/target
export PKG_CONFIG_LIBDIR=/target/usr/lib/aarch64-linux-gnu/pkgconfig:/target/usr/share/pkgconfig
export PKG_CONFIG_PATH=
cmake -S /work/backend-source/OpenHD -B /work/backend-build -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE=/work/pi5-toolchain.cmake -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_AIR=OFF -DENABLE_USB_CAMERAS=OFF -DENABLE_LIBCAMERA=OFF \
    -DOPENHD_ENABLE_GUI=OFF -DOPENHD_PORTABLE_GROUND=OFF
cmake --build /work/backend-build --target openhd -j"${BUILD_JOBS:-4}"
aarch64-linux-gnu-readelf -d /work/backend-build/openhd | tee /work/backend-dynamic.txt
if grep -Ei 'NEEDED.*(rockchip|mpp|hantro|Qt5)' /work/backend-dynamic.txt; then
    echo 'Unexpected vendor video dependency in the Pi ground backend' >&2
    exit 1
fi
install -m755 /work/backend-build/openhd /target/usr/local/bin/openhd
printf 'ENABLE_AIR=OFF\nENABLE_USB_CAMERAS=OFF\nENABLE_LIBCAMERA=OFF\n' > /work/backend-build-options.txt
