#!/usr/bin/env bash
set -euo pipefail

platform="${1:?platform is required}"
file="${2:?image file is required}"
: "${FLEETCONTROL_DEV_IMAGE_TOKEN:?FLEETCONTROL_DEV_IMAGE_TOKEN is required}"
test -s "${file}"

filename="$(basename "${file}")"
sha256="$(sha256sum "${file}" | awk '{print $1}')"
curl --fail-with-body --location --retry 5 --retry-all-errors \
  --request PUT \
  --header "Authorization: Bearer ${FLEETCONTROL_DEV_IMAGE_TOKEN}" \
  --header "Content-Type: application/octet-stream" \
  --header "X-OpenHD-Filename: ${filename}" \
  --header "X-OpenHD-Sha256: ${sha256}" \
  --header "X-OpenHD-Commit: ${GITHUB_SHA}" \
  --upload-file "${file}" \
  "https://openhd.tech/api/internal/dev-images/${GITHUB_RUN_ID}/${platform}"
