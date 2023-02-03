#!/bin/bash

# The folder to look for .deb files
UPDATE_FOLDER="/boot/openhd/update"

# The log file
LOG_FILE="$UPDATE_FOLDER/boot/openhd/install-log.txt"

# Check if the update folder exists
if [ ! -d "$UPDATE_FOLDER" ]; then
  echo "Error: $UPDATE_FOLDER does not exist"
  exit 1
fi

UPDATE_ZIP="$UPDATE_FOLDER/update.zip"
if [ -f "$UPDATE_ZIP" ]; then
  unzip "$UPDATE_ZIP" -d "$UPDATE_FOLDER"
  rm "$UPDATE_ZIP"
fi

# Clear the log file
echo "" > "$LOG_FILE"

# Install each .deb file in the update folder
for deb_file in "$UPDATE_FOLDER"/*.deb; do
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

if $all_successful; then
  echo "All .deb files were installed successfully, rebooting the system"
  reboot
fi