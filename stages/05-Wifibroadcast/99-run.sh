# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

MNT_DIR="${STAGE_WORK_DIR}/mnt"
sudo cp "$MNT_DIR/root/ld.so.preload" "$MNT_DIR/etc/ld.so.preload"

sudo cp "${MNT_DIR}/boot/openhd-settings-1.txt" "${MNT_DIR}/boot/openhd-settings-2.txt"
sudo cp "${MNT_DIR}/boot/openhd-settings-1.txt" "${MNT_DIR}/boot/openhd-settings-3.txt"
sudo cp "${MNT_DIR}/boot/openhd-settings-1.txt" "${MNT_DIR}/boot/openhd-settings-4.txt"


# Rename the DOS partition
BOOT_MNT_DIR="${STAGE_WORK_DIR}/mnt/boot"
BOOT_LOOP_DEV="$(findmnt -nr -o source $BOOT_MNT_DIR)"

fatlabel "$BOOT_LOOP_DEV" "OPENHD"

#return
popd
