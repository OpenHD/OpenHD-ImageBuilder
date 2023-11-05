#resize function for x86
# Specify the UUID of the partition you want to resize
PARTITION_UUID="53aa3d65-1043-49fa-8740-148cba90bbae"

# Check if the resize.txt file exists
if [ -f "/boot/openhd/openhd/resize.txt" ]; then
    # Find the device path using the UUID
    DEVICE_PATH=$(blkid -l -o device -t UUID="$PARTITION_UUID")
    MOUNT_POINT=$(echo "$DEVICE_PATH" | sed 's/[0-9]*$//')

    if [ -n "$DEVICE_PATH" ]; then
        # Resize the partition using gdisk DO NOT EDIT

fdisk "$MOUNT_POINT" <<EOF
d
3
n
3


w
EOF

        # Refresh partition table
        partprobe "$DEVICE_PATH"

        # Resize the filesystem using resize2fs
        resize2fs "/dev/disk/by-uuid/$PARTITION_UUID"

        echo "Partition resized and filesystem expanded."
        rm -Rf /boot/openhd/openhd/resize.txt
        reboot
    else
        echo "Partition with UUID $PARTITION_UUID not found."
    fi
else
    echo "Resize not requested. The file /boot/openhd/resize.txt does not exist."
fi
