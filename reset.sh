#!/bin/bash -e

IMAGE_TYPE=$1

echo "Reset Open.HD Builder"
echo "------------------------------------------------------"
echo ""


if [[ "${IMAGE_TYPE}" == "" ]]; then
    IMAGE_TYPE="pi-bullseye"

    echo "Usage: ./reset.sh pi-bullseye"
    echo "------------------------------------------------------"
    echo ""
fi

if [ -d "work-${IMAGE_TYPE}-${OS}-${DISTRO}" ]; then
    pushd "work-${IMAGE_TYPE}-${OS}-${DISTRO}"
        find . -type f -name 'SKIP' -delete
        find . -type f -name 'IMAGE.img' -delete
    popd
fi
