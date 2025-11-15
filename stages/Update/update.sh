#!/usr/bin/env bash
set -euo pipefail

# Fail with a readable message if anything breaks
trap 'echo "ERROR: failed at line $LINENO"; exit 1' ERR

# Require root
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root (e.g. sudo $0)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
APT="apt -o Dpkg::Options::=--force-confnew -y"

# Add OpenHD repo
curl -1sLf \
  'https://dl.cloudsmith.io/public/openhd/dev-release/setup.deb.sh' \
  | sudo -E bash

# Best-effort update
apt update || true

# Remove conflicting packages
$APT remove openhd 'qopenhd*' || true

# Determine OS (board)
if [[ -z "${OS:-}" ]]; then
  os_id="$(. /etc/os-release; echo "${ID}-${VERSION_CODENAME}")"
  model="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)"
  export OS="${os_id}"
fi

# Install common base packages
$APT install openhd libpoco-dev

if [[ "${OS}" == "radxa-debian-cubie" ]]; then
  $APT install v4l-utils
else
  $APT install "qopenhd-${OS}"
fi

# Enable OpenHD service
systemctl enable openhd || true

# Install Web UI
WEBUI_DEB_URL="https://dl.cloudsmith.io/public/openhd/dev-release/deb/any-distro/pool/any-version/main/o/op/open-hd-web-ui_2.6.1-alpha.0.32/open-hd-web-ui_2.6.1-alpha.0.32_arm64.deb"

tmpdir="$(mktemp -d)"
deb_file="${tmpdir}/$(basename "${WEBUI_DEB_URL}")"

if command -v curl >/dev/null 2>&1; then
  curl -fL --retry 3 --retry-delay 2 -o "${deb_file}" "${WEBUI_DEB_URL}"
else
  wget -O "${deb_file}" "${WEBUI_DEB_URL}"
fi

dpkg -i "${deb_file}" || { echo "Fixing deps…"; $APT -f install; }
rm -rf "${tmpdir}"

# Start the OpenHD service
systemctl restart openhd || true

echo "✅ Done. Detected board: ${OS}"
