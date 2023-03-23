# Extend Image Size
pushd ${STAGE_WORK_DIR}

    #Makes the images flashable with raspberry pi imager
    log "We now define the size to be ~15GB (the maximum size we have in our github builder, this doesn't affect the output image because we're resizeing it in the end before uploading the image)" 
    WANTEDSIZE="16500000000"
    FILESIZE=$(stat -c%s "IMAGE.img")
    DIFFERENCE=$(expr $WANTEDSIZE - $FILESIZE)
    DIFFERENCE=$(expr $DIFFERENCE - 1)


    log "Create empty image" #this will be attached to the base image to increase the size of it
    dd if=/dev/zero of=temp.img bs=1 count=1 seek=$DIFFERENCE


    log "Enlarge the downloaded image"
    cat temp.img >> IMAGE.img

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