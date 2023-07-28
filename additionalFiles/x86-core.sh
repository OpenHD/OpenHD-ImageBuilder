#!/bin/bash
# Service to control and setup X86 OpenHD Images

#resize on first boot
FILESYSTEM_UUID="YOUR_FILESYSTEM_UUID"
DEVICE_PATH=$(findfs UUID="$FILESYSTEM_UUID")

if [ -z "$DEVICE_PATH" ]; then
    echo "Filesystem with UUID $FILESYSTEM_UUID not found. Exiting..."
    exit 1
fi

# Extract the partition number from the device path (e.g., /dev/sda1 -> 1)
PARTITION_NUMBER=${DEVICE_PATH##*[!0-9]}

# Check if the script has been executed before
if [ ! -f /etc/resized_partition_flag ]; then
    # Resize the partition using parted
    parted "$DEVICE_PATH" resizepart "$PARTITION_NUMBER" 50%   # Adjust the size (50%) as needed
    touch /etc/resized_partition_flag
    echo "Partition resizing scheduled for the next boot."
    echo "Please reboot your system to apply the changes."
else
    echo "Partition has already been resized. Exiting..."
fi