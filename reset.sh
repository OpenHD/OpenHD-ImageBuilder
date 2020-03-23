#!/bin/bash -e

IMAGE_ARCH=$1
DISTRO=$2

echo "Reset Open.HD Builder"
echo "------------------------------------------------------"
echo ""


if [[ "${IMAGE_ARCH}" == "" || ${DISTRO} == "" ]]; then
    IMAGE_ARCH="pi"
    DISTRO="stretch"

    echo "Usage: ./reset.sh pi [stretch | buster]"
    echo "------------------------------------------------------"
    echo ""
fi

if [ -d "work-${IMAGE_ARCH}-${DISTRO}" ]; then
    pushd "work-${IMAGE_ARCH}-${DISTRO}"
        find . -type f -name 'SKIP' -delete
        find . -type f -name 'SKIP_STEP*' -delete
        find . -type f -name 'SKIP_CH_STEP*' -delete
        find . -type f -name 'IMAGE.img' -delete
    popd
fi
