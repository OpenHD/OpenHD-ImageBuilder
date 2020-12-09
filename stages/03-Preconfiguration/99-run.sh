# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

cp ${STAGE_WORK_DIR}/mnt/openhd_version.txt ${WORK_DIR}/openhd_version.txt


MNT_DIR="${STAGE_WORK_DIR}/mnt"

if [[ "${HAVE_CONF_PARTITION}" == "false" ]] && [[ "${HAVE_BOOT_PARTITION}" == "true" ]]; then
# Rename the DOS partition
    BOOT_MNT_DIR="${STAGE_WORK_DIR}/mnt/boot"
    BOOT_LOOP_DEV="$(findmnt -nr -o source $BOOT_MNT_DIR)"

    fatlabel "$BOOT_LOOP_DEV" "OPENHD"
fi


#return
popd
