# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Removing old GIT dir"
rm -r GIT || true

mkdir -p GIT

pushd GIT

MNT_DIR="${STAGE_WORK_DIR}/mnt"

log "Download Raspi2png"
git clone -b ${RASPI2PNG_BRANCH} ${RASPI2PNG_REPO}

log "Download Mavlink router"
sudo git clone -b ${MAVLINK_ROUTER_BRANCH} ${MAVLINK_ROUTER_REPO}
pushd mavlink-router
sudo git submodule update --init

#fix missing pymavlink
pushd modules/mavlink
sudo git clone --recurse-submodules -b ${PYMAVLINK_BRANCH} ${PYMAVLINK_REPO}
popd

popd

log "Download cmavnode"
sudo git clone -b ${CMAVNODE_BRANCH} ${CMAVNODE_REPO}
pushd cmavnode
sudo git submodule update --init
popd

#return
popd

