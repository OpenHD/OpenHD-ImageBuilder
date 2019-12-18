set -e

# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Remove previous Kernel"
rm -r linux || true

log "Download the Raspberry Pi Kernel"
git clone --depth=100 -b ${PI_KERNEL_BRANCH} ${PI_KERNEL_REPO}

pushd linux
# Switch to specific commit
git checkout $GIT_KERNEL_SHA1

# out
popd

log "Download the rtl8812au drivers"
rm -r rtl8812au || true
git clone -b ${RTL_8812AU_BRANCH} ${RTL_8812AU_REPO}

log "Download the v4l2loopback module"
rm -r v4l2loopback || true
git clone -b ${V4L2LOOPBACK_BRANCH} ${V4L2LOOPBACK_REPO}

#return 
popd
