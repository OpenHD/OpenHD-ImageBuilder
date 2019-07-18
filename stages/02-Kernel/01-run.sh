# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}


# in Make file change CONFIG_PLATFORM_I386_PC = y -> n, CONFIG_PLATFORM_ARM_RPI = n -> y and TopDir

cd rtl8812au
sudo sed -i 's/CONFIG_PLATFORM_I386_PC = y/CONFIG_PLATFORM_I386_PC = n/' Makefile
sudo sed -i 's/CONFIG_PLATFORM_ARM_RPI = n/CONFIG_PLATFORM_ARM_RPI = y/' Makefile
# per justins request commented out
# sudo sed -i 's/CONFIG_USB2_EXTERNAL_POWER = n/CONFIG_USB2_EXTERNAL_POWER = y/' Makefile
sudo sed -i 's/export TopDIR ?= $(shell pwd)/export TopDIR2 ?= $(shell pwd)/' Makefile
sudo sed -i '/export TopDIR2 ?= $(shell pwd)/a export TopDIR := $(TopDIR2)/drivers/net/wireless/realtek/rtl8812au/' Makefile

# Change the STBC value to make all antennas send with awus036ACH

cd core
sudo sed -i 's/u8 fixed_rate = MGN_1M, sgi = 0, bwidth = 0, ldpc = 0, stbc = 0;/u8 fixed_rate = MGN_1M, sgi = 0, bwidth = 0, ldpc = 0, stbc = 1;/' rtw_xmit.c
cd ..

cd ..

log "Merge the RTL8812 driver into kernel"

cp -a rtl8812au/. linux/drivers/net/wireless/realtek/rtl8812au/

log "Copy v4l2loopback driver into kernel"
cp -a v4l2loopback/. linux/drivers/media/v4l2loopback/

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
