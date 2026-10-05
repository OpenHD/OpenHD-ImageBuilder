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
###############################################################################
$(info Building the OpenHD package...)

# The Git repository from which to clone the source code
OPENHD_SITE = https://github.com/openhd/OpenHD.git
OPENHD_SITE_METHOD = git
OPENHD_GIT_SUBMODULES = YES

# OpenHD 3.0 and its matching Devourer gitlink, kept together for reproducibility.
OPENHD_VERSION = 9d998bcc17fcfa07b38f3f1c8675eb4269347374
OPENHD_DEVOURER_VERSION = 46c3e7c48bbd663b329ec9d54667d5bab99a1836
OPENHD_EXTRA_DOWNLOADS = https://github.com/OpenHD/devourer/archive/$(OPENHD_DEVOURER_VERSION).tar.gz

# Enable Git submodules if the project requires them
OPENHD_GIT_SUBMODULES = YES

# Subdirectory inside the Git repo, if needed (if OpenHD is not in the root)
OPENHD_SUBDIR = OpenHD

# Install to both the staging directory and target, for linking and runtime
OPENHD_INSTALL_STAGING = YES
OPENHD_INSTALL_TARGET = YES

# List of dependencies that must be built before OpenHD
OPENHD_DEPENDENCIES = poco libsodium gstreamer1 gst1-plugins-base libpcap libusb host-pkgconf host-kmod

# Buildroot source archives have no .git directory. Download the pinned backend
# through its download cache and extract it without reference-driver submodules.
define OPENHD_EXTRACT_DEVOURER
	mkdir -p $(@D)/OpenHD/ohd_interface/lib/devourer
	$(TAR) -xzf $(OPENHD_DL_DIR)/$(OPENHD_DEVOURER_VERSION).tar.gz --strip-components=1 -C $(@D)/OpenHD/ohd_interface/lib/devourer
endef
OPENHD_POST_EXTRACT_HOOKS += OPENHD_EXTRACT_DEVOURER

define OPENHD_PREPARE_DEVOURER_ROOTFS
	grep -a -q 'Devourer identified' $(TARGET_DIR)/usr/bin/openhd
	PATH="$(BR_PATH)" bash $(OPENHD_PKGDIR)/prepare-devourer-image.sh $(TARGET_DIR)
endef
OPENHD_TARGET_FINALIZE_HOOKS += OPENHD_PREPARE_DEVOURER_ROOTFS

# Additional configuration options for the CMake build
OPENHD_CONF_OPTS = \
    -DENABLE_USB_CAMERAS=OFF \
    -DOPENHD_ENABLE_DEVOURER=ON \
    -DPCAP_NEEDS_THREADS=ON
	
# Use Buildroot's CMake package infrastructure to handle the build
$(eval $(cmake-package))

