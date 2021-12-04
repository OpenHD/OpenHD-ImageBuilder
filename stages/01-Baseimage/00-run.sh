# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Check any previous images"

SHA=$(sha256sum ${BASE_IMAGE})
echo "SHA: ${SHA}"

if [[ "${SHA}" != "${BASE_IMAGE_SHA256}  ${BASE_IMAGE}" ]]; then    
    rm *.zip
    rm *.img    
    rm *.xz
    
    log "Download base Image"
    wget $BASE_IMAGE_URL/$BASE_IMAGE
fi



log "Unarchive base image"

if [[ ${BASE_IMAGE: -4} == ".zip" ]]; then
    unzip ${BASE_IMAGE}
elif [ ${BASE_IMAGE: -7} == ".img.xz" ]; then
    xz -k -d ${BASE_IMAGE}
elif [ ${BASE_IMAGE: -4} == ".bz2" ]; then
    bunzip2 -k -d ${BASE_IMAGE}
elif [ ${BASE_IMAGE: -3} == ".gz" ]; then
    gunzip -k ${BASE_IMAGE}
fi

mv *.[iI][mM][gG] IMAGE.img

# return
popd


