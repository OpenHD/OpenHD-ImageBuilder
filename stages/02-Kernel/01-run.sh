# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}


# in Make file change CONFIG_PLATFORM_I386_PC = y -> n, CONFIG_PLATFORM_ARM_RPI = n -> y and TopDir

cd rtl8812au
sudo sed -i 's/CONFIG_PLATFORM_I386_PC = y/CONFIG_PLATFORM_I386_PC = n/' Makefile
sudo sed -i 's/CONFIG_PLATFORM_ARM_RPI = n/CONFIG_PLATFORM_ARM_RPI = y/' Makefile
sudo sed -i 's/export TopDIR ?= $(shell pwd)/export TopDIR2 ?= $(shell pwd)/' Makefile
sudo sed -i '/export TopDIR2 ?= $(shell pwd)/a export TopDIR := $(TopDIR2)/drivers/net/wireless/realtek/rtl8812au/' Makefile

cd ..

log "Merge the RTL8812 driver into kernel"

cp -a rtl8812au/. linux/drivers/net/wireless/realtek/rtl8812au/

log "Patch the Kernel"
pushd linux

for PATCH_FILE in "${STAGE_DIR}/PATCHES/"*; do
    log "Applying patch ${PATCH_FILE}"
    patch -N -p0 < $PATCH_FILE
done

# out of linux 
popd

#return 
popd
