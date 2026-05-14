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
$APT remove openhd openhd-sys-utils 'qopenhd*' || true

# Determine OS (board)
if [[ -z "${OS:-}" ]]; then
  os_id="$(. /etc/os-release; echo "${ID}-${VERSION_CODENAME}")"
  export OS="${os_id}"
fi

# Install base packages
$APT install openhd libpoco-dev open-hd-web-ui openhd-sys-utils

# Install qopenhd or fallback
qopenhd_package="${QOPENHD_PACKAGE:-qopenhd}"

ensure_openhd_user() {
  if ! id openhd >/dev/null 2>&1; then
    adduser --shell /bin/bash --disabled-password --gecos "" openhd
  fi

  echo "openhd:openhd" | chpasswd
  usermod -s /bin/bash openhd || true
  if getent group sudo >/dev/null 2>&1; then
    usermod -aG sudo openhd || true
  fi
}

install_cubie_ssh_boot_fix() {
  cat >/usr/local/sbin/openhd-cubie-ssh-boot.sh <<'EOF'
#!/bin/sh
set -eu

if ! id openhd >/dev/null 2>&1; then
  adduser --shell /bin/bash --disabled-password --gecos "" openhd
fi

echo "openhd:openhd" | chpasswd
usermod -s /bin/bash openhd || true
if getent group sudo >/dev/null 2>&1; then
  usermod -aG sudo openhd || true
fi

mkdir -p /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/99-openhd-enable-password-login.conf <<'SSHEOF'
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
SSHEOF

systemctl unmask ssh.service ssh.socket sshd.service sshd.socket >/dev/null 2>&1 || true
systemctl enable ssh.service >/dev/null 2>&1 || true
systemctl restart ssh.service >/dev/null 2>&1 || systemctl start ssh.service >/dev/null 2>&1 || true
EOF

  chmod 0755 /usr/local/sbin/openhd-cubie-ssh-boot.sh

  cat >/etc/systemd/system/openhd-cubie-ssh-boot.service <<'EOF'
[Unit]
Description=Keep SSH enabled for OpenHD on Radxa Cubie
After=local-fs.target network.target rsetup-config-first-boot.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/openhd-cubie-ssh-boot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable openhd-cubie-ssh-boot.service || true
  /usr/local/sbin/openhd-cubie-ssh-boot.sh || true

  if [[ -d /conf ]]; then
    mkdir -p /conf/openhd
    touch /conf/openhd/resize.txt
    touch /conf/config.txt
    cat >/conf/before.txt <<'EOF'
remove_packages rsetup-config-first-boot
EOF
  fi
}

if [[ "${OS}" == "raspbian" ]]; then
  $APT remove openhd-linux-pi
  echo "Installing custom Kernel package"
  $APT install openhd-linux-pi
  $APT install openhd-linux-pi-headers
  # Fix Arducam Pivariety driver + imx662
  curl -s --compressed "https://arducam.github.io/arducam_ppa/KEY.gpg" | sudo apt-key add -
            sudo curl -s --compressed -o /etc/apt/sources.list.d/arducam_list_files.list "https://arducam.github.io/arducam_ppa/arducam_list_files.list"
            sudo apt update
            apt-cache madison arducam-pivariety-sdk-dev
  sudo apt install -y \
  -o Dpkg::Options::=--force-overwrite \
  arducam-pivariety-sdk-dev=1.0.5
  wget https://dl.cloudsmith.io/public/openhd/release/deb/raspbian/pool/bullseye/main/l/li/libcamera-openhd_1.2.7/libcamera-openhd_1.2.7_armhf.deb
  dpkg -i --force-overwrite libcamera-openhd_1.2.7_armhf.deb 
  wget https://raw.githubusercontent.com/OpenHD/libcamera/refs/heads/openhd/src/ipa/rpi/vc4/data/imx662.json
  mv imx662.json /usr/share/libcamera/ipa/rpi/vc4/imx662.json
fi

if [[ "${OS}" == "radxa-debian-cubie" ]]; then
  echo "Removing KDE desktop packages for Radxa Cubie shell image"
  $APT purge 'kde*' 'plasma*' 'sddm*' task-kde-desktop konsole yakuake || true
  $APT autoremove --purge || true
  $APT install openssh-server sudo v4l-utils linux-libc-dev linux-image-5.15.147-21-a733 linux-headers-5.15.147-21-a733 
  ensure_openhd_user
  install_cubie_ssh_boot_fix
else
  echo "Installing QOpenHD package: ${qopenhd_package}"
  $APT install "${qopenhd_package}"
  ensure_openhd_user
fi

# Enable service
systemctl enable openhd || true

systemctl restart openhd || true
systemctl enable openhd-sys-utils

echo "Done. Detected board: ${OS}"
