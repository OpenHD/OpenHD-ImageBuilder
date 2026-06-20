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
trap 'rm -f "${cookie}"' EXIT

curl -L -sc "${cookie}" "${ggURL}&id=${ggID}" >/dev/null
getcode="$(awk '/_warning_/ {print $NF}' "${cookie}" | tail -n 1)"

echo -e "Downloading from ${gURL}...\n"

if [[ -n "${out_file}" ]]; then
  output_args=(-o "${out_file}")
else
  output_args=(-OJ)
fi

if [[ -n "${getcode}" ]]; then
  curl --fail --location --insecure "${output_args[@]}" -b "${cookie}" "${ggURL}&confirm=${getcode}&id=${ggID}"
else
  curl --fail --location --insecure "${output_args[@]}" -b "${cookie}" "${ggURL}&id=${ggID}"
fi
