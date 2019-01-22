# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Clear any previous images"
rm *.zip
rm *.img

log "Download Raspbian base Image"
wget $BASE_IMAGE_URL/$BASE_IMAGE".zip"

log "Unzip"
unzip $BASE_IMAGE".zip"

log "Rename to IMAGE.img"
mv $BASE_IMAGE".img" "IMAGE.img"

# return
popd


