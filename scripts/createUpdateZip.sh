#!/bin/bash

#This script updates the package lists and downloads the .deb files for packages that need to be updated. The downloaded .deb files are stored in the /opt/update folder, and the folder is zipped into a file named update.zip.


# The folder to store the .deb files
UPDATE_FOLDER="/opt/update"

# The name of the zip file
ZIP_FILE="$UPDATE_FOLDER/update.zip"

# Create the update folder, if it doesn't exist
if [ ! -d "$UPDATE_FOLDER" ]; then
  mkdir "$UPDATE_FOLDER"
fi

# Remove all existing .deb files in the update folder
rm "$UPDATE_FOLDER"/*.deb

# Update the package lists
apt update

# Download the .deb files for packages that need to be updated
for package in $(apt list --upgradable | awk '/\*/ {print $1}'); do
  apt download "$package" -o APT::Sandbox::User=root --yes
  mv *.deb "$UPDATE_FOLDER"
done

# Create the zip file
zip -r "$ZIP_FILE" "$UPDATE_FOLDER"