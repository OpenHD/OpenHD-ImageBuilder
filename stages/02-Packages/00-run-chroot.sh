# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image

#!/bin/bash

# Remove bad and unnecessary symlinks 
rm /lib/modules/*/build || true
rm /lib/modules/*/source || true


if [ "${APT_CACHER_NG_ENABLED}" == "true" ]; then
    echo "Acquire::http::Proxy \"${APT_CACHER_NG_URL}/\";" >> /etc/apt/apt.conf.d/10cache
fi

if [[ "${OS}" == "raspbian" ]]; then
    rm /boot/config.txt
    rm /boot/cmdline.txt
    apt-mark hold firmware-atheros || exit 1
    apt purge firmware-atheros || exit 1
    apt -yq install firmware-misc-nonfree || exit 1
    apt-mark hold raspberrypi-kernel
    # Install libraspberrypi-dev before apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get -yq install libraspberrypi-doc libraspberrypi-dev libraspberrypi-dev libraspberrypi-bin libraspberrypi0 || exit 1
    apt-mark hold libraspberrypi-dev libraspberrypi-bin libraspberrypi0 libraspberrypi-doc
    apt purge raspberrypi-kernel
    PLATFORM_PACKAGES=""
fi


if [[ "${OS}" == "armbian" ]]; then
    PLATFORM_PACKAGES=""
fi


if [[ "${OS}" == "ubuntu" ]]; then
    PLATFORM_PACKAGES=""
fi


if [[ "${HAS_CUSTOM_KERNEL}" == "true" ]]; then
    PLATFORM_PACKAGES="${PLATFORM_PACKAGES} ${KERNEL_PACKAGE}"
fi


apt-get update || exit 1

apt-get install -y apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-1/cfg/gpg/gpg.0AD501344F75A993.key' | apt-key add -
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-1-testing/cfg/gpg/gpg.58A6C96C088A96BF.key' | apt-key add -


echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1.list

if [[ "${TESTING}" == "true" ]]; then
    echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1-testing/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1-testing.list
fi

apt-get update || exit 1

PURGE="wireless-regdb crda cron avahi-daemon cifs-utils curl iptables triggerhappy man-db dphys-swapfile logrotate"


DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
${OPENHD_PACKAGE} \
${PLATFORM_PACKAGES} \
${GNUPLOT} || exit 1

DEBIAN_FRONTEND=noninteractive apt-get -yq purge ${PURGE} || exit 1

DEBIAN_FRONTEND=noninteractive apt-get -yq clean || exit 1
DEBIAN_FRONTEND=noninteractive apt-get -yq autoremove || exit 1

if [ ${APT_CACHER_NG_ENABLED} == "true" ]; then
    rm /etc/apt/apt.conf.d/10cache
fi


MNT_DIR="${STAGE_WORK_DIR}/mnt"

#
# Write the openhd package version back to the base of the image and
# in the work dir so the builder can use it in the image name
export OPENHD_VERSION=$(dpkg -s openhd | grep "^Version" | awk '{ print $2 }')

echo ${OPENHD_VERSION} > /openhd_version.txt
echo ${OPENHD_VERSION} > /boot/openhd_version.txt
