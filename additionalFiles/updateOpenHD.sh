#!/bin/bash

#dirty hack to rotate steamdeck
if grep -q "AMD Custom APU 0405" /proc/cpuinfo; then
    echo "Running on a Steam Deck."
else
    echo "Not running on a Steam Deck."
fi

#resize function for x86

# Specify the UUID of the partition you want to resize
PARTITION_UUID="9266e0aa-591a-483d-97b3-def06fabc605"

# Check if the resize.txt file exists
if [ -f "/boot/openhd/resize.txt" ]; then
    # Find the device path using the UUID
    DEVICE_PATH=$(blkid -l -o device -t UUID="$PARTITION_UUID")

    if [ -n "$DEVICE_PATH" ]; then
        # Resize the partition using gdisk DO NOT EDIT

gdisk "$DEVICE_PATH" <<EOF
p
x
e
$PARTITION_UUID
l
c
$PARTITION_UUID
w
Y
EOF

gdisk "$DEVICE_PATH" <<EOF
p
EOF
        # # Refresh partition table
        # partprobe "$DEVICE_PATH"

        # # Resize the filesystem using resize2fs
        # resize2fs "/dev/disk/by-uuid/$PARTITION_UUID"

        # echo "Partition resized and filesystem expanded."
        rm -Rf /boot/openhd/resize.txt
    else
        echo "Partition with UUID $PARTITION_UUID not found."
    fi
else
    echo "Resize not requested. The file /boot/openhd/resize.txt does not exist."
fi


# The folder to look for .deb files
UPDATE_FOLDER="/boot/openhd/update"
TEMP_FOLDER="/tmp/updateOpenHD"

# The log file
LOG_FILE="/boot/openhd/install-log.txt"
mkdir -p $TEMP_FOLDER

# Check if the update folder exists
if [ ! -d "$UPDATE_FOLDER" ]; then
  echo "Error: $UPDATE_FOLDER does not exist"
  exit 0
fi

UPDATE_ZIP="$UPDATE_FOLDER/update.zip"
if [ -f "$UPDATE_ZIP" ]; then
  unzip "$UPDATE_ZIP" -d "$TEMP_FOLDER"
  rm "$UPDATE_ZIP"
fi

# Clear the log file
echo "" > "$LOG_FILE"

# Install each .deb file in the update folder
for deb_file in "$TEMP_FOLDER"/*.deb; do
  # Skip if the file is not a .deb file
  if [ ! -f "$deb_file" ]; then
    continue
  fi

  # Install the .deb files

  echo "Installing $deb_file"
  dpkg -i --force-overwrite "$deb_file" >> "$LOG_FILE" 2>&1
  if [ $? -eq 0 ]; then
    echo "Success: $deb_file installed successfully" >> "$LOG_FILE"
  else
    echo "Failure: Failed to install $deb_file" >> "$LOG_FILE"
    all_successful=false
  fi
done


if $all_successful; then
  echo "All .deb files were installed successfully, rebooting the system"
  # remove the update folder
  rm -rf "$UPDATE_FOLDER"
  rm -rf "$TEMP_FOLDER"
  sudo reboot
else
  wall The update has failed, please do a manual flash
fi
