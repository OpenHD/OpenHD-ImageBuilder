set -e

# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Remove previous Kernel"
rm -r linux || true

log "Download the Raspberry Pi Kernel"
git clone --depth=100 -b rpi-4.14.y https://github.com/raspberrypi/linux

pushd linux
# Switch to specific commit
git checkout $GIT_KERNEL_SHA1

# out
popd

log "Download the rtl8812au drivers"
rm -r rtl8812au || true
# Fixed at v5.2.20 until 5.3.4 works for injection
git clone -b v5.2.20 https://github.com/aircrack-ng/rtl8812au.git

log "Download the v4l2loopback module"
rm -r v4l2loopback || true
git clone https://github.com/RespawnDespair/v4l2loopback.git

#return 
popd
