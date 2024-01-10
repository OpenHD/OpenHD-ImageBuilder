#resize function

# Specify the UUID of the partition you want to resize
PARTITION_UUID=$1
PARTNR=$2

# Check if the resize.txt file exists
if [ -f "/boot/openhd/openhd/resize.txt" ] || [ -f "/boot/openhd/resize.txt" ]; then
    # Find the device path using the UUID
    DEVICE_PATH=$(blkid -l -o device -t UUID="$PARTITION_UUID")
    MOUNT_POINT=$(echo "$DEVICE_PATH" | sed 's/[0-9]*$//')

    if [ -n "$DEVICE_PATH" ]; then
        # Resize the partition using gdisk DO NOT EDIT

fdisk "$MOUNT_POINT" <<EOF
d
$PARTNR
n
$PARTNR


w
EOF

        # Refresh partition table
        partprobe "$DEVICE_PATH"

        # Resize the filesystem using resize2fs
        resize2fs "/dev/disk/by-uuid/$PARTITION_UUID"

        echo "Partition resized and filesystem expanded."
        if [ -f "/boot/openhd/openhd/resize.txt" ]; then
        rm -Rf /boot/openhd/openhd/resize.txt
        if [ -f "/boot/openhd/resize.txt" ]; then
        rm -Rf /boot/openhd/resize.txt
        reboot
    else
        echo "Partition with UUID $PARTITION_UUID not found."
    fi
else
    echo "Resize not requested. The file /boot/openhd/resize.txt does not exist."
fi
