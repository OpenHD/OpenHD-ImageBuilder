#!/bin/bash

# Update the package list for the specified repository
sudo apt-get update

# Directory to save downloaded packages
DOWNLOAD_DIR="./radxa-rockchip-packages"
mkdir -p "$DOWNLOAD_DIR"

# Path to the repository list file
REPO_LIST="/etc/apt/sources.list.d/radxa-rockchip.list"

# Extract the repository URL from the list file
REPO_URL=$(grep -Eo 'http[s]?://[^ ]+' "$REPO_LIST")

# List all available packages in the repository
PACKAGES=$(apt-cache dumpavail | grep -A 1 -B 10 "$REPO_URL" | grep 'Package: ' | awk '{print $2}')

# Download each package compatible with the system
for PACKAGE in $PACKAGES; do
    echo "Downloading $PACKAGE..."
    apt-get download "$PACKAGE" -o=dir::cache="$DOWNLOAD_DIR" || {
        echo "Failed to download $PACKAGE"
    }
done

echo "All compatible packages have been downloaded to $DOWNLOAD_DIR"
