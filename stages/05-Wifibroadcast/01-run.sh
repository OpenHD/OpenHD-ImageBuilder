# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

log "Removing old GIT dir"
rm -r GIT || true

mkdir -p GIT

pushd GIT

MNT_DIR="${STAGE_WORK_DIR}/mnt"

log "Download all Open.HD Sources"
sudo git clone -b master https://github.com/HD-Fpv/Open.HD.git
pushd Open.HD
sudo git submodule update --init
popd

log "Download OpenVG"
sudo mv Open.HD/openvg/ openvg/

log "Download EZWFB - Base"
# sudo git clone https://github.com/user1321/wifibroadcast-base.git
sudo mv Open.HD/wifibroadcast-base/ wifibroadcast-base/
sudo cp -r Open.HD/mavlink/ wifibroadcast-base/mavlink/

log "Download EZWFB - OSD"
# sudo git clone https://github.com/user1321/wifibroadcast-osd-orig wifibroadcast-osd
sudo mv Open.HD/wifibroadcast-osd/ wifibroadcast-osd/
sudo cp -r Open.HD/mavlink/ wifibroadcast-osd/mavlink/

log "Download EZWFB - RC"
# sudo git clone https://github.com/user1321/wifibroadcast-rc-orig.git wifibroadcast-rc
sudo mv Open.HD/wifibroadcast-rc/ wifibroadcast-rc/
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
sudo git clone https://github.com/HD-Fpv/Open.HD_FlirOneDrv.git

log "Download RemoteSettings"
# sudo git clone -b user1321-5MhzAth9k https://github.com/user1321/RemoteSettings
sudo mv Open.HD/RemoteSettings/ RemoteSettings/

log "Download cameracontrol"
# sudo git clone https://github.com/user1321/cameracontrol
sudo mv Open.HD/cameracontrol/ cameracontrol/

log "Download rc-encrypted"
# sudo git clone https://github.com/user1321/wifibroadcast-rc-encrypted
sudo mv Open.HD/wifibroadcast-rc-encrypted/ wifibroadcast-rc-encrypted/

log "Download JoystickIn"
# sudo git clone https://github.com/user1321/JoystickIn
sudo mv Open.HD/JoystickIn/ JoystickIn/

log "Download IMX290"
sudo mv Open.HD/raspberrypi/ raspberrypi/

log "Download UDPSplitter"
sudo mv Open.HD/UDPSplitter/ UDPSplitter/


sudo rm -rf Open.HD

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
