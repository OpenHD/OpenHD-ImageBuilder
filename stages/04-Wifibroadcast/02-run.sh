# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Copy the WFB overlay to the filesystem"

MNT_DIR="${STAGE_WORK_DIR}/mnt"

cp -r "${STAGE_DIR}/FILES/overlay/." "$MNT_DIR"

#return
popd
