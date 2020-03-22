# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Install QEMU"

MNT_DIR="${STAGE_WORK_DIR}/mnt"
sudo cp /usr/bin/qemu-arm-static "${MNT_DIR}/usr/bin"

log "Clear the preload file"
sudo cp "${MNT_DIR}/etc/ld.so.preload" "${MNT_DIR}/root"
sudo cp /dev/null "${MNT_DIR}/etc/ld.so.preload"

log "Change the /etc/network/interfaces file so that wpa_suppl does not mess around"
sudo bash -c "echo -e \"auto lo\niface lo inet loopback\nauto eth0\nallow-hotplug eth0\niface eth0 inet manual\niface wlan0 inet manual\niface wlan1 inet manual\niface wlan2 inet manual\" > \"${MNT_DIR}/etc/network/interfaces\""

#return
popd
