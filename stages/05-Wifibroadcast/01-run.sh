# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Removing old GIT dir"
rm -r GIT || true

mkdir -p GIT

pushd GIT

MNT_DIR="${STAGE_WORK_DIR}/mnt"

log "Download all Open.HD Sources REPO=${OPENHD_REPO} BRANCH=${OPENHD_BRANCH}"
sudo git clone  --depth=1 -b ${OPENHD_BRANCH} ${OPENHD_REPO} || exit 1
pushd Open.HD
sudo git submodule update --init || exit 1
OPENHD_VERSION=$(git describe --always --tags)
export OPENHD_VERSION
popd

# store the commit used for the Open.HD repo as we as the builder inside the image
# to allow tracing problems and changes back to the source, even if the image is renamed
echo ${OPENHD_VERSION} > ${MNT_DIR}/openhd_version.txt
echo ${BUILDER_VERSION} > ${MNT_DIR}/builder_version.txt
# copy the Open.HD repo version back down to the work folder so build.sh can retrieve it and use it
# in the name of the image being built
cp ${MNT_DIR}/openhd_version.txt ${STAGE_WORK_DIR}/../

log "Download OpenVG"
sudo mv Open.HD/openvg/ openvg/

log "Download EZWFB - Base"
# sudo git clone https://github.com/user1321/wifibroadcast-base.git
sudo mv Open.HD/wifibroadcast-base/ wifibroadcast-base/

log "Download EZWFB - OSD"
# sudo git clone https://github.com/user1321/wifibroadcast-osd-orig wifibroadcast-osd
sudo mv Open.HD/wifibroadcast-osd/ wifibroadcast-osd/

log "Download EZWFB - RC"
# sudo git clone -b user1321-5MHzAth9k https://github.com/user1321/wifibroadcast-rc-orig.git wifibroadcast-rc-Ath9k
sudo mv Open.HD/wifibroadcast-rc-Ath9k/ wifibroadcast-rc-Ath9k/

log "Download EZWFB - Status"
# sudo git clone https://github.com/RespawnDespair/wifibroadcast-status.git
sudo mv Open.HD/wifibroadcast-status/ wifibroadcast-status/

log "Download EZWFB - Scripts"
# sudo git clone -b user1321-5MhzAth9k https://github.com/user1321/wifibroadcast-scripts.git
sudo mv Open.HD/wifibroadcast-scripts/ wifibroadcast-scripts/

log "Download EZWFB - Misc"
# sudo git clone https://github.com/RespawnDespair/wifibroadcast-misc.git
sudo mv Open.HD/wifibroadcast-misc/ wifibroadcast-misc/

log "Download EZWFB - hello_video"
# sudo git clone https://github.com/RespawnDespair/wifibroadcast-hello_video.git
sudo mv Open.HD/wifibroadcast-hello_video/ wifibroadcast-hello_video/

log "Download EZWFB - Splash"
# sudo git clone https://github.com/RespawnDespair/wifibroadcast-splash.git
sudo mv Open.HD/wifibroadcast-splash/ wifibroadcast-splash/

log "Download FLIR one"
sudo git clone --depth=1 -b ${OPENHD_FLIRONE_DRIVER_BRANCH} ${OPENHD_FLIRONE_DRIVER_REPO}

log "Download RemoteSettings"
# sudo git clone -b user1321-5MhzAth9k https://github.com/user1321/RemoteSettings
sudo mv Open.HD/RemoteSettings/ RemoteSettings/

log "Download cameracontrol"
# sudo git clone https://github.com/user1321/cameracontrol
sudo mv Open.HD/cameracontrol/ cameracontrol/

log "Download JoystickIn"
# sudo git clone https://github.com/user1321/JoystickIn
sudo mv Open.HD/JoystickIn/ JoystickIn/

sudo mkdir -p ${MNT_DIR}/usr/local/bin || exit 1
sudo mv Open.HD/openhd-camera/openhdvid ${MNT_DIR}/usr/local/bin/ || exit 1
sudo chmod +x ${MNT_DIR}/usr/local/bin/openhdvid || exit 1


log "Download IMX290"
sudo mv Open.HD/raspberrypi/ raspberrypi/

log "Download UDPSplitter"
sudo mv Open.HD/UDPSplitter/ UDPSplitter/


sudo rm -rf Open.HD


git clone --depth=1 -b ${QOPENHD_VERSION} ${QOPENHD_REPO} || exit 1
cd QOpenHD
git submodule update --init --recursive || exit 1
echo ${OPENHD_VERSION} > .openhd_version
echo ${BUILDER_VERSION} > .builder_version
cd ..

#return
popd
popd


# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Copy all WFB Sources to RPi image"

MNT_DIR="${STAGE_WORK_DIR}/mnt"

cp -r GIT/. "$MNT_DIR/home/pi/"

#return
popd
