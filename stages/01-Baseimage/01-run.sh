# Extend Image Size
pushd ${STAGE_WORK_DIR}

if [[ "${OS}" == "raspbian" ]] || [[ "${OS}" == "raspbian-legacy" ]] ; then

    #Makes the images flashable with raspberry pi imager
    log "Calculate difference between original Image and Wanted size (7GB)" 
    WANTEDSIZE="4168000000"
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

#jetson images now use custom base images because of a change to the jetson-jetpack 
# if [[ "${OS}" == "ubuntu" ]]; then
#      log "Calculate difference between original Image and Wanted size (~16GB)"
#         WANTEDSIZE="15872000000"
#         FILESIZE=$(stat -c%s "IMAGE.img")
#         DIFFERENCE=$(expr $WANTEDSIZE - $FILESIZE)
#         DIFFERENCE=$(expr $DIFFERENCE - 1)
# 	DIFFERENCE=$(expr $DIFFERENCE - 204800)
#     dd if=/dev/zero of=temp.img bs=1 count=1 seek=$DIFFERENCE

#     log "Enlarge the downloaded image"
#     cat temp.img >> IMAGE.img

#     log "fdisk to enlarge the main partition"
#     #calculating image offsets
#     PARTED_OUT=$(parted -s IMAGE.img unit s print)
#     ROOT_OFFSET=$(echo "$PARTED_OUT" | grep -e "^ ${ROOT_PART}"| xargs echo -n \
#         | cut -d" " -f 2 | tr -d s)
#     echo "ROOT OFFSET: $ROOT_OFFSET"
#     #Now we delete Partition 1, write a new partition 1 and write the calculated size to have a larger root-partition)
#     fdisk IMAGE.img <<EOF
# n
# 15
# 30588367
# 30793166
# t
# 15
# 11
# w
# EOF
# echo "created conf partition"

# fdisk IMAGE.img <<EOF
# d
# 1
# n
# 1
# 28672
# 30588366
# w
# EOF
# sgdisk -c 1:APP IMAGE.img #some jetson-scripts assume that the first partition (active partition with the root-filesystem), is called app, so we rename it

# rm temp.img
# rm conf.img

# # LOOPFILE=$(losetup --partscan --show --find IMAGE.img)
# # LOOPFILE=${LOOPFILE}p15
# # mkfs.vfat $LOOPFILE

# fi
return

popd