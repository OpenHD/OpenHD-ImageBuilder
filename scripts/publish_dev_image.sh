#!/usr/bin/env bash
set -euo pipefail

platform="${1:?platform is required}"
file="${2:?image file is required}"
: "${FLEETCONTROL_DEV_IMAGE_TOKEN:?FLEETCONTROL_DEV_IMAGE_TOKEN is required}"
test -s "${file}"

filename="$(basename "${file}")"
sha256="$(sha256sum "${file}" | awk '{print $1}')"
chunk_dir="$(mktemp -d)"
trap 'rm -rf "${chunk_dir}"' EXIT
split --bytes="${FLEETCONTROL_CHUNK_SIZE:-128M}" --numeric-suffixes=0 --suffix-length=5 "${file}" "${chunk_dir}/chunk-"
mapfile -t chunks < <(find "${chunk_dir}" -maxdepth 1 -type f -name 'chunk-*' -print | sort)
test "${#chunks[@]}" -gt 0

upload_chunk() {
  local chunk="$1" index chunk_sha
  index="${chunk##*-}"
  chunk_sha="$(sha256sum "${chunk}" | awk '{print $1}')"
  curl --fail-with-body --location --retry 5 --retry-all-errors --retry-delay 2 \
    --request PUT \
    --header "Authorization: Bearer ${FLEETCONTROL_DEV_IMAGE_TOKEN}" \
    --header "Content-Type: application/octet-stream" \
    --header "X-OpenHD-Chunk-Sha256: ${chunk_sha}" \
    --upload-file "${chunk}" \
    "https://openhd.tech/api/internal/dev-images/${GITHUB_RUN_ID}/${platform}/chunks/${index}"
}
export -f upload_chunk
export FLEETCONTROL_DEV_IMAGE_TOKEN GITHUB_RUN_ID platform
printf '%s\0' "${chunks[@]}" | xargs -0 -n 1 -P "${FLEETCONTROL_UPLOAD_WORKERS:-4}" bash -c 'upload_chunk "$1"' _

curl --fail-with-body --location --retry 5 --retry-all-errors --retry-delay 2 \
  --request POST \
  --header "Authorization: Bearer ${FLEETCONTROL_DEV_IMAGE_TOKEN}" \
  --header "X-OpenHD-Filename: ${filename}" \
  --header "X-OpenHD-Sha256: ${sha256}" \
  --header "X-OpenHD-Commit: ${GITHUB_SHA}" \
  --header "X-OpenHD-Chunk-Count: ${#chunks[@]}" \
  "https://openhd.tech/api/internal/dev-images/${GITHUB_RUN_ID}/${platform}/complete"
