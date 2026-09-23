#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <base-firmware.zip> <openhd-orqa-deploy.tar.gz> <wifi_cards.json> <output.zip>" >&2
}

if [[ $# -ne 4 ]]; then
  usage
  exit 2
fi

base_archive="$(realpath "$1")"
deploy_archive="$(realpath "$2")"
wifi_cards="$(realpath "$3")"
output_archive="$(realpath -m "$4")"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
overlay_dir="${script_dir}/orqa-overlay"
work_dir="$(mktemp -d)"
bundle_dir="${work_dir}/bundle"
payload_dir="${work_dir}/payload"
root_dir="${work_dir}/root"
loop_device=""
root_mounted=false

check_rootfs() {
  local status
  set +e
  e2fsck -pf "$1"
  status=$?
  set -e
  if (( status > 1 )); then
    echo "ORQA root filesystem check failed with status ${status}" >&2
    exit "${status}"
  fi
}

cleanup() {
  set +e
  sync
  if [[ "${root_mounted}" == true ]] && mountpoint -q "${root_dir}"; then
    umount "${root_dir}"
  fi
  if [[ -n "${loop_device}" ]]; then
    losetup -d "${loop_device}"
  fi
  rm -rf "${work_dir}"
}
trap cleanup EXIT

for required in "${base_archive}" "${deploy_archive}" "${wifi_cards}"; do
  if [[ ! -s "${required}" ]]; then
    echo "Required ORQA input is missing or empty: ${required}" >&2
    exit 1
  fi
done

for required in \
  "${overlay_dir}/etc/systemd/system/openhd.service" \
  "${overlay_dir}/lib/systemd/system/openhd-sys-utils.service"; do
  if [[ ! -f "${required}" ]]; then
    echo "Required ORQA overlay file is missing: ${required}" >&2
    exit 1
  fi
done

mkdir -p "${bundle_dir}" "${payload_dir}" "${root_dir}"
unzip -q "${base_archive}" -d "${bundle_dir}"

for required in \
  bootloader.img \
  kernel.img \
  partition-table.img \
  recovery.img \
  rootfs.img \
  uuu.auto; do
  if [[ ! -s "${bundle_dir}/${required}" ]]; then
    echo "ORQA base archive does not contain ${required}" >&2
    exit 1
  fi
done

if [[ "$(find "${bundle_dir}" -mindepth 1 -maxdepth 1 -type f | wc -l)" -ne 6 ]]; then
  echo "ORQA base archive must contain exactly the six expected flash files" >&2
  find "${bundle_dir}" -mindepth 1 -maxdepth 1 -printf '%P\n' >&2
  exit 1
fi

tar -xzf "${deploy_archive}" -C "${payload_dir}"
for required in openhd openhd_sys_utils iwconfig; do
  if [[ ! -x "${payload_dir}/${required}" ]]; then
    echo "ORQA deploy archive does not contain executable ${required}" >&2
    exit 1
  fi
done

if command -v readelf >/dev/null 2>&1; then
  for binary in openhd openhd_sys_utils iwconfig; do
    if ! readelf -h "${payload_dir}/${binary}" | grep -q 'Machine:.*AArch64'; then
      echo "ORQA deploy binary is not AArch64: ${binary}" >&2
      exit 1
    fi
  done
fi

check_rootfs "${bundle_dir}/rootfs.img"
loop_device="$(losetup --find --show "${bundle_dir}/rootfs.img")"
mount "${loop_device}" "${root_dir}"
root_mounted=true

# The ORQA CI payload is deliberately package-manager independent. Put its
# libraries and plugin into their target paths, then install the three target
# binaries at the same locations used by normal OpenHD packages.
if [[ -d "${payload_dir}/usr" ]]; then
  cp -a "${payload_dir}/usr/." "${root_dir}/usr/"
fi
install -D -m 0755 "${payload_dir}/openhd" \
  "${root_dir}/usr/local/bin/openhd"
install -D -m 0755 "${payload_dir}/openhd_sys_utils" \
  "${root_dir}/usr/local/bin/openhd_sys_utils"
install -D -m 0755 "${payload_dir}/iwconfig" \
  "${root_dir}/usr/sbin/iwconfig"
ln -sfn ../sbin/iwconfig "${root_dir}/usr/bin/iwconfig"

install -D -m 0644 "${wifi_cards}" \
  "${root_dir}/usr/local/share/OpenHD/SysUtils/wifi_cards.json"
install -D -m 0644 \
  "${overlay_dir}/lib/systemd/system/openhd-sys-utils.service" \
  "${root_dir}/lib/systemd/system/openhd-sys-utils.service"
install -D -m 0644 \
  "${overlay_dir}/etc/systemd/system/openhd.service" \
  "${root_dir}/etc/systemd/system/openhd.service"

mkdir -p \
  "${root_dir}/etc/systemd/system/multi-user.target.wants" \
  "${root_dir}/usr/local/share/OpenHD/SysUtils"
ln -sfn /lib/systemd/system/openhd-sys-utils.service \
  "${root_dir}/etc/systemd/system/multi-user.target.wants/openhd-sys-utils.service"
ln -sfn /etc/systemd/system/openhd.service \
  "${root_dir}/etc/systemd/system/multi-user.target.wants/openhd.service"

# ORQA DTK images are air units. Leave camera selection to SysUtils first boot,
# which detects the ORQA device tree and seeds the supported camera defaults.
if [[ ! -e "${root_dir}/usr/local/share/OpenHD/SysUtils/config.json" ]]; then
  install -D -m 0644 /dev/null \
    "${root_dir}/usr/local/share/OpenHD/SysUtils/config.json"
  printf '%s\n' '{"run_mode":"air","firstboot":true}' > \
    "${root_dir}/usr/local/share/OpenHD/SysUtils/config.json"
fi

sync
umount "${root_dir}"
root_mounted=false
losetup -d "${loop_device}"
loop_device=""
check_rootfs "${bundle_dir}/rootfs.img"

mkdir -p "$(dirname "${output_archive}")"
rm -f "${output_archive}"
(
  cd "${bundle_dir}"
  zip -q -r -y "${output_archive}" \
    bootloader.img \
    kernel.img \
    partition-table.img \
    recovery.img \
    rootfs.img \
    uuu.auto
)

test -s "${output_archive}"
sha256sum "${output_archive}"
