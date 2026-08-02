#!/bin/bash -e
# shellcheck disable=SC2119,SC1091

################################################################################
# OpenHD
# 
# Licensed under the GNU General Public License (GPL) Version 3.
# 
# This software is provided "as-is," without warranty of any kind, express or 
# implied, including but not limited to the warranties of merchantability, 
# fitness for a particular purpose, and non-infringement. For details, see the 
# full license in the LICENSE file provided with this source code.
# 
# Non-Military Use Only:
# This software and its associated components are explicitly intended for 
# civilian and non-military purposes. Use in any military or defense 
# applications is strictly prohibited unless explicitly and individually 
# licensed otherwise by the OpenHD Team.
# 
# Contributors:
# A full list of contributors can be found at the OpenHD GitHub repository:
# https://github.com/OpenHD
# 
# © OpenHD, All Rights Reserved.
################################################################################

if [ -f config ]; then
    source config
fi

IMAGE_TYPE=$1
TESTING=$2
SMALL=$3
UPDATE=$4

UPDATE_MODE="false"
if [[ "${UPDATE,,}" == "true" ]]; then
    UPDATE_MODE="true"
fi

# print a simple line across the entire width of the terminal like '------------'
terminal_width () {
    if [[ -n "${COLUMNS:-}" ]]; then
        echo "${COLUMNS}"
    elif command -v tput >/dev/null 2>&1 && tput cols >/dev/null 2>&1; then
        tput cols
    else
        echo 80
    fi
}

TERM_WIDTH="$(terminal_width)"

line (){
  printf '%*s\n' "${TERM_WIDTH}" '' | tr ' ' -
}

echo ""
n=" ██████╗ ██████╗ ███████╗███╗   ██╗   ██╗  ██╗██████╗     ██╗███╗   ███╗ █████╗  ██████╗ ███████╗    ██████╗ ██╗   ██╗██╗██╗     ██████╗ ███████╗██████╗ " && echo "${n::${TERM_WIDTH}}" # some magic to cut the end on smaller terminals
n="██╔═══██╗██╔══██╗██╔════╝████╗  ██║   ██║  ██║██╔══██╗    ██║████╗ ████║██╔══██╗██╔════╝ ██╔════╝    ██╔══██╗██║   ██║██║██║     ██╔══██╗██╔════╝██╔══██╗" && echo "${n::${TERM_WIDTH}}"
n="██║   ██║██████╔╝█████╗  ██╔██╗ ██║   ███████║██║  ██║    ██║██╔████╔██║███████║██║  ███╗█████╗      ██████╔╝██║   ██║██║██║     ██║  ██║█████╗  ██████╔╝" && echo "${n::${TERM_WIDTH}}"
n="██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║   ██╔══██║██║  ██║    ██║██║╚██╔╝██║██╔══██║██║   ██║██╔══╝      ██╔══██╗██║   ██║██║██║     ██║  ██║██╔══╝  ██╔══██╗" && echo "${n::${TERM_WIDTH}}"
n="╚██████╔╝██║     ███████╗██║ ╚████║██╗██║  ██║██████╔╝    ██║██║ ╚═╝ ██║██║  ██║╚██████╔╝███████╗    ██████╔╝╚██████╔╝██║███████╗██████╔╝███████╗██║  ██║" && echo "${n::${TERM_WIDTH}}"
n=" ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═════╝     ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝    ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝" && echo "${n::${TERM_WIDTH}}"
echo ""
line
echo ""


if [[ "${IMAGE_TYPE}" == "" ]]; then
    echo "Usage: ./build.sh pi-bullseye"
    echo ""
    echo "Target boards:"
    echo ""
    ls -1 images/
    line
    echo ""
    exit 1
fi

IMAGE_METADATA_FILE="./images/${IMAGE_TYPE}"
if [[ "${UPDATE_MODE}" == "true" ]]; then
    UPDATE_METADATA_FILE="./images/${IMAGE_TYPE}_base"
    if [[ -f "${UPDATE_METADATA_FILE}" ]]; then
        IMAGE_METADATA_FILE="${UPDATE_METADATA_FILE}"
    fi
fi

if [[ ! -f "${IMAGE_METADATA_FILE}" ]]; then
    echo "Invalid image type: ${IMAGE_TYPE}"
    exit 1
fi

source "${IMAGE_METADATA_FILE}"

# All standard architectures use the common OpenHD package identity. Camera
# and encoder backends remain board-specific GStreamer/runtime packages.
if [[ "${OPENHD_PACKAGE:-openhd}" == "openhd" ]]; then
    case "${OS}" in
        debian-X20)
            OPENHD_PACKAGE="openhd-x20"
            ;;
    esac
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
    echo "-------------------------------------------------------"
    echo "--------------check-------------size-------------------"
    df -h
    if [ ! -f "${STAGE_WORK_DIR}/SKIP" ]; then
        # mount the image for this stage
        if [ ! -f "${STAGE_WORK_DIR}/SKIP_IMAGE" ]; then
            # Copy the image from the previous stage
            if [ -f "${PREV_WORK_DIR}/IMAGE.img" ]; then
                unmount_image
                cp "${PREV_WORK_DIR}/IMAGE.img" "${STAGE_WORK_DIR}/IMAGE.img"
                mount_image
                if [[ "${SMALL}" == "small" ]]; then
                echo "deleteing last work dir...SMALL option"
                rm -r "${PREV_WORK_DIR}"
                fi
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

ensure_base_image_for_update(){
    local base_stage="01-Baseimage"
    local base_stage_dir="${BASE_DIR}/stages/${base_stage}"
    local base_stage_work_dir="${WORK_DIR}/${base_stage}"
    local base_stage_download_script="${base_stage_dir}/00-run.sh"
    local base_stage_prepare_script="${base_stage_dir}/01-run.sh"
    local base_stage_image="${base_stage_work_dir}/IMAGE.img"
    local base_stage_ready_marker="${base_stage_work_dir}/UPDATE_BASE_READY"

    if [[ -f "${base_stage_image}" && -f "${base_stage_ready_marker}" ]]; then
        log "Base image for update already present: ${base_stage_image}"
        return
    fi

    if [[ ! -f "${base_stage_download_script}" ]]; then
        echo "[ERROR] Missing ${base_stage_download_script} required for update workflow." >&2
        exit 1
    fi

    if [[ ! -f "${base_stage_prepare_script}" ]]; then
        echo "[ERROR] Missing ${base_stage_prepare_script} required for update workflow." >&2
        exit 1
    fi

    log "Preparing base image for update using ${base_stage}"

    local saved_stage="${STAGE}"
    local saved_stage_dir="${STAGE_DIR}"
    local saved_stage_work_dir="${STAGE_WORK_DIR}"

    mkdir -p "${base_stage_work_dir}"

    pushd "${base_stage_dir}" > /dev/null
    STAGE="${base_stage}"
    STAGE_DIR="${base_stage_dir}"
    STAGE_WORK_DIR="${base_stage_work_dir}"

    if [[ ! -f "${base_stage_image}" ]]; then
        chmod +x "${base_stage_download_script}"
        "${base_stage_download_script}"
    fi

    chmod +x "${base_stage_prepare_script}"
    "${base_stage_prepare_script}"
    touch "${base_stage_ready_marker}"

    popd > /dev/null

    STAGE="${saved_stage}"
    STAGE_DIR="${saved_stage_dir}"
    STAGE_WORK_DIR="${saved_stage_work_dir}"

    if [[ ! -f "${base_stage_image}" ]]; then
        echo "[ERROR] Unable to download base image for update workflow." >&2
        exit 1
    fi
}

prepare_update_image(){
    local target_image="${STAGE_WORK_DIR}/IMAGE.img"
    local source_image="${UPDATE_IMAGE:-}" # optional override from caller

    mkdir -p "${STAGE_WORK_DIR}"

    if [[ -z "${source_image}" ]]; then
        local stage_candidate="${WORK_DIR}/03-Preconfiguration/IMAGE.img"
        if [[ -f "${stage_candidate}" ]]; then
            source_image="${stage_candidate}"
        fi
    fi

    if [[ -z "${source_image}" ]]; then
        ensure_base_image_for_update
        local base_stage_candidate="${WORK_DIR}/01-Baseimage/IMAGE.img"
        if [[ -f "${base_stage_candidate}" ]]; then
            source_image="${base_stage_candidate}"
        fi
    fi

    if [[ -z "${source_image}" ]]; then
        local latest_deploy_image
        latest_deploy_image=$(ls -t "${DEPLOY_DIR}"/*"${IMAGE_TYPE}"*.img 2>/dev/null | head -n 1 || true)
        if [[ -n "${latest_deploy_image}" ]]; then
            source_image="${latest_deploy_image}"
        fi
    fi

    if [[ -z "${source_image}" ]]; then
        echo "[ERROR] Unable to find an image to update. Set UPDATE_IMAGE to an existing .img file." >&2
        exit 1
    fi

    if [[ ! -f "${source_image}" ]]; then
        echo "[ERROR] UPDATE_IMAGE path '${source_image}' does not exist." >&2
        exit 1
    fi

    if [[ "${source_image}" != "${target_image}" ]]; then
        log "Copying source image ${source_image}"
        rm -f "${target_image}"
        cp "${source_image}" "${target_image}"
    fi
}

run_update_mode(){
    STAGE="Update"
    STAGE_DIR="${BASE_DIR}/stages/${STAGE}"

    if [[ ! -d "${STAGE_DIR}" ]]; then
        echo "[ERROR] Missing ${STAGE_DIR} directory for update workflow." >&2
        exit 1
    fi

    STAGE_WORK_DIR="${WORK_DIR}/${STAGE}"
    PREV_STAGE="${STAGE}"
    PREV_STAGE_DIR="${STAGE_DIR}"
    PREV_WORK_DIR="${STAGE_WORK_DIR}"

    prepare_update_image
    mount_image

    local update_script="${STAGE_DIR}/update.sh"
    if [[ ! -f "${update_script}" ]]; then
        echo "[ERROR] Missing ${update_script}." >&2
        unmount_image
        exit 1
    fi

    log "Running update script inside chroot"
    on_chroot < "${update_script}"

    touch "${STAGE_WORK_DIR}/SKIP"
    unmount_image
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
export IMG_DATE="${IMG_DATE:-"$(date -d '+1 hour' +'%m-%d-%Y--%H-%M-%S')"}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR="${BASE_DIR}/scripts"
export WORK_DIR="${BASE_DIR}/work-${IMAGE_TYPE}"
export DEPLOY_DIR=${DEPLOY_DIR:-"${BASE_DIR}/deploy"}
export LOG_FILE="${WORK_DIR}/build.log"

mkdir -p "${WORK_DIR}"

export BASE_DIR

export BASE_IMAGE_SHA256
export BASE_IMAGE_SHA512

export LEGACY
export BASE_IMAGE_Mirror
export HAS_CUSTOM_KERNEL
export BIT
export ROOT_PART
export ROOT_IMAGE_SIZE_BYTES
export BOOT_PART
export HAVE_BOOT_PART
export HAVE_CONF_PART
export CONF_PART
export OPENHD_PACKAGE
export QOPENHD_PACKAGE
export RPI5
export UPDATE_LINUX_PACKAGES_ONLY
export KERNEL_PACKAGE
export OPENHD_LITE_IMAGE
export GLIDE_PACKAGE
export OPENHD_RUNTIME_PACKAGES
export KERNEL_PACKAGES
export RTL_DRIVER_PACKAGES
export OPENHD_LITE_LOCAL_DEB_DIR
export OS
export IMAGE_TYPE
export DISTRO
export BASE_IMAGE_GDRIVE_URL
export BASE_IMAGE_GDRIVE_RCLONE_PATH
export BASE_IMAGE_URL
export BASE_IMAGE
export TESTING
export SMALL
export HAS_CUSTOM_BASE

export CLEAN
export IMG_NAME

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

if [[ "${UPDATE_MODE}" == "true" ]]; then
    run_update_mode
else
    # Iterate trough the steps
    find ./stages -name '*.sh' -type f | xargs chmod 775
    for STAGE_DIR in "${BASE_DIR}/stages/"*; do
        if [ -d "${STAGE_DIR}" ]; then
            run_stage
        fi
    done
fi

# Shrink Image ( only rpi and armbian right now)
log ""
log "======================================================"
if [[ "${UPDATE_MODE}" == "true" ]]; then
    log "Skipping pishrink for update workflow."
else
    log "Shrinking image: ${IMAGE_PATH_NAME}"
    if [[ "${OS}" == "raspbian" ]]; then
        ${SCRIPT_DIR}/pishrink.sh -v -f 500 ${PREV_WORK_DIR}/*.img
    # elif [[ "${OS}" == "debian-X20" ]]; then
    # ${SCRIPT_DIR}/pishrink.sh -v -s ${PREV_WORK_DIR}/*.img
    else
        echo "This image can't be shrunken"
    fi
fi

# Prepare Windows-readable OpenHD config partition and recordings partition
sudo chmod +x ${SCRIPT_DIR}/uPart.sh
${SCRIPT_DIR}/uPart.sh -v ${PREV_WORK_DIR}/*.img


# rename the image according to the build date, the builder/openhd repo versions
if [ -e "${WORK_DIR}/openhd_version.txt" ]; then
    OPENHD_VERSION=$(cat "${WORK_DIR}/openhd_version.txt")
else
    OPENHD_VERSION="unknown"
fi

if [ -f "${PREV_WORK_DIR}/IMAGE.img" ]; then
    IMAGE_PATH_NAME="${DEPLOY_DIR}/${IMG_NAME}-${OPENHD_VERSION}-${IMAGE_TYPE}.img"
    log ""
    log "======================================================"
    log "Deploy image to: ${IMAGE_PATH_NAME}"
    df -h
    mkdir -p "${DEPLOY_DIR}" || true
    df -h
    ls -l --block-size=M ${PREV_WORK_DIR}/*.img
    mv ${PREV_WORK_DIR}/*.img ${DEPLOY_DIR}
    rm -Rf ${PREV_WORK_DIR}
    cd ${DEPLOY_DIR}
    df -h
fi

cd ${BASE_DIR}

log "End ${BASE_DIR}"
