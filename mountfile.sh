#!/bin/bash

IMG_FILE=$1/IMAGE.img

PARTED_OUT=$(parted -s "${IMG_FILE}" unit b print)
    BOOT_OFFSET=$(echo "$PARTED_OUT" | grep -e '^ 1'| xargs echo -n \
    | cut -d" " -f 2 | tr -d B)
    BOOT_LENGTH=$(echo "$PARTED_OUT" | grep -e '^ 1'| xargs echo -n \
    | cut -d" " -f 4 | tr -d B)

    ROOT_OFFSET=$(echo "$PARTED_OUT" | grep -e '^ 2'| xargs echo -n \
    | cut -d" " -f 2 | tr -d B)
    ROOT_LENGTH=$(echo "$PARTED_OUT" | grep -e '^ 2'| xargs echo -n \
    | cut -d" " -f 4 | tr -d B)

    BOOT_DEV=$(losetup --show -f -o "${BOOT_OFFSET}" --sizelimit "${BOOT_LENGTH}" "${IMG_FILE}")
    ROOT_DEV=$(losetup --show -f -o "${ROOT_OFFSET}" --sizelimit "${ROOT_LENGTH}" "${IMG_FILE}")
    log "/boot: offset $BOOT_OFFSET, length $BOOT_LENGTH"
    log "/:     offset $ROOT_OFFSET, length $ROOT_LENGTH"

    # Make sure the mount point is there
    MNT_DIR="$1/mnt"
    mkdir -p "${MNT_DIR}"

    # mount the ROOTFS partition
    mountpoint -q "${MNT_DIR}" || mount "$IMG_FILE" -o loop,offset=${ROOT_OFFSET},rw,sizelimit=${ROOT_LENGTH} "${MNT_DIR}"

    # give it some time
	sleep 5

	# Resize to full size
	LOOP_DEV="$(findmnt -nr -o source $MNT_DIR)"
	resize2fs -f "$LOOP_DEV"

    # mount the BOOT partition
    mountpoint -q "${MNT_DIR}/boot" || mount "$IMG_FILE" -o loop,offset=${BOOT_OFFSET},rw,sizelimit=${BOOT_LENGTH} "${MNT_DIR}/boot"
