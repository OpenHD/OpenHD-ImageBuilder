#!/bin/bash

pushd "${STAGE_WORK_DIR}"

check_base_image_checksum() {
    if [[ -n "${BASE_IMAGE_SHA512:-}" ]]; then
        SHA=$(sha512sum "${BASE_IMAGE}" 2>/dev/null || true)
        EXPECTED_SHA="${BASE_IMAGE_SHA512}  ${BASE_IMAGE}"
    elif [[ -n "${BASE_IMAGE_SHA256:-}" ]]; then
        SHA=$(sha256sum "${BASE_IMAGE}" 2>/dev/null || true)
        EXPECTED_SHA="${BASE_IMAGE_SHA256}  ${BASE_IMAGE}"
    elif [[ -f "${BASE_IMAGE}" ]]; then
        SHA="present"
        EXPECTED_SHA="present"
    else
        SHA="missing"
        EXPECTED_SHA="present"
    fi
}

download_base_image() {
    if [[ -n "${BASE_IMAGE_GDRIVE_URL:-}" ]]; then
        bash "${SCRIPT_DIR}/gdrive.sh" "${BASE_IMAGE_GDRIVE_URL}" "${BASE_IMAGE}" "${BASE_IMAGE_GDRIVE_RCLONE_PATH:-}"
        if [[ ! -f "${BASE_IMAGE}" ]]; then
            log "Google Drive download did not create ${BASE_IMAGE}"
            exit 1
        fi
        return
    fi

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
}

log "Checking for previous images"

check_base_image_checksum
echo "SHA: ${SHA}"

if [[ "${SHA}" != "${EXPECTED_SHA}" ]]; then
    log "Checksum failed. Downloading base image."
    rm -f *.zip *.img *.xz *.7z
else
    log "Checksum succeeded. No need to download base image."
    popd
    exit 0
fi

log "Downloading base image"

download_base_image

log "Verifying checksum of downloaded image"

check_base_image_checksum
echo "Calculated checksum: ${SHA}"

if [[ "${SHA}" != "${EXPECTED_SHA}" ]]; then
    log "Checksum failed. Aborting."
    exit 1
fi

log "Unarchiving base image"

if [[ "${BASE_IMAGE: -4}" == ".zip" ]]; then
    unzip "${BASE_IMAGE}"
elif [[ "${BASE_IMAGE: -7}" == ".img.xz" ]]; then
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
