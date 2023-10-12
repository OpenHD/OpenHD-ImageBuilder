#!/bin/bash

#This script handles initial configuation, updates and misc features which aren't included in the main OpenHD executable (yet)

# print debug messages to the screen if debug is enabled
debug_file="/boot/openhd/debug.txt"
if [ -e "$debug_file" ]; then
    echo "debug mode selected"
    echo "sudo journalctl -f" >> /root/.bashrc
fi

#initialise x20 air-unit
if [ -f "/boot/openhd/hardware_vtx_v20.txt" ]; then
depmod -a
modprobe 88XXau_wfb
modprobe HdZero
fi

#camera Selector helper for the imagewriter
##rockship
if [ -f "/boot/openhd/rock-5a.txt" ]; then
  sudo bash /usr/local/bin/initRock.sh
  rm /boot/openhd/rock-5a.txt
  reboot
fi

if [ -f "/boot/openhd/rock-5b.txt" ]; then
  sudo bash /usr/local/bin/initRock.sh
  rm /boot/openhd/rock-5b.txt
  reboot
fi
##raspberry
if [ -f "/boot/openhd/rpi.txt" ]; then
  if [ -f "/boot/openhd/air.txt" ]; then
  sudo bash /usr/local/bin/initPi.sh
  rm /boot/openhd/rpi.txt
  reboot
  fi
fi

#dirty hack to rotate steamdeck
if grep -q "AMD Custom APU 0405" /proc/cpuinfo; then
    echo "Running on a Steam Deck."
else
    echo "Not running on a Steam Deck."
fi

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

##Update function for .zip update Files

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
