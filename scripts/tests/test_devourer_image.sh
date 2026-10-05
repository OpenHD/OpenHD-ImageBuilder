#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
source "$repo/additionalFiles/prepare-devourer-image.sh"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT
export OS=raspbian
export TEST_COMMAND_LOG="$fixture/commands"
mkdir -p "$fixture/bin" "$fixture/image/usr/lib/modules/6.1-test/kernel/drivers/net/wireless"
ln -s usr/lib "$fixture/image/lib"
wireless="$fixture/image/usr/lib/modules/6.1-test/kernel/drivers/net/wireless"
for name in 88XXau_ohd.ko 88x2eu_ohd.ko.xz rtl88x2cu_ohd.ko.gz \
    88x2bu.ko.zst rtw88_8822bu.ko rtw89_8852bu.ko; do
    touch "$wireless/$name"
done
ln -s "$wireless/88XXau_ohd.ko" "$wireless/88XXau_wfb.ko"
for name in brcmfmac.ko rtw88_core.ko rtw88_8822be.ko rtw89_8852be.ko \
    cfg80211.ko mac80211.ko iwlwifi.ko aic8800_fdrv.ko mt7921u.ko; do
    touch "$wireless/$name"
done
cat > "$fixture/bin/depmod" <<'EOF'
#!/bin/sh
printf 'depmod %s\n' "$*" >> "$TEST_COMMAND_LOG"
EOF
chmod +x "$fixture/bin/depmod"
export PATH="$fixture/bin:$PATH"
prepare_devourer_image "$fixture/image"
for name in 88XXau_ohd.ko 88x2eu_ohd.ko.xz rtl88x2cu_ohd.ko.gz \
    88x2bu.ko.zst rtw88_8822bu.ko rtw89_8852bu.ko 88XXau_wfb.ko; do
    test ! -e "$wireless/$name" && test ! -L "$wireless/$name"
done
for name in brcmfmac.ko rtw88_core.ko rtw88_8822be.ko rtw89_8852be.ko \
    cfg80211.ko mac80211.ko iwlwifi.ko aic8800_fdrv.ko mt7921u.ko; do
    test -f "$wireless/$name"
done
test "$(wc -l < "$TEST_COMMAND_LOG")" -eq 1
grep -q '^install 88x2eu_ohd /bin/false$' "$fixture/image/etc/modprobe.d/90-openhd-devourer.conf"
cp "$fixture/image/etc/modprobe.d/90-openhd-devourer.conf" "$fixture/policy"
prepare_devourer_image "$fixture/image"
cmp "$fixture/policy" "$fixture/image/etc/modprobe.d/90-openhd-devourer.conf"

# X20 follows the same Devourer-only policy as every other target.
export OS=debian-X20
touch "$wireless/88XXau_ohd.ko"
prepare_devourer_image "$fixture/image"
test ! -f "$wireless/88XXau_ohd.ko"
test "$(wc -l < "$TEST_COMMAND_LOG")" -eq 3

# Package cleanup selects exact installed USB driver packages, preserving PCI
# drivers, firmware, common DKMS, and the kernel containing onboard drivers.
cat > "$fixture/bin/dpkg-query" <<'EOF'
#!/bin/sh
cat <<'PACKAGES'
rtl8812au-x86 installed
rtl88x2eu-rpi:armhf installed
rtl88x2bu-old config-files
rtl88x2cu-board installed
8852bu-dkms installed
8852be-dkms installed
firmware-realtek installed
linux-image-test installed
dkms installed
PACKAGES
EOF
for command in apt-mark apt-get; do
    cat > "$fixture/bin/$command" <<'EOF'
#!/bin/sh
printf '%s %s\n' "${0##*/}" "$*" >> "$TEST_COMMAND_LOG"
EOF
done
chmod +x "$fixture/bin/"*
remove_legacy_broadcast_packages
grep -q '^apt-get -y purge rtl8812au-x86 rtl88x2eu-rpi:armhf rtl88x2cu-board 8852bu-dkms$' "$TEST_COMMAND_LOG"

# A missing module tree is valid (e.g. userspace-only rootfs).
export OS=ubuntu-x86
mkdir -p "$fixture/empty"
prepare_devourer_image "$fixture/empty"
test -f "$fixture/empty/etc/modprobe.d/90-openhd-devourer.conf"
echo 'Devourer image cleanup tests passed'
