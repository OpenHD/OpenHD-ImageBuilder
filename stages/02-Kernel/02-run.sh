set -e

# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Compile kernel For Pi 1, Pi Zero, Pi Zero W, or Compute Module"
pushd linux

log "Copy Kernel config"
cp "${STAGE_DIR}/FILES/.config_db_v6_kernel_4_14_66" ./.config

#KERNEL=kernel ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make bcmrpi_defconfig
KERNEL=kernel ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j $J_CORES zImage modules dtbs

log "Saving kernel as ${STAGE_WORK_DIR}/kernel1.img"
mv arch/arm/boot/zImage "${STAGE_WORK_DIR}/kernel1.img"

log "Copy the kernel modules For Pi 1, Pi Zero, Pi Zero W, or Compute Module"
MNT_DIR="${STAGE_WORK_DIR}/mnt"
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH="$MNT_DIR" modules_install

# out of linux 
popd

log "Copy the DTBs For Pi 1, Pi Zero, Pi Zero W, or Compute Module"
sudo cp linux/arch/arm/boot/dts/*.dtb "${MNT_DIR}/boot/"
sudo cp linux/arch/arm/boot/dts/overlays/*.dtb* "${MNT_DIR}/boot/overlays/"
sudo cp linux/arch/arm/boot/dts/overlays/README "${MNT_DIR}/boot/overlays/"

#return 
popd
