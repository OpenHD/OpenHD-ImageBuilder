#!/bin/bash
set -euo pipefail

CONFIG_PARTITION_SIZE_MB="${CONFIG_PARTITION_SIZE_MB:-64}"
RECORDINGS_PARTITION_SIZE_MB="${RECORDINGS_PARTITION_SIZE_MB:-300}"
SECTOR_SIZE=512

log() {
  echo "$1"
}

image_file() {
  local img
  img=$(find "${PREV_WORK_DIR}" -maxdepth 1 -type f -name '*.img' | head -n 1)
  if [[ -z "${img}" ]]; then
    echo "No image found in ${PREV_WORK_DIR}" >&2
    exit 1
  fi
  echo "${img}"
}

has_partition_table_type() {
  local img="$1"
  local expected="$2"
  parted -s "${img}" print | awk -F: '/^Partition Table:/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' | grep -qi "^${expected}$"
}

last_partition_end_sector() {
  local img="$1"
  parted -sm "${img}" unit s print |
    awk -F: '$1 ~ /^[0-9]+$/ {gsub("s", "", $3); if ($3 > max) max = $3} END {print max + 0}'
}

align_sector() {
  local sector="$1"
  local alignment="${2:-2048}"
  echo $((sector + (alignment - sector % alignment) % alignment))
}

append_zeroes() {
  local img="$1"
  local size_mb="$2"
  local temp_file
  temp_file="$(mktemp)"
  dd if=/dev/zero of="${temp_file}" bs=1M count="${size_mb}"
  cat "${temp_file}" >> "${img}"
  rm -f "${temp_file}"
}

image_size_sectors() {
  local img="$1"
  local bytes
  bytes="$(stat -c%s "${img}")"
  echo $(((bytes + SECTOR_SIZE - 1) / SECTOR_SIZE))
}

allocate_partition_space() {
  local img="$1"
  local size_mb="$2"
  local min_start
  local file_end
  local start_sector
  local end_sector

  min_start="$(( $(last_partition_end_sector "${img}") + 1 ))"
  file_end="$(image_size_sectors "${img}")"
  if [[ "${file_end}" -gt "${min_start}" ]]; then
    min_start="${file_end}"
  fi

  start_sector="$(align_sector "${min_start}")"
  end_sector="$((start_sector + (size_mb * 1024 * 1024 / SECTOR_SIZE) - 1))"
  truncate -s "$(((end_sector + 1) * SECTOR_SIZE))" "${img}"
  sgdisk -e "${img}" >/dev/null 2>&1 || true

  echo "${start_sector} ${end_sector}"
}

next_partition_number() {
  local img="$1"
  parted -sm "${img}" unit s print |
    awk -F: '$1 ~ /^[0-9]+$/ {if ($1 > max) max = $1} END {print max + 1}'
}

create_partition() {
  local img="$1"
  local start_sector="$2"
  local end_sector="$3"
  local part_num

  sgdisk -e "${img}" >/dev/null 2>&1 || true
  part_num="$(next_partition_number "${img}")"
  parted -s "${img}" --script mkpart primary fat32 "${start_sector}s" "${end_sector}s"

  if has_partition_table_type "${img}" "gpt"; then
    parted -s "${img}" set "${part_num}" msftdata on
  else
    printf 't\n%s\n0c\nw\n' "${part_num}" | fdisk "${img}" >/dev/null
  fi

  echo "${part_num}"
}

format_partition() {
  local img="$1"
  local part_num="$2"
  local label="$3"
  local loop_device
  local part_device

  loop_device="$(losetup -f --show -P "${img}")"
  part_device="$(partition_device_for_loop "${loop_device}" "${part_num}" || true)"
  if [[ -z "${part_device}" ]]; then
    losetup -d "${loop_device}"
    echo "Unable to find partition ${part_num} on ${loop_device}" >&2
    exit 1
  fi

  mkfs.vfat -F 32 -n "${label}" "${part_device}"
  losetup -d "${loop_device}"
}

seed_openhd_config_partition() {
  local img="$1"
  local part_num="$2"
  local mount_dir
  local loop_device
  local part_device

  mount_dir="$(mktemp -d)"
  loop_device="$(losetup -f --show -P "${img}")"
  part_device="$(partition_device_for_loop "${loop_device}" "${part_num}" || true)"
  if [[ -z "${part_device}" ]]; then
    losetup -d "${loop_device}"
    rmdir "${mount_dir}"
    echo "Unable to find partition ${part_num} on ${loop_device}" >&2
    exit 1
  fi

  mount "${part_device}" "${mount_dir}"
  mkdir -p "${mount_dir}/openhd"
  touch "${mount_dir}/config.txt"
  sync
  umount "${mount_dir}"
  losetup -d "${loop_device}"
  rmdir "${mount_dir}"
}

partition_device_for_loop() {
  local loop_device="$1"
  local part_num="$2"
  local part_device="${loop_device}p${part_num}"

  if [[ ! -e "${part_device}" ]]; then
    part_device="${loop_device}${part_num}"
  fi
  if [[ ! -e "${part_device}" ]]; then
    echo ""
    return 1
  fi
  echo "${part_device}"
}

prepare_existing_openhd_partition() {
  local img="$1"
  local part_num="$2"
  local label="${3:-OPENHD}"
  local mount_dir
  local loop_device
  local part_device
  local mounted_loop_dev

  mount_dir="$(mktemp -d)"
  loop_device="$(losetup -f --show -P "${img}")"
  part_device="$(partition_device_for_loop "${loop_device}" "${part_num}" || true)"
  if [[ -z "${part_device}" ]]; then
    losetup -d "${loop_device}"
    rmdir "${mount_dir}"
    echo "Unable to find configured OpenHD partition ${part_num} on ${loop_device}" >&2
    exit 1
  fi

  mount "${part_device}" "${mount_dir}"
  mkdir -p "${mount_dir}/openhd"
  touch "${mount_dir}/config.txt"
  sync

  mounted_loop_dev="$(findmnt -nr -o source "${mount_dir}")"
  if [[ -n "${mounted_loop_dev}" ]]; then
    fatlabel "${mounted_loop_dev}" "${label}" || true
  fi

  umount "${mount_dir}"
  losetup -d "${loop_device}"
  rmdir "${mount_dir}"
}

add_fat32_partition() {
  local img
  local start_sector
  local end_sector
  local config_part_num
  local recordings_part_num
  local allocated

  img="$(image_file)"

  log ""
  log "======================================================"
  log "Preparing OpenHD FAT32 partitions in: ${img}"

  sgdisk -e "${img}" >/dev/null 2>&1 || true

  if [[ "${HAVE_CONF_PART:-false}" == "true" ]]; then
    if [[ -z "${CONF_PART:-}" ]]; then
      echo "HAVE_CONF_PART=true but CONF_PART is not set" >&2
      exit 1
    fi
    prepare_existing_openhd_partition "${img}" "${CONF_PART}" "OPENHD"
    log "Existing config partition prepared as OPENHD"
  elif [[ "${HAVE_BOOT_PART:-false}" == "true" ]]; then
    if [[ -z "${BOOT_PART:-}" ]]; then
      echo "HAVE_BOOT_PART=true but BOOT_PART is not set" >&2
      exit 1
    fi
    prepare_existing_openhd_partition "${img}" "${BOOT_PART}" "OPENHD"
    log "Existing boot partition prepared as OPENHD config storage"
  else
    allocated="$(allocate_partition_space "${img}" "${CONFIG_PARTITION_SIZE_MB}")"
    read -r start_sector end_sector <<< "${allocated}"
    config_part_num="$(create_partition "${img}" "${start_sector}" "${end_sector}")"
    format_partition "${img}" "${config_part_num}" "OPENHD"
    seed_openhd_config_partition "${img}" "${config_part_num}"
    log "OPENHD config partition added as partition ${config_part_num}"
  fi

  if [[ "${OS:-}" == "ubuntu-x86-minimal" ]] || [[ "${OS:-}" == "ubuntu-x86" ]] || [[ "${OS:-}" == "debian-X20" ]]; then
    log "Skipping appended recordings partition for ${OS}"
    return 0
  fi

  if has_partition_table_type "${img}" "msdos" && [[ "$(next_partition_number "${img}")" -gt 4 ]]; then
    log "Skipping appended recordings partition because the MBR partition table is full"
    return 0
  fi

  allocated="$(allocate_partition_space "${img}" "${RECORDINGS_PARTITION_SIZE_MB}")"
  read -r start_sector end_sector <<< "${allocated}"
  recordings_part_num="$(create_partition "${img}" "${start_sector}" "${end_sector}")"
  format_partition "${img}" "${recordings_part_num}" "RECORDINGS"
  log "RECORDINGS partition added as partition ${recordings_part_num}"
}

add_fat32_partition
