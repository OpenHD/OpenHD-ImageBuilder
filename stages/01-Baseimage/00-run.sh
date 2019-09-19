# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Check any previous images"
# check for matching sha256 hash instead of downloading it again
if echo "`wget -qO- ${BASE_IMAGE_URL}/${BASE_IMAGE}.zip.sha256`" | sha256sum -c -
then
    rm *.img  # must be deleted every time because of no way to check
    log "Raspbian base Image already downloaded"
else
    rm *.zip
    rm *.img

    log "Download Raspbian base Image"
    wget $BASE_IMAGE_URL/$BASE_IMAGE".zip"
fi

log "Unzip"
unzip $BASE_IMAGE".zip"

log "Rename to IMAGE.img"
mv $BASE_IMAGE".img" "IMAGE.img"

# return
popd


