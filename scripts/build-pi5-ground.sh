#!/bin/bash
# Standalone Trixie ground image builder; does not alter legacy Pi image recipes.
# Usage: sudo bash scripts/build-pi5-ground.sh QOPENHD_REPO SYSUTILS_REPO WORKDIR
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run this image builder as root' >&2; exit 1; }
builder=$(cd "$(dirname "$0")/.." && pwd)
qopenhd=$(realpath "${1:?Specify the QOpenHD source checkout}")
sysutils=$(realpath "${2:?Specify the SysUtils source checkout}")
mkdir -p "${3:?Specify an empty or resumable build directory}"
work=$(realpath "$3")
backend=$(realpath "${PI5_OPENHD_SOURCE:-$qopenhd/..}")
[[ "$work" != / && "$work" != "$builder" && "$work" != "$qopenhd" && "$work" != "$sysutils" ]]
source_git() {
    local checkout=$1
    shift
    # Git for Windows avoids slow per-file stat calls across the WSL mount.
    if [[ "$checkout" == /mnt/?/* ]] && command -v git.exe >/dev/null && command -v wslpath >/dev/null; then
        local windows_checkout
        windows_checkout=$(wslpath -w "$checkout")
        git.exe -c safe.directory="$windows_checkout" -C "$windows_checkout" "$@"
    else
        git -c safe.directory="$checkout" -C "$checkout" "$@"
    fi
}
source "$builder/images/pi5-trixie-ground"
cd "$work"
image="$work/OpenHD-RPi5-Ground-Trixie.img"
root="$work/rootfs"
cleanup() {
    if mountpoint -q "$root"; then umount -R "$root"; fi
    if [[ -f loop-device ]]; then losetup -d "$(cat loop-device)"; rm loop-device; fi
}
trap cleanup EXIT
if [[ ! -f base.verified ]]; then
    if [[ $(stat -c%s base.img.xz 2>/dev/null || echo 0) != "$BASE_IMAGE_DOWNLOAD_SIZE" ]]; then
        curl -fL --retry 4 -C - "$BASE_IMAGE_URL/$BASE_IMAGE" -o base.img.xz
    fi
    xz -dk base.img.xz
    echo "$BASE_IMAGE_EXTRACT_SHA256  base.img" | sha256sum -c -
    touch base.verified
fi
if [[ ! -f image.initialized ]]; then
    mv base.img "$image"
    truncate -s 6G "$image"
    parted -s "$image" resizepart 2 100%
    touch image.initialized
fi
mkdir -p "$root"
if ! mountpoint -q "$root"; then
    loop=$(losetup --find --show --partscan "$image")
    echo "$loop" > loop-device
    e2fsck -pf "${loop}p2" || [[ $? == 1 ]]
    resize2fs "${loop}p2"
    mount "${loop}p2" "$root"
    mount "${loop}p1" "$root/boot/firmware"
fi
for path in dev proc sys; do
    mountpoint -q "$root/$path" || mount --rbind "/$path" "$root/$path"
    mount --make-rslave "$root/$path"
done
cp /usr/bin/qemu-aarch64-static "$root/usr/bin/"
update-binfmts --import qemu-aarch64
update-binfmts --enable qemu-aarch64
rm -f "$root/etc/resolv.conf"
cp -L /etc/resolv.conf "$root/etc/resolv.conf"
printf '#!/bin/sh\nexit 101\n' > "$root/usr/sbin/policy-rc.d"
chmod +x "$root/usr/sbin/policy-rc.d"
if [[ ! -f dependencies.ready ]]; then
    chroot "$root" apt-get update
    mapfile -t packages < "$builder/additionalFiles/pi5-ground-packages.txt"
    python3 "$qopenhd/ci/apt-prefetch.py" --root "$root" --cache "$root/var/cache/apt/archives" "${packages[@]}"
    chroot "$root" /bin/bash < "$builder/additionalFiles/pi5-ground-dependencies.sh"
    touch dependencies.ready
fi
if [[ ! -f components.ready ]]; then
    chroot "$root" /bin/bash < "$builder/additionalFiles/pi5-ground-components.sh"
    touch components.ready
fi
mkdir -p "$work/source"
rsync -a --exclude=.git --exclude=fuzz --exclude=tests --exclude=test --exclude='build*/' --exclude='*.o' --exclude='*.so*' \
    --exclude=gstreamer_prebuilts "$qopenhd/app" "$qopenhd/qml" "$qopenhd/lib" \
    "$qopenhd/translations" "$qopenhd/tools" "$qopenhd/ci" "$qopenhd/deployment" \
    "$qopenhd/icons" "$work/source/"
cp "$qopenhd/CMakeLists.txt" "$work/source/"
if [[ ${PI5_SKIP_BUILDER_BUILD:-0} != 1 ]]; then
    docker build -t openhd-pi5-qt6-builder -f "$qopenhd/ci/pi5-qt6.Dockerfile" "$qopenhd/ci"
fi
docker run --rm -e BUILD_JOBS="${BUILD_JOBS:-4}" \
    -v "$work/source:/source" -v "$root:/target" -v "$sysutils:/sysutils:ro" \
    -v "$work:/work" openhd-pi5-qt6-builder bash /source/ci/build-pi5-qt6.sh
python3 "$qopenhd/ci/apt-prefetch.py" --root "$root" --cache "$root/var/cache/apt/archives" libpoco-dev libsodium-dev libpcap-dev libusb-1.0-0-dev libsdl2-dev librtlsdr-dev libncurses-dev
chroot "$root" apt-get install -y --no-install-recommends libpoco-dev libsodium-dev libpcap-dev libusb-1.0-0-dev libsdl2-dev librtlsdr-dev libncurses-dev
python3 "$builder/scripts/snapshot-pi5-backend.py" "$backend" "$work/backend-source" --revision "${PI5_OPENHD_REVISION:-HEAD}"
docker run --rm -e BUILD_JOBS="${BUILD_JOBS:-4}" -v "$root:/target" -v "$work:/work" \
    -v "$builder:/builder:ro" openhd-pi5-qt6-builder bash /builder/scripts/build-pi5-backend.sh
(cd "$work/source" && find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$work/source-inputs.sha256"
mkdir -p "$root/usr/local/share/qopenhd-rpi/deployment"
cp -a "$work/runtime/." "$root/usr/local/share/qopenhd-rpi/"
cp "$qopenhd/deployment/rpi/"*.service "$qopenhd/deployment/rpi/weston.ini" \
    "$root/usr/local/share/qopenhd-rpi/deployment/"
install -m755 "$work/sysutils-build/openhd_sys_utils" "$root/usr/local/bin/openhd_sys_utils"
install -Dm755 "$work/sysutils-build/openhd-usb-power-recover" "$root/usr/local/sbin/openhd-usb-power-recover"
chroot "$root" ldconfig
cp "$builder/additionalFiles/configure-pi5-ground.sh" "$work/configure-image.sh"
chroot "$root" /bin/bash < "$work/configure-image.sh"
{
    echo "base=$BASE_IMAGE"
    echo "base_extract_sha256=$BASE_IMAGE_EXTRACT_SHA256"
    echo "qopenhd_source=$(source_git "$qopenhd" rev-parse HEAD)"
    echo "qopenhd_diff_sha256=$(source_git "$qopenhd" diff --binary | sha256sum | cut -d' ' -f1)"
    echo "qopenhd_build_inputs_sha256=$(sha256sum "$work/source-inputs.sha256" | cut -d' ' -f1)"
    echo "sysutils_source=$(source_git "$sysutils" rev-parse HEAD)"
    echo "sysutils_diff_sha256=$(source_git "$sysutils" diff --binary | sha256sum | cut -d' ' -f1)"
    echo 'role=ground'
    echo 'qt_major=6'
    echo 'compositor=Weston 9.0.0, shared NXP source and scanout patch, Mesa/vc4 build'
    cat "$root/usr/share/openhd/image-components.txt"
    chroot "$root" dpkg-query -W '-f=${Package}=${Version}\n' libqt6core6t64 mesa-libgallium
    chroot "$root" dpkg-query -W '-f=${Package}=${Version}\n' libicu72 libpcre3 librtlsdr0
    echo 'openhd_backend=custom ground-only build; package supplies supporting files'
    cat "$work/backend-build-options.txt"
    cat "$work/backend-source/snapshot-revisions.txt"
    sha256sum "$root/usr/local/bin/openhd" "$root/usr/local/share/qopenhd-rpi/QOpenHD" "$root/usr/local/share/qopenhd-rpi/weston" "$root/usr/local/bin/openhd_sys_utils"
} > "$work/image-manifest.txt"
cp "$work/image-manifest.txt" "$root/boot/firmware/openhd/image-manifest.txt"
chroot "$root" dpkg --audit > "$work/dpkg-audit.txt"
test ! -s "$work/dpkg-audit.txt"
chroot "$root" /bin/bash -euo pipefail -c 'export LD_LIBRARY_PATH=/usr/local/share/qopenhd-rpi/lib; ldd /usr/local/share/qopenhd-rpi/QOpenHD; ldd /usr/local/share/qopenhd-rpi/weston; ldd /usr/local/bin/openhd; ldd /usr/local/bin/openhd_sys_utils; while IFS= read -r module; do echo "$module"; ldd "$module"; done < <(find /usr/local/share/qopenhd-rpi/lib -type f -name "*.so*")' > "$work/runtime-validation.txt" 2>&1
if grep -q 'not found' "$work/runtime-validation.txt"; then
    echo 'Unresolved image runtime libraries' >&2
    exit 1
fi
chroot "$root" /usr/bin/systemd-analyze verify qopenhd.service qopenhd-rpi-compositor.service openhd.service openhd-sys-utils.service > "$work/unit-validation.txt" 2>&1
chroot "$root" /bin/bash -c 'apt-get clean; rm -f /usr/sbin/policy-rc.d /usr/bin/qemu-aarch64-static /etc/ssh/ssh_host_* /opt/pi5-ui-smoke/QOpenHD; rmdir /opt/pi5-ui-smoke 2>/dev/null || true; rm -rf /tmp/pi5-ui-smoke /tmp/pi5-compositor-smoke; truncate -s0 /etc/machine-id'
ln -sfn ../run/NetworkManager/resolv.conf "$root/etc/resolv.conf"
sync
cleanup
trap - EXIT
check_loop=$(losetup --find --show --partscan "$image")
trap 'losetup -d "$check_loop"' EXIT
e2fsck -fn "${check_loop}p2" > "$work/filesystem-validation.txt" 2>&1
fsck.fat -n "${check_loop}p1" > "$work/boot-filesystem-validation.txt" 2>&1
losetup -d "$check_loop"
trap - EXIT
# Compress without making another uncompressed image.
xz -T2 -3 -k "$image"
sha256sum "$(basename "$image").xz" > "$image.xz.sha256"
echo "Built image: $image.xz"
