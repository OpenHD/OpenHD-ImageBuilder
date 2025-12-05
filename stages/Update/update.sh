#!/usr/bin/env bash
set -euo pipefail

trap 'echo "ERROR: failed at line $LINENO"; exit 1' ERR

# Require root
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root (e.g. sudo $0)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
APT="apt -o Dpkg::Options::=--force-confnew -y"

fix_apt_sources() {
  echo "Sanitizing APT sources for CI…"

  local files=(/etc/apt/sources.list)
  if compgen -G "/etc/apt/sources.list.d/*.list" > /dev/null; then
    files+=(/etc/apt/sources.list.d/*.list)
  fi

  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue

    # Disable bullseye-backports (no Release file anymore)
    sed -i '/bullseye-backports/s/^/#/' "$f" || true

    # Disable Radxa repos (broken GPG in CI chroot)
    sed -i '/radxa-repo.github.io/s/^/#/' "$f" || true
  done

  echo "APT source cleanup done."
}

fix_apt_sources

# Remove old OpenHD repo if exists
  if [[ -f /etc/apt/sources.list.d/openhd-dev-release.list ]]; then
    echo "Removing old OpenHD APT sources…"
    rm /etc/apt/sources.list.d/openhd-dev-release.list
  fi
  if [[ -f /etc/apt/sources.list.d/openhd-release.list ]]; then
    echo "Removing old OpenHD APT sources…"
    rm /etc/apt/sources.list.d/openhd-release.list
  fi
  apt-get clean
  rm -rf /var/lib/apt/lists/*

# Add OpenHD repo (ignore failures from gnupg checks)
if command -v sudo >/dev/null 2>&1; then
  curl -1sLf \
    "https://dl.cloudsmith.io/public/openhd/dev-release/setup.deb.sh" \
    | sudo -E bash || true
else
  curl -1sLf \
    "https://dl.cloudsmith.io/public/openhd/dev-release/setup.deb.sh" \
    | bash || true
fi

# Best-effort update
apt update || echo "Warning: apt update failed but continuing…"

# Remove conflicting packages
$APT remove openhd 'qopenhd*' || true

# Determine OS (board)
if [[ -z "${OS:-}" ]]; then
  os_id="$(. /etc/os-release; echo "${ID}-${VERSION_CODENAME}")"
  export OS="${os_id}"
fi

# Install base packages
$APT install openhd libpoco-dev open-hd-web-ui 

# Install qopenhd or fallback
qopenhd_package="${QOPENHD_PACKAGE:-qopenhd}"

if [[ "${OS}" == "radxa-debian-cubie" ]]; then
  $APT install v4l-utils
else
  $APT install "${qopenhd_package}" || true
fi

# Enable service
systemctl enable openhd || true

# Install Web UI
WEBUI_DEB_URL="https://dl.cloudsmith.io/public/openhd/dev-release/deb/any-distro/pool/any-version/main/o/op/open-hd-web-ui_2.6.1-alpha.0.32/open-hd-web-ui_2.6.1-alpha.0.32_arm64.deb"

tmpdir="$(mktemp -d)"
deb_file="${tmpdir}/$(basename "${WEBUI_DEB_URL}")"

dpkg -i "${deb_file}" || { echo "Fixing deps…"; $APT -f install; }
rm -rf "${tmpdir}"

systemctl restart openhd || true

echo "Done. Detected board: ${OS}"
