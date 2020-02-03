log "Checking prerequisites"

if [ ! -d ~/tools ]; then
    log "Download the Raspberry Pi Tools"
    git clone --depth=1 -b ${PI_TOOLS_BRANCH} ${PI_TOOLS_REPO} ~/tools
    log "Install the Raspberry Pi Tools"
    echo PATH=\$PATH:~/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian/bin >> ~/.bashrc
    source ~/.bashrc
fi

