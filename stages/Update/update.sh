#!/bin/bash -e
# This script runs inside the OpenHD image when the builder is invoked with update=true.
# Customize it with the commands that need to execute during the chroot update.

echo "Running OpenHD update stage..."
apt-get update
apt-get -y upgrade
