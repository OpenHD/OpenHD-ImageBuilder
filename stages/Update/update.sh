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

fix_apt_sources() {
  echo "Checking APT sources for known issues..."

  # Collect sources files
  local files=(
    /etc/apt/sources.list
  )
  if compgen -G "/etc/apt/sources.list.d/*.list" > /dev/null; then
    files+=(/etc/apt/sources.list.d/*.list)
  fi

  # Comment out dead bullseye-backports entries
  local had_backports=0
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    if grep -q "bullseye-backports" "$f"; then
      had_backports=1
      cp "$f" "$f.bak.$(date +%s)" || true
      sed -i '/bullseye-backports/s/^/#/' "$f" || true
    fi
  done

  if [[ $had_backports -eq 1 ]]; then
    echo "Disabled bullseye-backports entries (no longer has a Release file)."
  fi

  # Try to import Radxa repo keys if needed
  if grep -R "radxa-repo.github.io/bullseye" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | grep -q .; then
    if command -v apt-key >/dev/null 2>&1; then
      echo "Radxa bullseye repos detected; ensuring GPG keys are present..."
      apt-get install -y gnupg curl || true

      for key in 67A474DD40402951 5D93177D0752732A; do
        if ! apt-key list 2>/dev/null | grep -q "$key"; then
          echo "Importing Radxa key $key..."
          apt-key adv --keyserver keyserver.ubuntu.com --recv-keys "$key" || true
        fi
      done
    else
      echo "Warning: apt-key not available; Radxa repo signatures may still fail."
    fi
  fi
}

# Fix broken repos on old Radxa bullseye images (Rock 5A etc.)
fix_apt_sources

# Add OpenHD repo
if command -v sudo >/dev/null 2>&1; then
  curl -1sLf \
    "https://dl.cloudsmith.io/public/openhd/dev-release/setup.deb.sh" \
    | sudo -E bash
else
  curl -1sLf \
    "https://dl.cloudsmith.io/public/openhd/dev-release/setup.deb.sh" \
    | bash
fi

# Best-effort update
apt update || echo "Warning: apt update failed, continuing anyway"

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

dpkg -i "${deb_file}" || { echo "Fixing deps..."; $APT -f install; }
rm -rf "${tmpdir}"

# Start the OpenHD service
systemctl restart openhd || true

echo "Done. Detected board: ${OS}"
