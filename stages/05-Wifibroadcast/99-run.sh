# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

MNT_DIR="${STAGE_WORK_DIR}/mnt"
sudo cp "$MNT_DIR/root/ld.so.preload" "$MNT_DIR/etc/ld.so.preload"

# Rename the DOS partition
BOOT_MNT_DIR="${STAGE_WORK_DIR}/mnt/boot"
BOOT_LOOP_DEV="$(findmnt -nr -o source $BOOT_MNT_DIR)"

fatlabel "$BOOT_LOOP_DEV" "OPENHD"

#return
popd
