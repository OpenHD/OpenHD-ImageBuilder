# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Copy all Support Sources to RPi image"

MNT_DIR="${STAGE_WORK_DIR}/mnt"

cp -r GIT/. "$MNT_DIR/home/pi/"

#return
popd
