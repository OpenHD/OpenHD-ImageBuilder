#!/bin/bash -e
# shellcheck disable=SC2119,SC1091

if [ -f config ]; then
    source config
fi

IMAGE_ARCH=$1
DISTRO=$2

# print a simple line across the entire width of the terminal like '------------'
line (){
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

echo ""
n=" ██████╗ ██████╗ ███████╗███╗   ██╗   ██╗  ██╗██████╗     ██╗███╗   ███╗ █████╗  ██████╗ ███████╗    ██████╗ ██╗   ██╗██╗██╗     ██████╗ ███████╗██████╗ " && echo "${n::${COLUMNS:-$(tput cols)}}" # some magic to cut the end on smaller terminals
n="██╔═══██╗██╔══██╗██╔════╝████╗  ██║   ██║  ██║██╔══██╗    ██║████╗ ████║██╔══██╗██╔════╝ ██╔════╝    ██╔══██╗██║   ██║██║██║     ██╔══██╗██╔════╝██╔══██╗" && echo "${n::${COLUMNS:-$(tput cols)}}"
n="██║   ██║██████╔╝█████╗  ██╔██╗ ██║   ███████║██║  ██║    ██║██╔████╔██║███████║██║  ███╗█████╗      ██████╔╝██║   ██║██║██║     ██║  ██║█████╗  ██████╔╝" && echo "${n::${COLUMNS:-$(tput cols)}}"
n="██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║   ██╔══██║██║  ██║    ██║██║╚██╔╝██║██╔══██║██║   ██║██╔══╝      ██╔══██╗██║   ██║██║██║     ██║  ██║██╔══╝  ██╔══██╗" && echo "${n::${COLUMNS:-$(tput cols)}}"
n="╚██████╔╝██║     ███████╗██║ ╚████║██╗██║  ██║██████╔╝    ██║██║ ╚═╝ ██║██║  ██║╚██████╔╝███████╗    ██████╔╝╚██████╔╝██║███████╗██████╔╝███████╗██║  ██║" && echo "${n::${COLUMNS:-$(tput cols)}}"
n=" ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═════╝     ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝    ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝" && echo "${n::${COLUMNS:-$(tput cols)}}"
echo ""
line
echo ""


if [[ "${IMAGE_ARCH}" == "" || ${DISTRO} == "" ]]; then
    IMAGE_ARCH="pi"
    DISTRO="stretch"

    echo "Usage: ./build.sh pi [stretch | buster]"
    echo ""
    echo "Options:"
    echo ""
    echo "                  pi stretch: standard image, supports Pi Zero, Pi 2, Pi 3, CM3"
    echo ""
    echo "                   pi buster: testing image, for Pi Compute Module 3+ and Pi 4"
    echo ""
    echo ""
    line
    echo ""
fi


if [[ "$IMAGE_ARCH" == "pi" && "${DISTRO}" == "stretch" ]]; then
    echo "Building pi stretch image"

    BASE_IMAGE_URL=${PI_STRETCH_BASE_IMAGE_URL}
    BASE_IMAGE=${PI_STRETCH_BASE_IMAGE}
fi


if [[ "$IMAGE_ARCH" == "pi" && "${DISTRO}" == "buster" ]]; then
    echo "Building pi buster image"

    BASE_IMAGE_URL=${PI_BUSTER_BASE_IMAGE_URL}
    BASE_IMAGE=${PI_BUSTER_BASE_IMAGE}
fi

echo ""
line


run_stage(){
    STAGE="$(basename "${STAGE_DIR}")"
    STAGE_WORK_DIR="${WORK_DIR}/${STAGE}"

    log ""
    log ""
    log "======================================================"
    log "Begin ${STAGE_WORK_DIR}"
    pushd "${STAGE_DIR}" > /dev/null

    # Create the Work folder
    mkdir -p "${STAGE_WORK_DIR}"

    # Check wether to skip or not
    if [ ! -f "${STAGE_WORK_DIR}/SKIP" ]; then
        # mount the image for this stage
        if [ ! -f "${STAGE_WORK_DIR}/SKIP_IMAGE" ]; then
            # Copy the image from the previous stage
            if [ -f "${PREV_WORK_DIR}/IMAGE.img" ]; then
                unmount_image
                cp "${PREV_WORK_DIR}/IMAGE.img" "${STAGE_WORK_DIR}/IMAGE.img"
                mount_image
            else
                log "[ERROR] No image to copy in ${PREV_WORK_DIR}/"
            fi
        fi

        # iterate different files
        for i in {00..99}; do

            if [ -x ${i}-run.sh ]; then
                log "Begin ${STAGE_DIR}/${i}-run.sh"
                ./${i}-run.sh
                log "End ${STAGE_DIR}/${i}-run.sh"
            fi

            if [ -f ${i}-run-chroot.sh ]; then
                log "Begin ${STAGE_DIR}/${i}-run-chroot.sh"
                on_chroot < ${i}-run-chroot.sh
                log "End ${STAGE_DIR}/${i}-run-chroot.sh"
            fi

        done
    fi

    # SKIP this stage next time
    touch "${STAGE_WORK_DIR}/SKIP"

    PREV_STAGE="${STAGE}"
    PREV_STAGE_DIR="${STAGE_DIR}"
    PREV_WORK_DIR="${WORK_DIR}/${STAGE}"

    if [ ! -f "${STAGE_WORK_DIR}/SKIP_IMAGE" ]; then
        unmount_image
    fi

    popd > /dev/null
    log "End ${STAGE_WORK_DIR}"
}

if [ "$(id -u)" != "0" ]; then
    echo "Please run as root" 1>&2
    exit 1
fi



if [ -z "${IMG_NAME}" ]; then
    echo "IMG_NAME not set" 1>&2
    exit 1
fi

# Variables
export IMG_DATE="${IMG_DATE:-"$(date +%Y-%m-%d)"}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR="${BASE_DIR}/scripts"
export WORK_DIR="${BASE_DIR}/work-${IMAGE_ARCH}-${DISTRO}"
export DEPLOY_DIR=${DEPLOY_DIR:-"${BASE_DIR}/deploy"}
export LOG_FILE="${WORK_DIR}/build.log"

mkdir -p "${WORK_DIR}"

export BASE_DIR

export IMAGE_ARCH
export DISTRO
export BASE_IMAGE_URL
export BASE_IMAGE

export CLEAN
export IMG_NAME
export BASE_IMAGE_URL
export BASE_IMAGE

export APT_CACHER_NG_URL
export APT_CACHER_NG_ENABLED

export STAGE
export STAGE_DIR
export STAGE_WORK_DIR
export PREV_STAGE
export PREV_STAGE_DIR
export PREV_WORK_DIR
export ROOTFS_DIR
export PREV_ROOTFS_DIR
export IMG_SUFFIX

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

log "IMG ${BASE_IMAGE}"
log "Begin ${BASE_DIR}"

# Iterate trough the steps
find ./stages -name '*.sh' -type f | xargs chmod 775
for STAGE_DIR in "${BASE_DIR}/stages/"*; do
    if [ -d "${STAGE_DIR}" ]; then
        run_stage
    fi
done

# rename the image according to the build date, the builder/openhd repo versions
OPENHD_VERSION=$(cat ${WORK_DIR}/openhd_version.txt)
if [ -f "${PREV_WORK_DIR}/IMAGE.img" ]; then
    mkdir -p "${DEPLOY_DIR}" || true
    cp "${PREV_WORK_DIR}/IMAGE.img" "${DEPLOY_DIR}/${IMG_NAME}-${OPENHD_VERSION}-${DISTRO}.img"
fi

cd ${BASE_DIR}

log "End ${BASE_DIR}"
