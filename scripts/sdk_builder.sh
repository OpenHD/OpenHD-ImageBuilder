#!/usr/bin/env bash

################################################################################
# OpenHD
# 
# Licensed under the GNU General Public License (GPL) Version 3.
# 
# This software is provided "as-is," without warranty of any kind, express or 
# implied, including but not limited to the warranties of merchantability, 
# fitness for a particular purpose, and non-infringement. For details, see the 
# full license in the LICENSE file provided with this source code.
# 
# Non-Military Use Only:
# This software and its associated components are explicitly intended for 
# civilian and non-military purposes. Use in any military or defense 
# applications is strictly prohibited unless explicitly and individually 
# licensed otherwise by the OpenHD Team.
# 
# Contributors:
# A full list of contributors can be found at the OpenHD GitHub repository:
# https://github.com/OpenHD
# 
# © OpenHD, All Rights Reserved.
################################################################################

#
# Usage:
#   ./sdk_builder.sh                -> lists available platforms, prompts for choice, then builds
#   ./sdk_builder.sh <PLATFORM>     -> directly loads /images/br_<PLATFORM>.conf and builds
#
# The config file /images/br_<PLATFORM>.conf should define environment variables like:
#   DOWNLOAD_URL="..."
#   BUILDROOT_VERSION="..."
#   PLATFORM_DEFCONFIG="..."
#   KERNEL_REPO_URL="..."
#   KERNEL_BRANCH="..."
#   ... (any other custom variables you need)
#
# Then inside the script, we source those variables and run the build steps.
# ---------------------------------------------------------------------------

CONFIG_DIR="images"

###############################################################################
# 1) Helper function: list available config files
###############################################################################
list_platforms() {
  echo "Scanning for available platform config files in: $CONFIG_DIR"
  echo "------------------------------------------------------------"
  # List all files matching br_*.conf
  local files=("$CONFIG_DIR"/br/*.conf)
  
  if [ -f "${files[0]}" ]; then
    for f in "${files[@]}"; do
      platform_name="$(basename "$f" .conf | cut -d'_' -f2- )"
      echo "- $platform_name"
    done
  else
    echo "No config files found (br_*.conf) in $CONFIG_DIR."
  fi
  echo
}

###############################################################################
# 2) Helper function: source a specific PLATFORM config & show settings
###############################################################################
load_config() {
  local platform="$1"
  local config_file="${CONFIG_DIR}/br/${platform}"

  if [[ ! -f "$config_file" ]]; then
    ls -a ${CONFIG_DIR}/br/
    echo "Error: Config file $config_file not found!"
    exit 1
  fi

  # Source the config file. 
  # It should define environment variables like DOWNLOAD_URL, BUILDROOT_VERSION, etc.
  echo "Loading config from: $config_file"
  # shellcheck disable=SC1090
  source "$config_file"

#   # Optional: Display the loaded environment variables
#   echo "------------------------------------------------------------"
#   echo "  PLATFORM:           $platform"
#   echo "  DOWNLOAD_URL:       ${DOWNLOAD_URL:-<not set>}"
#   echo "  BUILDROOT_VERSION:  ${BUILDROOT_VERSION:-<not set>}"
#   echo "  PLATFORM_DEFCONFIG: ${PLATFORM_DEFCONFIG:-<not set>}"
#   echo "  KERNEL_REPO_URL:    ${KERNEL_REPO_URL:-<not set>}"
#   echo "  KERNEL_BRANCH:      ${KERNEL_BRANCH:-<not set>}"
#   echo "  ... (and so on for other variables) ..."
#   echo "------------------------------------------------------------"
 }

###############################################################################
# 3) The actual build steps (you’ll adapt these to your setup)
###############################################################################
perform_build() {
  local platform="$1"

  echo "Starting build steps for: $platform"
  echo "------------------------------------------------------------"

    if [[ -n "${DOWNLOAD_URL}" && "${DOWNLOAD_URL}" != " " ]]; then
    echo "Downloading Buildroot from $DOWNLOAD_URL ..."
    wget -q "$DOWNLOAD_URL" -O buildroot.tar.gz
    tar -xf buildroot.tar.gz


    elif [[ -n "${GITHUB_URL}" && "${GITHUB_URL}" != " " ]]; then
    echo "Cloning Buildroot from GitHub: $GITHUB_URL ..."
    git clone "$GITHUB_URL" buildroot

    else
    echo "Error: Neither DOWNLOAD_URL nor GITHUB_URL is set! Cannot proceed."
    exit 1
    fi

  echo "Starting confiugation steps for: $platform"
  echo "------------------------------------------------------------"
 
    ./build.sh launch <<EOF
    $TYPE_1
    $TYPE_2
    $TYPE_2
    EOF

  echo "Build process for $platform completed (placeholder)."
  echo
}

###############################################################################
# 4) Main logic: parse argument, or list and prompt if none
###############################################################################
if [[ -z "$1" ]]; then
  # No platform given. List available ones and let user choose:
  list_platforms

  read -rp "Enter a platform name to build (or press Ctrl+C to exit): " chosen_platform
  if [[ -z "$chosen_platform" ]]; then
    echo "No platform selected; exiting."
    exit 1
  fi
  # Now load config & build
  load_config "$chosen_platform"
  perform_build "$chosen_platform"

else
  # A specific platform was given as an argument
  platform="$1"
  load_config "$platform"
  perform_build "$platform"
fi
