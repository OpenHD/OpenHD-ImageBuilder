set -e

# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}
MNT_DIR="${STAGE_WORK_DIR}/mnt"

log "Compile kernel for Pi 2, Pi 3, Pi 3+, or Compute Module 3/3+"
pushd ${LINUX_DIR}

log "Copy Kernel config"
cp "${STAGE_DIR}/FILES/.config-${KERNEL_BRANCH}-v7" ./.config


make clean

#KERNEL=kernel7 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make bcm2709_defconfig
yes "" | KERNEL=kernel7 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j $J_CORES zImage modules dtbs

log "Saving kernel as ${STAGE_WORK_DIR}/kernel7.img"
cp arch/arm/boot/zImage "${MNT_DIR}/boot/kernel7.img"

log "Copy the kernel modules for Pi 2, Pi 3, Pi 3+, or Compute Module 3/3+"
make -j $J_CORES ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH="$MNT_DIR" modules_install

log "Copy the DTBs for Pi 2, Pi 3, Pi 3+, or Compute Module 3/3+"
sudo cp arch/arm/boot/dts/*.dtb "${MNT_DIR}/boot/"
sudo cp arch/arm/boot/dts/overlays/*.dtb* "${MNT_DIR}/boot/overlays/"
sudo cp arch/arm/boot/dts/overlays/README "${MNT_DIR}/boot/overlays/"

# out of linux 
popd

#return 
popd
