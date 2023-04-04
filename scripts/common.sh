log (){
    date +"[%T] $*" | tee -a "${LOG_FILE}"
}
export -f log

mount_image () {
    IMG_FILE="${STAGE_WORK_DIR}/IMAGE.img"

    log "Mounting image file: ${IMG_FILE}"

    PARTED_OUT=$(parted -s "${IMG_FILE}" unit b print)

    if [[ "${HAVE_BOOT_PART}" == "true" ]]; then
        log "Mounting boot partition: ${BOOT_PART}"
        echo "Mounting boot partition: ${BOOT_PART}"

        BOOT_OFFSET=$(echo "$PARTED_OUT" | grep -e "^ ${BOOT_PART}" | xargs echo -n | cut -d" " -f 2 | tr -d B)
        BOOT_LENGTH=$(echo "$PARTED_OUT" | grep -e "^ ${BOOT_PART}" | xargs echo -n | cut -d" " -f 4 | tr -d B)
        BOOT_DEV=$(losetup --show -f -o "${BOOT_OFFSET}" --sizelimit "${BOOT_LENGTH}" "${IMG_FILE}")
        log "/boot: offset $BOOT_OFFSET, length $BOOT_LENGTH"
        echo "/boot: offset $BOOT_OFFSET, length $BOOT_LENGTH"
    fi

    if [[ "${HAVE_CONF_PART}" == "true" ]]; then
        log "Mounting conf partition: ${CONF_PART}"
        echo "Mounting conf partition: ${CONF_PART}"

        #for 2 digit grep matches there is no space here - "^${CONF_PART}"... 
        CONF_OFFSET=$(echo "$PARTED_OUT" | grep -e "^${CONF_PART}" | xargs echo -n | cut -d" " -f 2 | tr -d B)
        CONF_LENGTH=$(echo "$PARTED_OUT" | grep -e "^${CONF_PART}" | xargs echo -n | cut -d" " -f 4 | tr -d B)
        CONF_DEV=$(losetup --show -f -o "${CONF_OFFSET}" --sizelimit "${CONF_LENGTH}" "${IMG_FILE}")
        log "/conf: offset $CONF_OFFSET, length $CONF_LENGTH"
        echo "/conf: offset $CONF_OFFSET, length $CONF_LENGTH"
    fi

    log "Mounting root partition: ${ROOT_PART}"
    echo "Mounting root partition: ${ROOT_PART}"

    ROOT_OFFSET=$(echo "$PARTED_OUT" | grep -e "^ ${ROOT_PART}" | xargs echo -n | cut -d" " -f 2 | tr -d B)
    ROOT_LENGTH=$(echo "$PARTED_OUT" | grep -e "^ ${ROOT_PART}" | xargs echo -n | cut -d" " -f 4 | tr -d B)
    ROOT_DEV=$(losetup --show -f -o "${ROOT_OFFSET}" --sizelimit "${ROOT_LENGTH}" "${IMG_FILE}")


    log "/:     offset $ROOT_OFFSET, length $ROOT_LENGTH"
    echo "/:     offset $ROOT_OFFSET, length $ROOT_LENGTH"

    # Make sure the mount point is there
    MNT_DIR="${STAGE_WORK_DIR}/mnt"
    mkdir -p "${MNT_DIR}"

    # mount the ROOTFS partition
    mountpoint -q "${MNT_DIR}" || mount "$IMG_FILE" -o loop,offset=${ROOT_OFFSET},rw,sizelimit=${ROOT_LENGTH} "${MNT_DIR}"

    # give it some time
    sleep 5

    log "Resizing root to fill partition"
    echo "Resizing root to fill partition"

    # Resize to full size
    LOOP_DEV="$(findmnt -nr -o source $MNT_DIR)"
    log "loop_dev: ${LOOP_DEV}"
    resize2fs -f "$LOOP_DEV"

    # disable dir_index due to a weird bug when running qemu in a 32-bit chroot on 64-bit x86 hardware, readdir() fails in strange ways
    if [[ "${BIT}" == "32" ]]; then
        echo "Disabling dir_index on ${LOOP_DEV}"
        tune2fs -O ^dir_index ${LOOP_DEV} || true
    fi

    if [[ "${HAVE_BOOT_PART}" == "true" ]]; then
        echo "mount the BOOT partition"
        mountpoint -q "${MNT_DIR}/boot" || mount "$IMG_FILE" -o loop,offset=${BOOT_OFFSET},rw,sizelimit=${BOOT_LENGTH} "${MNT_DIR}/boot"
    fi

    if [[ "${HAVE_CONF_PART}" == "true" ]]; then
        echo "mount the conf partition"
        
        if [ -d "$MNT_DIR/boot/openhd" ]; then
            echo "conf DIR exists already..."
        else
            mkdir $MNT_DIR/boot/openhd
            echo "Created conf DIR..."
        fi
        
        mountpoint -q "${MNT_DIR}/boot/openhd" || mount "$IMG_FILE" -o loop,offset=${CONF_OFFSET},rw,sizelimit=${CONF_LENGTH} "${MNT_DIR}/boot/openhd"
    fi

    log "Finished mounting"
    echo "Finished mounting"
}
export -f mount_image

unmount_image(){
    sync
    sleep 1
    
    MNT_DIR="${STAGE_WORK_DIR}/mnt"
    #LOOP_DEV="$(findmnt -nr -o source $MNT_DIR)"
    
    if mount | grep -q "$MNT_DIR/boot"; then
        umount -l "$MNT_DIR/boot"
    fi

    if mount | grep -q "$MNT_DIR/conf"; then
        umount -l "$MNT_DIR/conf"
    fi

    if mount | grep -q "$MNT_DIR"; then
        umount -l "$MNT_DIR/"
    fi

    #log "Re-enabling dir_index on ${LOOP_DEV}"
    #tune2fs -O dir_index ${LOOP_DEV} || true
    #e2fsck -D ${LOOP_DEV} || true
}
export -f unmount_image

on_chroot() {
    MNT_DIR="${STAGE_WORK_DIR}/mnt"

    echo "Binding host partitions on ${MNT_DIR}"

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
        rm -Rf "${MNT_DIR}/etc/resolv.conf"
        echo "nameserver 1.1.1.1" > "${MNT_DIR}/etc/resolv.conf"
        mount --bind /etc/resolv.conf "${MNT_DIR}/etc/resolv.conf"
    fi

    cp -r "${STAGE_DIR}/../../additionalFiles" "${MNT_DIR}/opt"
    #sudo chroot --userspec=1000:1000 "$MNT_DIR" /bin/bash "/home/pi/install.sh"
    capsh --drop=cap_setfcap "--chroot=${MNT_DIR}/" -- "$@"

    umount -l "${MNT_DIR}/etc/resolv.conf"
    umount -l "${MNT_DIR}/sys"
    umount -l "${MNT_DIR}/dev/pts"
    umount -l "${MNT_DIR}/dev"
    umount -l "${MNT_DIR}/proc"
}
export -f on_chroot

