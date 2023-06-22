# Extend Image Size

pushd ${STAGE_WORK_DIR}

    #Makes the images flashable with raspberry pi imager
    log "We now define the size to be ~15GB (the maximum size we have in our github builder, this doesn't affect the output image because we're resizeing it in the end before uploading the image)" 
    if [[ "${OS}" == radxa-ubuntu ]] || [[ "${OS}" == radxa-debian ]] ; then
    WANTEDSIZE="14500000256"
    else
    WANTEDSIZE="16500000256"
    fi
    FILESIZE=$(stat -c%s "IMAGE.img")
    DIFFERENCE=$(expr $WANTEDSIZE - $FILESIZE)
    DIFFERENCE=$(expr $DIFFERENCE - 1)
    echo "partitions in image:"
    sudo gdisk -l IMAGE.img
    echo "IMAGE will be extended with"
    echo $DIFFERENCE
    echo "bytes"
    ls -l

    log "Create empty image" #this will be attached to the base image to increase the size of it
    dd if=/dev/zero of=temp.img bs=1 count=1 seek=$DIFFERENCE
    ls -l


    log "Enlarge the downloaded image"
    cat temp.img >> IMAGE.img

    # if [[ "${OS}" == radxa-ubuntu ]] || [[ "${OS}" == radxa-debian ]] ; then
    # echo "resize with parted"
    # #fixing bad partition table
    # echo -e "x\ne\nd\nn\n\n\n\n\nw\ny\n" | sudo gdisk IMAGE.img
    # sudo parted -s IMAGE.img resizepart 2 100%
    # sudo gdisk -l IMAGE.img
    # else

    log "fdisk magic to enlarge the main partition"
    #calculating image offsets
    #debug showing all offsets:
    echo "Partition information for /dev/sda:"
    sudo parted -m IMAGE.img unit s print | awk -F: '$1 ~ /^[0-9]+$/ {print "Partition " $1 ": " $2 " - " $3 " (offset: " $2 "s)"}'

    PARTED_OUT=$(parted -s IMAGE.img unit s print)
    ROOT_OFFSET=$(echo "$PARTED_OUT" | grep -e "^ ${ROOT_PART}"| xargs echo -n \
        | cut -d" " -f 2 | tr -d s)
    
    echo "ROOT PART: ${ROOT_PART}"
    echo "ROOT OFFSET: $ROOT_OFFSET"
    echo "IF EDITING THIS SCRIPT THE SPACES MATER FOR FDISK COMMANDS"
    #Now we delete the root Partition , write a new partition and write the calculated size to have a larger root-partition)
    #DO NOT TOUCH OR REFORMAT .. this is quite annoying

    fdisk IMAGE.img <<EOF
d
${ROOT_PART}
n
p
${ROOT_PART}
${ROOT_OFFSET}

w
EOF

popd