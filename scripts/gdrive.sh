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
