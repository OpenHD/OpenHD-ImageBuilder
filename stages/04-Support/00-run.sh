# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Removing old GIT dir"
rm -r GIT || true

mkdir -p GIT

pushd GIT

MNT_DIR="${STAGE_WORK_DIR}/mnt"

log "Download Raspi2png"
git clone https://github.com/AndrewFromMelbourne/raspi2png.git

log "Download v4l2loopback"
sudo git clone https://github.com/umlaeute/v4l2loopback.git

log "Download Mavlink router"
sudo git clone -b rock64 https://github.com/user1321/mavlink-router.git
pushd mavlink-router
sudo git submodule update --init

#fix missing pymavlink
pushd modules/mavlink
sudo git clone --recurse-submodules https://github.com/user1321/pymavlink

popd

log "Download cmavnode"
sudo git clone https://github.com/MonashUAS/cmavnode.git
pushd cmavnode
sudo git submodule update --init
popd

#return
popd

