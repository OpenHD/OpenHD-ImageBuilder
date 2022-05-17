# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

if [[ "${OS}" == "raspbian" ]]; then

    log "Calculate difference between original Image and Wanted size (7GB)"
    WANTEDSIZE="7168000000"
    FILESIZE=$(stat -c%s "IMAGE.img")
    DIFFERENCE=$(expr $WANTEDSIZE - $FILESIZE)
    DIFFERENCE=$(expr $DIFFERENCE - 1)


    log "Create empty image"
    dd if=/dev/zero of=temp.img bs=1 count=1 seek=$DIFFERENCE


    log "Enlarge the downloaded image"
    cat temp.img >> IMAGE.img

    log "fdisk magic to enlarge the main partition"

    PARTED_OUT=$(parted -s IMAGE.img unit s print)
    ROOT_OFFSET=$(echo "$PARTED_OUT" | grep -e "^ ${ROOT_PART}"| xargs echo -n \
        | cut -d" " -f 2 | tr -d s)

    echo "ROOT OFFSET: $ROOT_OFFSET"
    echo "IF EDITING THIS SCRIPT THE SPACES MATER FOR FDISK COMMANDS"

    fdisk IMAGE.img <<EOF
d
2
n
p
2
${ROOT_OFFSET}

w
EOF
fi

if [[ "${OS}" == "ubuntu" ]]; then

    log "Calculate difference between original Image and Wanted size (~16GB)"
        WANTEDSIZE="15872000000"
        FILESIZE=$(stat -c%s "IMAGE.img")
        DIFFERENCE=$(expr $WANTEDSIZE - $FILESIZE)
        DIFFERENCE=$(expr $DIFFERENCE - 1)
    log $DIFFERENCE

    log "Create empty image"
    dd if=/dev/zero of=temp.img bs=1 count=1 seek=$DIFFERENCE

    log "Enlarge the downloaded image"
    cat temp.img >> IMAGE.img

    log "fdisk to enlarge the main partition"

    PARTED_OUT=$(parted -s IMAGE.img unit s print)
    ROOT_OFFSET=$(echo "$PARTED_OUT" | grep -e "^ ${ROOT_PART}"| xargs echo -n \
        | cut -d" " -f 2 | tr -d s)

    echo "ROOT OFFSET: $ROOT_OFFSET"
    echo "IF EDITING THIS SCRIPT THE SPACES MATER FOR FDISK COMMANDS" 
    fdisk IMAGE.img <<EOF
d
1
n
1
${ROOT_OFFSET}

w
EOF
sgdisk -c 1:APP IMAGE.img
fi

rm temp.img

# return
popd
