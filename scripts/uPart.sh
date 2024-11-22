#!/bin/bash

version="v0.0.1"

# Log function
log() {
  echo "$1"
}

# Create and append a FAT32 partition to the image
add_fat32_partition() {
  log ""
  log "======================================================"
  log "Adding Fat32 Video Partition to: ${IMAGE_PATH_NAME}"

  dd if=/dev/zero of=fat.img bs=1M count=300
  cat fat.img >> "${PREV_WORK_DIR}"/*.img
  rm -f fat.img
  if [[ "${OS}" == "ubuntu-x86-minimal" ]] || [[ "${OS}" == "ubuntu-x86" ]] || [[ "${OS}" == "debian-X20" ]]; then
    echo "Video partition not supporte yet"
  elif [[ "${OS}" == "radxa-debian-rock-cm3" ]]; then
    sgdisk -e "${PREV_WORK_DIR}"/*.img
    echo -e "n\n4\n\n\n\n0C00\nw\ny" | sudo gdisk "${PREV_WORK_DIR}"/*.img
    sudo parted "${PREV_WORK_DIR}"/*.img set 4 msftdata on
    log "Video partition added"
    local loop_device
    loop_device=$(sudo losetup -f --show -P "${PREV_WORK_DIR}"/*.img)
    sudo mkfs.fat -F 32 "${loop_device}p4"
    sudo losetup -d "${loop_device}"
  else
    local first_sec
    first_sec=$(($(parted -s "${PREV_WORK_DIR}"/*.img unit s print | awk '/^ 2 / {gsub("s", "", $3); print $3}') + 1))
    first_sec=$((first_sec + (2048 - first_sec % 2048) % 2048))
    sudo parted "${PREV_WORK_DIR}"/*.img --script mkpart primary fat32 "${first_sec}s" 100%
    echo -e "t\n3\n0c\nw" | fdisk "${PREV_WORK_DIR}"/*.img
    log "Video partition added"
    # local loop_device
    # loop_device=$(sudo losetup -f --show -o $((first_sec * 512)) "${PREV_WORK_DIR}"/*.img)
    # sudo mkfs.fat -F 32 "${loop_device}"
    # sudo losetup -d "${loop_device}"
  fi
}

# Call the function to add FAT32 partition
add_fat32_partition
