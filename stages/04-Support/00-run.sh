# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

MNT_DIR="${STAGE_WORK_DIR}/mnt"

log "Removing old GIT dir"
rm -r GIT || true

mkdir -p GIT

pushd GIT

log "Installing Qt"

if [ ! -f Qt${QT_VERSION}-${QT_MINOR_RELEASE}-${DISTRO}.tar.gz ]; then
	log "Download Qt ${QT_VERSION} for ${DISTRO} on ${IMAGE_ARCH}"
	wget https://github.com/OpenHD/qt-raspberrypi/releases/download/${QT_VERSION}-${QT_MINOR_RELEASE}/Qt${QT_VERSION}-${QT_MINOR_RELEASE}-${DISTRO}.tar.gz || exit 1
fi

tar xvf Qt${QT_VERSION}-${QT_MINOR_RELEASE}-${DISTRO}.tar.gz || exit 1

rm -rf ${MNT_DIR}/opt/Qt* || true

mv Qt${QT_VERSION} ${MNT_DIR}/opt/ || exit 1

rm -f Qt${QT_VERSION}-${QT_MINOR_RELEASE}-${DISTRO}.tar.gz

log "Download LiFePO4wered-pi"
git clone --depth=1 -b ${LIFEPOWEREDPI_BRANCH} ${LIFEPOWEREDPI_REPO} || exit 1

log "Download OpenHDMicroservice"
git clone --depth=1 -b ${OPENHDMICROSERVICE_BRANCH} ${OPENHDMICROSERVICE_REPO} || exit 1

log "Download OpenHDRouter"
git clone --depth=1 -b ${OPENHDROUTER_BRANCH} ${OPENHDROUTER_REPO} || exit 1

log "Download Raspi2png"
git clone --depth=1 -b ${RASPI2PNG_BRANCH} ${RASPI2PNG_REPO} || exit 1

log "Download Mavlink router"
sudo git clone --depth=1 -b ${MAVLINK_ROUTER_BRANCH} ${MAVLINK_ROUTER_REPO} || exit 1
pushd mavlink-router
sudo git submodule update --init --recursive  || exit 1
popd

log "Download Mavlink library"
sudo git clone --depth=1 -b ${MAVLINK_BRANCH} ${MAVLINK_REPO} || exit 1
pushd mavlink
sudo git submodule update --init --recursive  || exit 1
popd


#return
popd

