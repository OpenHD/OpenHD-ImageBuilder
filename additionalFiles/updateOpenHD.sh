#!/bin/bash

# The folder to look for .deb files
UPDATE_FOLDER="/boot/openhd/update"
TEMP_FOLDER="/tmp/updateOpenHD"

# The log file
LOG_FILE="/boot/openhd/install-log.txt"
mkdir -p $TEMP_FOLDER

#Moving temp-config to config partition
if [ ! -d "/boot/openhd1" ]; then
  echo "moving config folder"
  sudo mv /boot/openhd1/* /boot/openhd/
fi

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

# remove the update folder
rm -rf "$UPDATE_FOLDER"
rm -rf "$TEMP_FOLDER"

if $all_successful; then
  echo "All .deb files were installed successfully, rebooting the system"
  reboot
fi
