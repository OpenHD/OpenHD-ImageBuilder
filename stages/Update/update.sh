#!/usr/bin/env bash
set -euo pipefail

trap 'echo "ERROR: failed at line $LINENO"; exit 1' ERR

# Require root
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root (e.g. sudo $0)"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
APT="apt -o Dpkg::Options::=--force-confnew -y --allow-downgrades"

print_linux_package_metadata() {
  local package_regex="${LINUX_METADATA_PACKAGE_REGEX:-^linux-(headers|image|libc-dev)}"

  echo "#######################################################"
  echo "#######################################################"
  echo "#######################################################"
  echo "#######################################################"
  echo "#######################################################"
  echo "Metadata for installed Linux kernel-related packages:"
  echo "Package regex: ${package_regex}"

  while read -r package; do
    echo
    echo "#######################################################"
    echo "### ${package}"
    echo "#######################################################"

    echo
    echo "### dpkg status"
    dpkg-query -s "${package}" || true

    echo
    echo "### apt policy"
    apt-cache policy "${package}" || true

    echo
    echo "### apt show"
    apt-cache show --no-all-versions "${package}" || true

    echo
    echo "### apt source metadata"
    apt-cache showsrc "${package}" || true

    echo
    echo "### apt madison"
    apt-cache madison "${package}" || true

    echo
    echo "### dpkg info files"
    find /var/lib/dpkg/info -maxdepth 1 -type f -name "${package}.*" -print || true

    if [[ -d "/usr/share/doc/${package}" ]]; then
      echo
      echo "### doc metadata files"
      find "/usr/share/doc/${package}" -maxdepth 1 -type f \
        \( -name 'copyright' -o -name 'changelog*' -o -name 'NEWS*' -o -name 'README*' \) \
        -print || true
    fi
  done < <(
    dpkg-query -W -f='${db:Status-Abbrev}\t${binary:Package}\n' \
      | awk -v regex="${package_regex}" '$1 ~ /^ii/ && $2 ~ regex { print $2 }'
  )
}

if [[ "${UPDATE_LINUX_PACKAGES_ONLY:-false}" == "true" && "${OPENHD_LITE_IMAGE:-false}" != "true" ]]; then
  print_linux_package_metadata
  echo "Done. UPDATE_LINUX_PACKAGES_ONLY is set, skipping OpenHD/QOpenHD package changes."
  exit 0
fi

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

    # Disable Radxa repos for full images (broken GPG in some CI chroots).
    # Lite images need Radxa kernel packages, so they repair the keyring below.
    if [[ "${OPENHD_LITE_IMAGE:-false}" != "true" ]]; then
      sed -i '/radxa-repo.github.io/s/^/#/' "$f" || true
    fi
  done

  echo "APT source cleanup done."
}

fix_apt_sources

refresh_radxa_apt_for_lite() {
  if [[ "${OPENHD_LITE_IMAGE:-false}" != "true" ]]; then
    return 0
  fi

  if [[ "${OS:-}" != radxa-* ]]; then
    return 0
  fi

  echo "Refreshing Radxa APT keyring for OpenHD Lite image"
  if compgen -G "/etc/apt/sources.list.d/*.list" > /dev/null; then
    sed -i '/radxa-repo.github.io/s/^#//' /etc/apt/sources.list.d/*.list || true
  fi
  if [[ -f /etc/apt/sources.list ]]; then
    sed -i '/radxa-repo.github.io/s/^#//' /etc/apt/sources.list || true
  fi

  local keyring
  local version
  keyring="$(mktemp)"
  version="$(curl -Ls https://github.com/radxa-pkg/radxa-archive-keyring/releases/latest/download/VERSION || true)"
  if [[ -n "${version}" ]]; then
    curl -L --output "${keyring}" "https://github.com/radxa-pkg/radxa-archive-keyring/releases/latest/download/radxa-archive-keyring_${version}_all.deb" \
      && dpkg -i "${keyring}" || true
  fi
  rm -f "${keyring}"
}

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

# Determine OS (board)
if [[ -z "${OS:-}" ]]; then
  os_id="$(. /etc/os-release; echo "${ID}-${VERSION_CODENAME}")"
  export OS="${os_id}"
fi

# Best-effort update
refresh_radxa_apt_for_lite
apt update || echo "Warning: apt update failed but continuing…"

print_linux_package_metadata

if [[ "${OPENHD_LITE_IMAGE:-false}" == "true" ]]; then
  echo "OpenHD Lite image detected, skipping full OpenHD/QOpenHD package set."
elif [[ "${OS}" != "radxa-debian-rock3a" ]]; then
  # Remove conflicting packages
  $APT remove openhd openhd-sys-utils 'qopenhd*' || true

  # Install base packages
  $APT install openhd libpoco-dev open-hd-web-ui openhd-sys-utils
else
  echo "Skipping OpenHD package install for Radxa Rock 3A"
fi

# Install qopenhd or fallback
qopenhd_package="${QOPENHD_PACKAGE:-qopenhd}"

install_packages_from_list() {
  local label="$1"
  local package_string="${2:-}"
  local -a packages=()

  if [[ -z "${package_string//[[:space:]]/}" ]]; then
    echo "No ${label} configured, skipping."
    return 0
  fi

  read -r -a packages <<< "${package_string}"
  echo "Installing ${label}: ${packages[*]}"
  $APT install "${packages[@]}"
}

install_packages_with_disabled_dkms_prerm() {
  local label="$1"
  local package_string="${2:-}"
  local dkms_prerm="/etc/kernel/prerm.d/dkms"
  local disabled_dkms_prerm="${dkms_prerm}.openhd-disabled"
  local rc

  if [[ -z "${package_string//[[:space:]]/}" ]]; then
    echo "No ${label} configured, skipping."
    return 0
  fi

  if [[ -e "${dkms_prerm}" ]]; then
    echo "Temporarily disabling DKMS kernel pre-remove hook for kernel replacement"
    mv "${dkms_prerm}" "${disabled_dkms_prerm}"
  fi

  set +e
  install_packages_from_list "${label}" "${package_string}"
  rc=$?
  set -e

  if [[ -e "${disabled_dkms_prerm}" ]]; then
    mv "${disabled_dkms_prerm}" "${dkms_prerm}"
    echo "Restored DKMS kernel pre-remove hook"
  fi

  return "${rc}"
}

install_local_lite_debs() {
  local deb_root="${OPENHD_LITE_LOCAL_DEB_DIR:-/opt/additionalFiles/openhd-lite-debs}"
  local image_type="${IMAGE_TYPE:-}"
  local deb_dir="${deb_root}"
  local board_deb_dir="${deb_root}/${image_type}"
  local -a debs=()

  OPENHD_LITE_LOCAL_DEBS_INSTALLED=false

  if [[ -n "${image_type}" && -d "${board_deb_dir}" ]]; then
    deb_dir="${board_deb_dir}"
  fi

  if [[ ! -d "${deb_dir}" ]]; then
    echo "No local OpenHD Lite deb directory found at ${deb_dir}, skipping."
    return 0
  fi

  mapfile -t debs < <(find "${deb_dir}" -maxdepth 1 -type f -name '*.deb' | sort)
  if [[ "${#debs[@]}" -eq 0 ]]; then
    echo "No local OpenHD Lite debs found in ${deb_dir}, skipping."
    return 0
  fi

  echo "Installing local OpenHD Lite debs from ${deb_dir}"
  OPENHD_LITE_LOCAL_DEBS_INSTALLED=true
  dpkg -i "${debs[@]}" || apt -o Dpkg::Options::=--force-confnew -y -f install
}

install_lite_kernel_packages() {
  local kernel_packages="${KERNEL_PACKAGES:-}"

  install_local_lite_debs
  if [[ "${OPENHD_LITE_LOCAL_DEBS_INSTALLED:-false}" == "true" ]]; then
    echo "Local OpenHD Lite kernel debs installed; skipping repository kernel package install."
    return 0
  fi

  if [[ "${OS}" == "radxa-debian-cubie" ]]; then
    install_packages_with_disabled_dkms_prerm "custom kernel packages" "${kernel_packages}"
  else
    install_packages_from_list "custom kernel packages" "${kernel_packages}"
  fi
}

ensure_kernel_headers() {
  local kver="$1"
  local header_dir

  if [[ -e "/lib/modules/${kver}/build/Makefile" ]]; then
    return 0
  fi

  apt -o Dpkg::Options::=--force-confnew -y install "linux-headers-${kver}" || true
  if [[ ! -e "/lib/modules/${kver}/build/Makefile" ]]; then
    header_dir="$(find /usr/src -maxdepth 1 -type d \( -name "linux-headers-${kver}" -o -name "*${kver}*" \) | head -n1 || true)"
    if [[ -n "${header_dir}" ]]; then
      ln -sfn "${header_dir}" "/lib/modules/${kver}/build"
    fi
  fi

  [[ -e "/lib/modules/${kver}/build/Makefile" ]]
}

build_one_rtl_driver() {
  local repo_url="$1"
  local module_name="$2"
  local user_module_name="$3"
  local kver="$4"
  local work_root="$5"
  local source_dir="${work_root}/$(basename "${repo_url%.git}")"
  local -a make_args
  local ko

  if [[ ! -d "${source_dir}" ]]; then
    git clone --recursive --depth 1 "${repo_url}" "${source_dir}"
  fi

  make -C "${source_dir}" clean || true
  make_args=(-C "${source_dir}" -j"$(nproc)" ARCH=arm64 KVER="${kver}" KSRC="/lib/modules/${kver}/build")
  if [[ -n "${user_module_name}" ]]; then
    make_args+=(USER_MODULE_NAME="${user_module_name}")
  fi

  make "${make_args[@]}" modules
  ko="${source_dir}/${module_name}.ko"
  if [[ ! -f "${ko}" ]]; then
    ko="$(find "${source_dir}" -maxdepth 1 -name '*.ko' | head -n1)"
  fi
  if [[ -z "${ko}" || ! -f "${ko}" ]]; then
    echo "Failed to find built module for ${repo_url}" >&2
    return 1
  fi

  install -D -m 0644 "${ko}" "/lib/modules/${kver}/kernel/drivers/net/wireless/${module_name}.ko"
}

build_openhd_rtl_drivers_from_source() {
  local kernel_regex="${RTL_DRIVER_KERNEL_REGEX:-}"
  local work_root="/opt/openhd-rtl-driver-build"
  local -a kernels=()
  local -a filtered_kernels=()
  local kver

  if [[ "${BUILD_RTL_DRIVERS_FROM_SOURCE:-false}" != "true" ]]; then
    return 0
  fi

  echo "Building OpenHD RTL drivers from source"
  $APT install --no-install-recommends build-essential git make gcc bc bison flex kmod ca-certificates

  mapfile -t kernels < <(find /lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
  for kver in "${kernels[@]}"; do
    if [[ -z "${kernel_regex}" || "${kver}" =~ ${kernel_regex} ]]; then
      filtered_kernels+=("${kver}")
    fi
  done

  if [[ "${#filtered_kernels[@]}" -eq 0 ]]; then
    echo "No kernel modules matched RTL_DRIVER_KERNEL_REGEX='${kernel_regex}'" >&2
    return 1
  fi

  rm -rf "${work_root}"
  mkdir -p "${work_root}"

  for kver in "${filtered_kernels[@]}"; do
    echo "Building RTL drivers for kernel ${kver}"
    ensure_kernel_headers "${kver}"
    build_one_rtl_driver "https://github.com/OpenHD/rtl8812au.git" "88XXau_ohd" "88XXau" "${kver}" "${work_root}"
    build_one_rtl_driver "https://github.com/OpenHD/rtl88x2eu.git" "rtl88x2eu_ohd" "rtl88x2eu_ohd" "${kver}" "${work_root}"
    build_one_rtl_driver "https://github.com/OpenHD/rtl88x2bu.git" "88x2bu_ohd" "88x2bu" "${kver}" "${work_root}"
    build_one_rtl_driver "https://github.com/OpenHD/rtl88x2cu.git" "88x2cu_ohd" "" "${kver}" "${work_root}"
    depmod -a "${kver}" || true
  done
}

install_openhd_lite_packages() {
  local glide_package="${GLIDE_PACKAGE:-openhd-glide}"
  local core_packages="${OPENHD_LITE_PACKAGES:-openhd openhd-sys-utils}"

  echo "Installing OpenHD Lite package set"
  $APT purge 'qopenhd*' || true
  install_lite_kernel_packages
  install_packages_from_list "OpenHD Lite core packages" "${core_packages}"
  install_packages_from_list "OpenHD Glide package" "${glide_package}"
  install_packages_from_list "RTL driver packages" "${RTL_DRIVER_PACKAGES:-}"
  build_openhd_rtl_drivers_from_source
}

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

install_radxa_ssh_boot_fix() {
  cat >/usr/local/sbin/openhd-radxa-ssh-boot.sh <<'EOF'
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

  chmod 0755 /usr/local/sbin/openhd-radxa-ssh-boot.sh

  cat >/etc/systemd/system/openhd-radxa-ssh-boot.service <<'EOF'
[Unit]
Description=Keep SSH enabled for OpenHD on Radxa images
After=local-fs.target network.target rsetup-config-first-boot.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/openhd-radxa-ssh-boot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable openhd-radxa-ssh-boot.service || true
  /usr/local/sbin/openhd-radxa-ssh-boot.sh || true

  if [[ -d /conf ]]; then
    mkdir -p /conf/openhd
    touch /conf/openhd/resize.txt
    touch /conf/config.txt
    cat >/conf/before.txt <<'EOF'
remove_packages rsetup-config-first-boot
EOF
  fi
}

install_cubie_kernel_image_without_dkms_prerm() {
  local package_string="${1:-linux-image-5.15.147-21-a733}"
  local dkms_prerm="/etc/kernel/prerm.d/dkms"
  local disabled_dkms_prerm="${dkms_prerm}.openhd-disabled"
  local -a packages=()
  local rc

  if [[ -e "${dkms_prerm}" ]]; then
    echo "Temporarily disabling DKMS kernel pre-remove hook for Cubie kernel replacement"
    mv "${dkms_prerm}" "${disabled_dkms_prerm}"
  fi

  set +e
  read -r -a packages <<< "${package_string}"
  apt -o Dpkg::Options::=--force-confnew -y install "${packages[@]}"
  rc=$?
  set -e

  if [[ -e "${disabled_dkms_prerm}" ]]; then
    mv "${disabled_dkms_prerm}" "${dkms_prerm}"
    echo "Restored DKMS kernel pre-remove hook"
  fi

  return "${rc}"
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
  $APT install openssh-server sudo v4l-utils
  if [[ "${OPENHD_LITE_IMAGE:-false}" == "true" ]]; then
    install_openhd_lite_packages
  else
    $APT install linux-libc-dev
    $APT install linux-headers-5.15.147-21-a733
    install_cubie_kernel_image_without_dkms_prerm
  fi
  ensure_openhd_user
  install_radxa_ssh_boot_fix
elif [[ "${OS}" == "radxa-debian-rock3a" ]]; then
  $APT install openssh-server sudo v4l-utils
  ensure_openhd_user
  install_radxa_ssh_boot_fix
elif [[ "${OPENHD_LITE_IMAGE:-false}" == "true" ]]; then
  install_openhd_lite_packages
  ensure_openhd_user
else
  echo "Installing QOpenHD package: ${qopenhd_package}"
  $APT install "${qopenhd_package}"
  ensure_openhd_user
fi

if [[ "${OS}" != "radxa-debian-rock3a" ]]; then
  # Enable service
  systemctl enable openhd || true

  systemctl restart openhd || true
  systemctl enable openhd-sys-utils || true
fi

echo "Done. Detected board: ${OS}"
