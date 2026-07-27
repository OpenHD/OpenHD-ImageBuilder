#!/bin/bash

set -e

packages=(
  unzip bzip2 p7zip-full curl git qemu-user-static binfmt-support
  build-essential dosfstools gdisk parted fdisk util-linux
)

apt-get update

# Ubuntu 24.04 no longer provides the qemu meta-package. It is not required
# when qemu-user-static is installed, but retain it on older hosts where it is
# available for compatibility with the other image targets.
qemu_candidate="$(apt-cache policy qemu 2>/dev/null | awk '/Candidate:/ {print $2}')"
if [[ -n "${qemu_candidate}" && "${qemu_candidate}" != "(none)" ]]; then
  packages+=(qemu)
fi

apt-get install -y "${packages[@]}"
#This file installs requied dependencies (extraction tools, emulation tools, build tools)
