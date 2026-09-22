#!/bin/sh
set -eu
DEST_BIN="${DEST_BIN:-/usr/bin}"
DEST_LIB="${DEST_LIB:-/usr/lib}"
DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "${DEST_BIN}" "${DEST_LIB}"
install -m 0755 "${DIR}/usr/bin/openhd" "${DEST_BIN}/openhd"

if [ -d "${DIR}/usr/lib" ]; then
  cp -af "${DIR}/usr/lib/"* "${DEST_LIB}/"
  ldconfig 2>/dev/null || true
fi

echo "OpenHD installed to ${DEST_BIN}/openhd"
