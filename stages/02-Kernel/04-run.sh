set -e

# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Copy the kernel modules"
pushd linux
MNT_DIR="${STAGE_WORK_DIR}/mnt"
make -j $J_CORES ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH="$MNT_DIR" modules_install

#exit linux
popd

#return 
popd
