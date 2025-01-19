# Extend Image Size
ls -a ../../
if [ ! -e ../../emmc ]; then
    if [[ "${OS}" == radxa-debian-rock5a ]] || [[ "${OS}" == radxa-debian-rock5b ]];then
    WANTEDSIZE="6800000000"
    else
    WANTEDSIZE="5632000000"
    fi
else
WANTEDSIZE="10500000256"
echo "_______________________________________________________________________"
echo "this is the emmc-model"
echo "_______________________________________________________________________"

fi

pushd ${STAGE_WORK_DIR}

    #Makes the images flashable with raspberry pi imager
    log "We now define the size to be ~15GB (the maximum size we have in our github builder, this doesn't affect the output image because we're resizeing it in the end before uploading the image)" 
    FILESIZE=$(stat -c%s "IMAGE.img")
    DIFFERENCE=$(expr $WANTEDSIZE - $FILESIZE)
    DIFFERENCE=$(expr $DIFFERENCE - 1)
    echo "partitions in image:"
    sudo gdisk -l IMAGE.img
    echo "IMAGE will be extended with"
    echo $DIFFERENCE
    echo "bytes"
    ls -l

if [[ "${OS}" != ubuntu-x86 ]] && [[ "${OS}" != debian-X20 ]]; then

    log "Create empty image" #this will be attached to the base image to increase the size of it
    dd if=/dev/zero of=temp.img bs=1 count=1 seek=$DIFFERENCE
    ls -l

    log "Enlarge the downloaded image"
    cat temp.img >> IMAGE.img


    if [[ "${OS}" == radxa-debian-rock5a ]] || [[ "${OS}" == radxa-debian-rock5b ]] || [[ "${OS}" == radxa-debian-rock-cm3 ]] || [[ "${OS}" == radxa-debian-rock-cm3-core3566 ]]; then
    echo "resize with parted"
    echo -e "x\ne\nd\nn\n\n\n\n\nw\ny\n" | sudo gdisk IMAGE.img
    sudo parted -s IMAGE.img resizepart ${ROOT_PART} 100%
    sudo gdisk -l IMAGE.img
    else

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
fi

else 
echo "the image doesn't need to be enlarged, just using it like it is"
fi

popd