#!/usr/bin/env bash
set -euo pipefail

# gdrive_download
#
# script to download Google Drive files from command line
# not guaranteed to work indefinitely
# taken from Stack Overflow answer:
# http://stackoverflow.com/a/38937732/7002068

gURL=$1
out_file="${2:-}"
rclone_path="${3:-}"
# match more than 26 word characters  
ggID=$(echo "$gURL" | egrep -o '(\w|-){26,}')

ggURL='https://drive.google.com/uc?export=download'
curl_common=(--fail --location --insecure -A "Mozilla/5.0")

cookie="$(mktemp)"
response="$(mktemp)"
trap 'rm -f "${cookie}" "${response}"' EXIT

curl "${curl_common[@]}" -c "${cookie}" -o "${response}" "${ggURL}&id=${ggID}"
getcode="$(awk '/_warning_/ {print $NF}' "${cookie}" | tail -n 1)"
confirm="$(sed -n 's/.*name="confirm"[[:space:]][^>]*value="\([^"]*\)".*/\1/p' "${response}" | tail -n 1 || true)"
uuid="$(sed -n 's/.*name="uuid"[[:space:]][^>]*value="\([^"]*\)".*/\1/p' "${response}" | tail -n 1 || true)"
form_action="$(sed -n 's/.*<form[^>]*id="download-form"[^>]*action="\([^"]*\)".*/\1/p' "${response}" | tail -n 1 || true)"

echo -e "Downloading from ${gURL}...\n"

if [[ -n "${out_file}" ]]; then
  output_args=(-o "${out_file}")
else
  output_args=(-OJ)
fi

download_with_rclone() {
  local rclone_config

  if [[ -z "${OPENHD_RCLONE_CONFIG_GDRIVE:-}" || -z "${rclone_path}" || -z "${out_file}" ]]; then
    return 1
  fi

  if ! command -v rclone >/dev/null 2>&1; then
    echo "OPENHD_RCLONE_CONFIG_GDRIVE is set but rclone is not installed; falling back to anonymous Google Drive download." >&2
    return 1
  fi

  rclone_config="$(mktemp)"
  printf '%s' "${OPENHD_RCLONE_CONFIG_GDRIVE}" \
    | awk '{ gsub(/\\n/, "\n"); print }' \
    | tr -d '\r' > "${rclone_config}"

  if ! grep -q '^\[gdrive\]$' "${rclone_config}"; then
    echo "OPENHD_RCLONE_CONFIG_GDRIVE does not contain a readable [gdrive] section." >&2
    echo "Found rclone config sections:" >&2
    grep -E '^\[[^]]+\]$' "${rclone_config}" >&2 || true
    rm -f "${rclone_config}"
    return 1
  fi

  echo "Downloading from Google Drive with authenticated rclone remote path: ${rclone_path}"
  if RCLONE_CONFIG="${rclone_config}" rclone copyto "gdrive:${rclone_path}" "${out_file}" --progress; then
    rm -f "${rclone_config}"
    return 0
  fi

  echo "Authenticated rclone download from My Drive failed, trying Shared with me." >&2
  if RCLONE_CONFIG="${rclone_config}" rclone copyto --drive-shared-with-me "gdrive:${rclone_path}" "${out_file}" --progress; then
    rm -f "${rclone_config}"
    return 0
  fi

  rm -f "${rclone_config}"
  return 1
}

if download_with_rclone; then
  exit 0
fi

if [[ -n "${confirm}" && -n "${uuid}" ]]; then
  action_url="${form_action:-https://drive.usercontent.google.com/download}"
  curl "${curl_common[@]}" "${output_args[@]}" -b "${cookie}" -e "${ggURL}&id=${ggID}" \
    "${action_url}?id=${ggID}&export=download&confirm=${confirm}&uuid=${uuid}"
elif [[ -n "${getcode}" ]]; then
  curl "${curl_common[@]}" "${output_args[@]}" -b "${cookie}" -e "${ggURL}&id=${ggID}" "${ggURL}&confirm=${getcode}&id=${ggID}"
else
  curl "${curl_common[@]}" "${output_args[@]}" -b "${cookie}" -e "${ggURL}&id=${ggID}" "${ggURL}&id=${ggID}"
fi

if [[ -n "${out_file}" ]] && grep -qiE '<!doctype html|<html' "${out_file}"; then
  echo "Google Drive returned HTML instead of the requested file. Check sharing/access for ${gURL}." >&2
  sed -n 's/.*<title>\(.*\)<\/title>.*/Google Drive response title: \1/p' "${out_file}" >&2 || true
  rm -f "${out_file}"
  exit 1
fi
