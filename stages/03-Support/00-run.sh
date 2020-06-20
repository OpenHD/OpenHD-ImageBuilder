# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

MNT_DIR="${STAGE_WORK_DIR}/mnt"

log "Removing old GIT dir"
rm -r GIT || true

mkdir -p GIT

pushd GIT

log "Download Mavlink library"
sudo git clone --depth=1 -b ${MAVLINK_BRANCH} ${MAVLINK_REPO} || exit 1
pushd mavlink
sudo git submodule update --init --recursive  || exit 1
popd

log "Download VEYE support library"
sudo git clone --depth=1 -b ${VEYE_BRANCH} ${VEYE_REPO} || exit 1

#return
popd

