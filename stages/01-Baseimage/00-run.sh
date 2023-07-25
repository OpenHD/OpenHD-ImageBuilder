#!/bin/bash

pushd "${STAGE_WORK_DIR}"

log "Checking for previous images"

SHA=$(sha256sum "${BASE_IMAGE}")
echo "SHA: ${SHA}"

if [[ "${SHA}" != "${BASE_IMAGE_SHA256}  ${BASE_IMAGE}" ]]; then    
    log "Checksum failed. Downloading base image."
    rm -f *.zip *.img *.xz *.7z
else
    log "Checksum succeeded. No need to download base image."
    popd
    exit 0
fi

log "Downloading base image"

if wget -q --show-progress --progress=bar:force:noscroll "${BASE_IMAGE_URL}/${BASE_IMAGE}"; then
    log "Base image download successful"
else
    log "Base image download using wget failed, trying with curl"
    if curl "${BASE_IMAGE_URL}/${BASE_IMAGE}" -o "${BASE_IMAGE}" -s; then
        log "Base image download successful"
    else
        log "Base image download using curl failed"
        exit 1
    fi
fi

log "Verifying checksum of downloaded image"

SHA=$(sha256sum "${BASE_IMAGE}")
echo "Calculated checksum: ${SHA}"

if [[ "${SHA}" != "${BASE_IMAGE_SHA256}  ${BASE_IMAGE}" ]]; then    
    log "Checksum failed. Aborting."
    exit 1
fi

log "Unarchiving base image"

if [[ "${BASE_IMAGE: -4}" == ".zip" ]]; then
    unzip "${BASE_IMAGE}"
elif [[ "${BASE_IMAGE: -3}" == ".xz" ]]; then
    xz -k -d "${BASE_IMAGE}"
elif [[ "${BASE_IMAGE: -4}" == ".bz2" ]]; then
    bunzip2 -k -d "${BASE_IMAGE}"
elif [[ "${BASE_IMAGE: -3}" == ".gz" ]]; then
    gunzip -k "${BASE_IMAGE}"
elif [[ "${BASE_IMAGE: -3}" == ".7z" ]]; then
    7z e "${BASE_IMAGE}"
else
    log "Unknown file type: ${BASE_IMAGE}"
    exit 1
fi

mv *.[iI][mM][gG] IMAGE.img

popd
