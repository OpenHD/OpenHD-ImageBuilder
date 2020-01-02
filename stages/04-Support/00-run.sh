# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

MNT_DIR="${STAGE_WORK_DIR}/mnt"

log "Removing old GIT dir"
rm -r GIT || true

mkdir -p GIT

pushd GIT

MNT_DIR="${STAGE_WORK_DIR}/mnt"

log "Installing Qt"

if [ ! -f Qt${QT_MAJOR_VERSION}.${QT_MINOR_VERSION}.tar.gz ]; then
	log "Download Qt ${QT_MAJOR_VERSION}.${QT_MINOR_VERSION}"
	wget https://github.com/infincia/qt-raspberrypi/releases/download/${QT_MAJOR_VERSION}.${QT_MINOR_VERSION}/Qt${QT_MAJOR_VERSION}.${QT_MINOR_VERSION}.tar.gz || exit 1
fi

tar xvf Qt${QT_MAJOR_VERSION}.${QT_MINOR_VERSION}.tar.gz || exit 1

mv Qt${QT_MAJOR_VERSION}.${QT_MINOR_VERSION} ${MNT_DIR}/opt/ || exit 1

rm -f Qt${QT_MAJOR_VERSION}.${QT_MINOR_VERSION}.tar.gz

log "Download LiFePO4wered-pi"
git clone -b ${LIFEPOWEREDPI_BRANCH} ${LIFEPOWEREDPI_REPO} || exit 1

log "Download Raspi2png"
git clone -b ${RASPI2PNG_BRANCH} ${RASPI2PNG_REPO} || exit 1

log "Download Mavlink router"
sudo git clone -b ${MAVLINK_ROUTER_BRANCH} ${MAVLINK_ROUTER_REPO} || exit 1
pushd mavlink-router
sudo git submodule update --init || exit 1

#fix missing pymavlink
pushd modules/mavlink
sudo git clone --recurse-submodules -b ${PYMAVLINK_BRANCH} ${PYMAVLINK_REPO} || exit 1
popd

popd

log "Download cmavnode"
sudo git clone -b ${CMAVNODE_BRANCH} ${CMAVNODE_REPO} || exit 1
pushd cmavnode
sudo git submodule update --init || exit 1
popd

#return
popd

