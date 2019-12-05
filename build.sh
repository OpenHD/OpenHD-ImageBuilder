#!/bin/bash -e
# shellcheck disable=SC2119,SC1091

run_stage(){
	log "Begin ${STAGE_DIR}"
	STAGE="$(basename "${STAGE_DIR}")"
	STAGE_WORK_DIR="${WORK_DIR}/${STAGE}"
	pushd "${STAGE_DIR}" > /dev/null

	# Create the Work folder
	mkdir -p "${STAGE_WORK_DIR}"

	# Check wether to skip or not
	if [ ! -f "${STAGE_DIR}/SKIP" ]; then
        	# mount the image for this stage
	        if [ ! -f "${STAGE_DIR}/SKIP_IMAGE" ]; then
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
			SKIP_STEP="${STAGE_DIR}/SKIP_STEP${i}"
	        	if [ ! -f "${SKIP_STEP}" ]; then
	                	log "Begin ${STAGE_DIR}/${i}-run.sh"
        	        	./${i}-run.sh
                		log "End ${STAGE_DIR}/${i}-run.sh"
				touch "${SKIP_STEP}"
				
			fi
	            fi
        	    if [ -f ${i}-run-chroot.sh ]; then
			SKIP_CH_STEP="${STAGE_DIR}/SKIP_CH_STEP${i}"
	        	if [ ! -f "${SKIP_CH_STEP}" ]; then
                		log "Begin ${STAGE_DIR}/${i}-run-chroot.sh"
	                	on_chroot < ${i}-run-chroot.sh
	                	log "End ${STAGE_DIR}/${i}-run-chroot.sh"
				touch "${SKIP_CH_STEP}"
			fi
        	    fi
	        done
	fi

	# SKIP this stage next time
	touch "${STAGE_DIR}/SKIP"

    	PREV_STAGE="${STAGE}"
    	PREV_STAGE_DIR="${STAGE_DIR}"
	PREV_WORK_DIR="${WORK_DIR}/${STAGE}"

	if [ ! -f "${STAGE_DIR}/SKIP_IMAGE" ]; then
		unmount_image
	fi

	popd > /dev/null
	log "End ${STAGE_DIR}"
}

if [ "$(id -u)" != "0" ]; then
	echo "Please run as root" 1>&2
	exit 1
fi

if [ -f config ]; then
	source config
fi

if [ -z "${IMG_NAME}" ]; then
	echo "IMG_NAME not set" 1>&2
	exit 1
fi

# Variables
export IMG_DATE="${IMG_DATE:-"$(date +%Y-%m-%d)"}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR="${BASE_DIR}/scripts"
export WORK_DIR="${BASE_DIR}/work"
export DEPLOY_DIR=${DEPLOY_DIR:-"${BASE_DIR}/deploy"}
export LOG_FILE="${WORK_DIR}/build.log"

mkdir -p "${WORK_DIR}"

# Get the dynamic information from the image
curl $BASE_IMAGE_URL/$BASE_IMAGE".info" > $WORK_DIR/infofile

GIT_KERNEL_SHA1=$(cat $WORK_DIR/infofile | grep -Po '\b(Kernel: https:\/\/github\.com\/raspberrypi\/linux\/tree\/\K)+(.*)$')
KERNEL_VERSION_V7=$(cat $WORK_DIR/infofile | grep -Po '\b(Uname string: Linux version )\K(?<price>[^\ ]+)')
KERNEL_VERSION=${KERNEL_VERSION_V7%"-v7+"}"+"

# used in the stage 5 scripts to place a version file inside the image, and below after the
# stages have run, in the name of the image itself
BUILDER_VERSION=$(git describe --always --tags)
export BUILDER_VERSION


export BASE_DIR

export CLEAN
export IMG_NAME
export BASE_IMAGE_URL
export BASE_IMAGE
export J_CORES
export GIT_KERNEL_SHA1
export KERNEL_VERSION
export KERNEL_VERSION_V7
export APT_PROXY
export OPENHD_REPO
export OPENHD_BRANCH

export STAGE
export STAGE_DIR
export STAGE_WORK_DIR
export PREV_STAGE
export PREV_STAGE_DIR
export PREV_WORK_DIR
export ROOTFS_DIR
export PREV_ROOTFS_DIR
export IMG_SUFFIX

# shellcheck source=scripts/common
source "${SCRIPT_DIR}/common"

log "IMG ${BASE_IMAGE}"
log "SHA ${GIT_KERNEL_SHA1}"
log "V7  ${KERNEL_VERSION_V7}"
log "VER ${KERNEL_VERSION}"
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
	cp "${PREV_WORK_DIR}/IMAGE.img" "${DEPLOY_DIR}/${IMG_NAME}-${IMG_DATE}-${OPENHD_VERSION}.img"
fi

#  Clean up SKIP_STEP files since we finished the build
#  and it should be clean for the next run. Maybe make
#  this an option?
cd ${BASE_DIR}
find stages -name "SKIP_STEP*" -exec rm {} \;
#find stages -name "SKIP*" -exec rm {} \;

log "End ${BASE_DIR}"
