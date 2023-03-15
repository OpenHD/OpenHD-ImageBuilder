# Extend Image Size
pushd ${STAGE_WORK_DIR}

function resize_partitions {

    #Makes the images flashable with raspberry pi imager
    log "Calculate difference between original Image and Wanted size (7GB)" 
    WANTEDSIZE="15168000000"
    FILESIZE=$(stat -c%s "IMAGE.img")
    DIFFERENCE=$(expr $WANTEDSIZE - $FILESIZE)
    DIFFERENCE=$(expr $DIFFERENCE - 1)


    log "Create empty image" #this will be attached to the base image to increase the size of it
    dd if=/dev/zero of=temp.img bs=1 count=1 seek=$DIFFERENCE


    log "Enlarge the downloaded image"
    cat temp.img >> IMAGE.img

    log "fdisk magic to enlarge the main partition"
    #calculating image offsets
    PARTED_OUT=$(parted -s IMAGE.img unit s print)
    ROOT_OFFSET=$(echo "$PARTED_OUT" | grep -e "^ ${ROOT_PART}"| xargs echo -n \
        | cut -d" " -f 2 | tr -d s)
    
    echo "ROOT OFFSET: $ROOT_OFFSET"
    echo "IF EDITING THIS SCRIPT THE SPACES MATER FOR FDISK COMMANDS"
    #Now we delete Partition 2, write a new partition 2 and write the calculated size to have a larger root-partition)

fdisk IMAGE.img <<END_CMD
d
${ROOT_PART}
n
p
${ROOT_PART}
${ROOT_OFFSET}
w
END_CMD
}



resize_partitions

popd