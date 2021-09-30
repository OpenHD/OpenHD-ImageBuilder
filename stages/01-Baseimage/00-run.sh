# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Check any previous images"
# check for matching sha256 hash instead of downloading it again


    log "Download Raspbian base Image"
    curl -O $BASE_IMAGE_URL/$BASE_IMAGE".zip"


log "Unzip"
unzip ${BASE_IMAGE}.zip

log "Rename to IMAGE.img"
mv ${BASE_IMAGE}.img IMAGE.img

# return
popd


