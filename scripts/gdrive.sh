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

validate_downloaded_file() {
  local file="$1"
  local magic

  if [[ ! -s "${file}" ]]; then
    echo "Downloaded file is missing or empty: ${file}" >&2
    return 1
  fi

  magic="$(head -c 8 "${file}" | od -An -tx1 | tr -d ' \n')"

  case "${file}" in
    *.7z)
      [[ "${magic}" == 377abcaf271c* ]] && return 0
      ;;
    *.img.xz|*.xz)
      [[ "${magic}" == fd377a585a00* ]] && return 0
      ;;
    *.zip)
      [[ "${magic}" == 504b0304* || "${magic}" == 504b0506* || "${magic}" == 504b0708* ]] && return 0
      ;;
    *.gz)
      [[ "${magic}" == 1f8b* ]] && return 0
      ;;
    *.bz2)
      [[ "${magic}" == 425a68* ]] && return 0
      ;;
    *)
      return 0
      ;;
  esac

  if grep -qiE '<!doctype html|<html|^[[:space:]]*\{' "${file}"; then
    echo "Google Drive returned HTML/JSON instead of the requested archive." >&2
    sed -n 's/.*<title>\(.*\)<\/title>.*/Google Drive response title: \1/p' "${file}" >&2 || true
  else
    echo "Downloaded file does not match expected archive magic for ${file}. Magic: ${magic}" >&2
  fi

  return 1
}

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

  if ! awk '
    /^\[gdrive\]$/ { in_section = 1; next }
    /^\[[^]]+\]$/ { in_section = 0 }
    in_section && $1 == "type" && $2 == "=" && $3 == "drive" { found = 1 }
    END { exit found ? 0 : 1 }
  ' "${rclone_config}"; then
    echo "OPENHD_RCLONE_CONFIG_GDRIVE [gdrive] section is missing required line: type = drive" >&2
    rm -f "${rclone_config}"
    return 1
  fi

  echo "Refreshing rclone Google Drive token metadata"
  rclone --config "${rclone_config}" about "gdrive:" >/dev/null || true

  echo "Downloading from Google Drive with authenticated rclone remote path: ${rclone_path}"
  echo "Using rclone config file: ${rclone_config}"
  echo "Found rclone config sections:"
  grep -E '^\[[^]]+\]$' "${rclone_config}" || true

  access_token="$(sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p' "${rclone_config}" | tail -n 1 || true)"
  if [[ -n "${access_token}" ]]; then
    echo "Downloading from Google Drive API by file ID: ${ggID}"
    if curl "${curl_common[@]}" \
      -H "Authorization: Bearer ${access_token}" \
      -o "${out_file}" \
      "https://www.googleapis.com/drive/v3/files/${ggID}?alt=media&acknowledgeAbuse=true&supportsAllDrives=true"; then
      if ! validate_downloaded_file "${out_file}"; then
        rm -f "${out_file}"
        return 1
      fi
      rm -f "${rclone_config}"
      return 0
    fi
    echo "Authenticated Google Drive API download failed, trying rclone fallbacks." >&2
  else
    echo "Unable to find access_token in rclone config, trying rclone fallbacks." >&2
  fi

  if rclone --config "${rclone_config}" backend copyid "gdrive:" "${ggID}" "${out_file}" --progress; then
    rm -f "${rclone_config}"
    return 0
  fi

  echo "Authenticated rclone download by file ID failed, trying Shared with me path lookup." >&2
  if rclone --config "${rclone_config}" copyto --drive-shared-with-me "gdrive:${rclone_path}" "${out_file}" --progress; then
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

if [[ -n "${out_file}" ]]; then
  if ! validate_downloaded_file "${out_file}"; then
    echo "Google Drive did not return the requested file. Check sharing/access for ${gURL}." >&2
    rm -f "${out_file}"
    exit 1
  fi
fi
