#!/bin/bash

set -euo pipefail

WORK_DIR="${STAGE_WORK_DIR}"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')]: $@"
}

log "Checking for any previous images"

if [[ -f "${WORK_DIR}/IMAGE.img" ]]; then
  log "Previous image found, removing it"
  rm "${WORK_DIR}/IMAGE.img"
fi

log "Verifying base image checksum"

BASE_IMAGE_PATH="${WORK_DIR}/${BASE_IMAGE}"
EXPECTED_CHECKSUM="$(echo ${BASE_IMAGE_SHA256} | cut -d ' ' -f 1)"
ACTUAL_CHECKSUM="$(sha256sum ${BASE_IMAGE_PATH} | cut -d ' ' -f 1)"

if [[ "${EXPECTED_CHECKSUM}" != "${ACTUAL_CHECKSUM}" ]]; then
  log "Invalid checksum, removing base image"
  rm "${BASE_IMAGE_PATH}"
fi

if [[ ! -f "${BASE_IMAGE_PATH}" ]]; then
  log "Downloading base image from ${BASE_IMAGE_URL}"
  if wget -q --show-progress --progress=bar:force:noscroll "${BASE_IMAGE_URL}/${BASE_IMAGE}" || \
     curl -L -s "${BASE_IMAGE_URL}/${BASE_IMAGE}" -o "${BASE_IMAGE_PATH}"; then
    log "Base image download successful"
  else
    log "Base image download failed"
    exit 1
  fi
fi

log "Extracting base image"

if [[ "${BASE_IMAGE}" == *.zip ]]; then
  unzip -q "${BASE_IMAGE_PATH}" -d "${WORK_DIR}"
elif [[ "${BASE_IMAGE}" == *.img.xz ]]; then
  xz -d -k "${BASE_IMAGE_PATH}"
elif [[ "${BASE_IMAGE}" == *.bz2 ]]; then
  bunzip2 -d -k "${BASE_IMAGE_PATH}"
elif [[ "${BASE_IMAGE}" == *.gz ]]; then
  gunzip -k "${BASE_IMAGE_PATH}"
elif [[ "${BASE_IMAGE}" == *.7z ]]; then
  7z e "${BASE_IMAGE_PATH}" -o"${WORK_DIR}"
fi

mv "${WORK_DIR}"/*.img IMAGE.img

log "Image extraction complete"
