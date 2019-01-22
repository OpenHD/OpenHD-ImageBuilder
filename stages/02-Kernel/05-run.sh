set -e

# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Copy the Kernel.img"

MNT_DIR="${STAGE_WORK_DIR}/mnt"
sudo cp "${STAGE_WORK_DIR}/kernel1.img" "${MNT_DIR}/boot/kernel.img"

#return 
popd
