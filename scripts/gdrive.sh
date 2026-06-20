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

cookie="$(mktemp)"
response="$(mktemp)"
trap 'rm -f "${cookie}" "${response}"' EXIT

curl -L -sc "${cookie}" -o "${response}" "${ggURL}&id=${ggID}"
getcode="$(awk '/_warning_/ {print $NF}' "${cookie}" | tail -n 1)"
confirm="$(grep -o 'name="confirm" value="[^"]*"' "${response}" | sed 's/.*value="\([^"]*\)".*/\1/' | tail -n 1 || true)"
uuid="$(grep -o 'name="uuid" value="[^"]*"' "${response}" | sed 's/.*value="\([^"]*\)".*/\1/' | tail -n 1 || true)"

echo -e "Downloading from ${gURL}...\n"

if [[ -n "${out_file}" ]]; then
  output_args=(-o "${out_file}")
else
  output_args=(-OJ)
fi

if [[ -n "${confirm}" && -n "${uuid}" ]]; then
  curl --fail --location --insecure "${output_args[@]}" -b "${cookie}" \
    "https://drive.usercontent.google.com/download?id=${ggID}&export=download&confirm=${confirm}&uuid=${uuid}"
elif [[ -n "${getcode}" ]]; then
  curl --fail --location --insecure "${output_args[@]}" -b "${cookie}" "${ggURL}&confirm=${getcode}&id=${ggID}"
else
  curl --fail --location --insecure "${output_args[@]}" -b "${cookie}" "${ggURL}&id=${ggID}"
fi

if [[ -n "${out_file}" ]] && grep -qiE '<!doctype html|<html' "${out_file}"; then
  echo "Google Drive returned HTML instead of the requested file. Check sharing/access for ${gURL}." >&2
  rm -f "${out_file}"
  exit 1
fi
