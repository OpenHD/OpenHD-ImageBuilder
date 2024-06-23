#!/bin/bash

# Update the package list
sudo apt-get update

# Get all versions of the libc6 package
versions=$(apt-cache madison libc6 | awk '{print $3}')

# Create a directory to store the downloaded packages
mkdir -p libc6_packages
cd libc6_packages

# Loop through each version and download the package with dependencies
for version in $versions; do
    echo "Downloading libc6 version: $version"
    apt-get download libc6=$version

    # Get the dependencies for the specific version of libc6
    dependencies=$(apt-cache depends libc6=$version | grep "Depends:" | awk '{print $2}')

    # Download each dependency
    for dependency in $dependencies; do
        echo "Downloading dependency: $dependency"
        apt-get download $dependency
    done
done

echo "Download complete. All packages are stored in the libc6_packages directory."
