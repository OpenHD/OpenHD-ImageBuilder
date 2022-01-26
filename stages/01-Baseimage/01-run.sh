# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

if [[ "${OS}" == "raspbian" ]]; then

    log "Create 4Gb empty image"
    dd if=/dev/zero of=temp.img bs=1 count=1 seek=4G


    log "Enlarge the downloaded image by 4Gb"
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

    log "Create empty image"
    dd if=/dev/zero of=temp.img bs=1 count=1 seek=2G


    log "Enlarge the downloaded image"
    cat temp.img >> IMAGE.img

    log "fdisk to enlarge the main partition"

    PARTED_OUT=$(parted -s IMAGE.img unit s print)
    ROOT_OFFSET=$(echo "$PARTED_OUT" | grep -e "^ ${ROOT_PART}"| xargs echo -n \
        | cut -d" " -f 2 | tr -d s)

    echo "ROOT OFFSET: $ROOT_OFFSET"
    echo "IF EDITING THIS SCRIPT THE SPACES MATER FOR FDISK COMMANDS" 
        #Jetson needs more space
    fdisk IMAGE.img <<EOF
d
1
n
1
${ROOT_OFFSET}

w
EOF
fi
sgdisk -c 1:APP IMAGE.img

rm temp.img

# return
popd
