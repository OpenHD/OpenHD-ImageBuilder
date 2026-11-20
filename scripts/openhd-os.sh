#!/usr/bin/env bash
# ImageBuilder integration for the separately maintained Debian x86 distribution.
set -euo pipefail
action=${1:?Usage: openhd-os.sh build|update|apps|test WORKDIR [SOURCES_OR_DEB_DIRECTORY]}
work=${2:?Supply the persistent build work directory}
here=$(cd -- "$(dirname -- "$0")" && pwd)
revision=$(cat "$here/../openhd-os.revision")
checkout=${OPENHD_OS_CHECKOUT:-$work/os-source}
if [[ ! -d "$checkout/.git" ]]; then
    git clone https://github.com/OpenHD/OpenHD-OS.git "$checkout"
fi
if [[ -z ${OPENHD_OS_CHECKOUT:-} ]]; then
    git -C "$checkout" fetch origin "$revision"
    git -C "$checkout" checkout --detach "$revision"
fi
case "$action" in
    build) exec bash "$checkout/debian-x86/build.sh" "$work" "${3:?Supply source directory/archive}" ;;
    update) exec bash "$checkout/debian-x86/update-packages.sh" "$work" "${3:?Supply new Debian packages}" "${4:---test}" ;;
    apps) exec bash "$checkout/debian-x86/refresh-desktop-apps.sh" "$work" "${3:---test}" ;;
    test) exec bash "$checkout/debian-x86/assemble-and-test.sh" "$work" --test-only ;;
    *) echo "Unknown action: $action" >&2; exit 1 ;;
esac
