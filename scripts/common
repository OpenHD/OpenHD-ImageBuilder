log (){
	date +"[%T] $*" | tee -a "${LOG_FILE}"
}
export -f log

mount_image () {
    IMG_FILE="${STAGE_WORK_DIR}/IMAGE.img"

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
    MNT_DIR="${STAGE_WORK_DIR}/mnt"
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
}
export -f mount_image

unmount_image(){
	sync
	sleep 1
	
	MNT_DIR="${STAGE_WORK_DIR}/mnt"
	if mount | grep -q "$MNT_DIR/boot"; then
		umount -l "$MNT_DIR/boot"
	fi
	if mount | grep -q "$MNT_DIR"; then
		umount -l "$MNT_DIR/"
	fi
}
export -f unmount_image

on_chroot() {
	MNT_DIR="${STAGE_WORK_DIR}/mnt"

	if ! mount | grep -q "${MNT_DIR}/proc)"; then
		mount -t proc proc "${MNT_DIR}/proc"
	fi

	if ! mount | grep -q "${MNT_DIR}/dev)"; then
		mount --bind /dev "${MNT_DIR}/dev"
	fi
	
	if ! mount | grep -q "${MNT_DIR}/dev/pts)"; then
		mount --bind /dev/pts "${MNT_DIR}/dev/pts"
	fi

	if ! mount | grep -q "${MNT_DIR}/sys)"; then
		mount --bind /sys "${MNT_DIR}/sys"
	fi

	if ! mount | grep -q "${MNT_DIR}/etc/resolv.conf)"; then
                mount --bind /etc/resolv.conf "${MNT_DIR}/etc/resolv.conf"
        fi

	#cp "${STAGE_DIR}/$1" "${MNT_DIR}/home/pi/install.sh"
	#sudo chroot --userspec=1000:1000 "$MNT_DIR" /bin/bash "/home/pi/install.sh"
	capsh --drop=cap_setfcap "--chroot=${MNT_DIR}/" -- "$@"

	umount -l "${MNT_DIR}/etc/resolv.conf"
	umount -l "${MNT_DIR}/sys"
	umount -l "${MNT_DIR}/dev/pts"
	umount -l "${MNT_DIR}/dev"
	umount -l "${MNT_DIR}/proc"
}
export -f on_chroot

