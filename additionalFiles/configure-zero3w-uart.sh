#!/usr/bin/env bash
# Apply the Zero 3W boot policy inside the image chroot.
set -euo pipefail

assets=$(cd "$(dirname "$0")" && pwd)
boot_overlays=/boot/dtbo
overlay_name=rk3568-uart4-m1.dtbo
overlay="$boot_overlays/$overlay_name"
source_overlay="$overlay"
if [[ ! -f "$source_overlay" ]]; then
    source_overlay="$overlay.disabled"
fi
[[ -f "$source_overlay" ]] || { echo "Missing Zero 3W UART4 M1 overlay: $source_overlay" >&2; exit 1; }

# Verify the combined overlays on each supported Zero 3W device tree before
# enabling the overlay. The same list is used after SysUtils changes the camera.
merged=$(mktemp)
trap 'rm -f -- "$merged"' EXIT
shopt -s nullglob
base_dtbs=(
    /usr/lib/linux-image-*/rockchip/rk3566-radxa-zero3.dtb
    /usr/lib/linux-image-*/rockchip/rk3566-radxa-zero-3w-*.dtb
)
[[ ${#base_dtbs[@]} -gt 0 ]] || { echo 'No Zero 3W device tree found.' >&2; exit 1; }
overlays=("$boot_overlays"/*.dtbo)
if [[ "$source_overlay" != "$overlay" ]]; then
    overlays+=("$source_overlay")
fi
for dtb in "${base_dtbs[@]}"; do
    fdtoverlay -i "$dtb" -o "$merged" "${overlays[@]}"
    uart4=$(fdtget -t s "$merged" /aliases serial4)
    uart4_m1=$(fdtget -t s "$merged" /__symbols__ uart4m1_xfer)
    if [[ $(fdtget -t s "$merged" "$uart4" status) != okay ||
          $(fdtget -t x "$merged" "$uart4" pinctrl-0) != "$(fdtget -t x "$merged" "$uart4_m1" phandle)" ]]; then
        echo "UART4 M1 did not apply to $dtb." >&2
        exit 1
    fi
done

if [[ "$source_overlay" != "$overlay" ]]; then
    mv -T "$source_overlay" "$overlay"
fi

# The vendor generator re-runs after camera and kernel changes. Keep the fix
# installed in the image and let dpkg update the diverted vendor copy.
generator=/usr/sbin/u-boot-update
vendor="$generator.distrib"
if [[ $(dpkg-divert --truename "$generator") == "$generator" ]]; then
    dpkg-divert --local --rename --divert "$vendor" --add "$generator"
fi
[[ $(dpkg-divert --truename "$generator") == "$vendor" && -x "$vendor" ]]
install -m 0755 "$assets/zero3w-u-boot-update.sh" "$generator"

install -d /etc/u-boot-menu/conf.d
cat >/etc/u-boot-menu/conf.d/90-openhd-zero3w.conf <<'EOF'
# Start the default Extlinux entry immediately.
U_BOOT_PROMPT=0
U_BOOT_TIMEOUT=0
# An empty list means automatic discovery of enabled overlays.
if [ -n "${U_BOOT_FDT_OVERLAYS:-}" ]; then
    case " $U_BOOT_FDT_OVERLAYS " in
        *" rk3568-uart4-m1.dtbo "*) ;;
        *) U_BOOT_FDT_OVERLAYS="$U_BOOT_FDT_OVERLAYS rk3568-uart4-m1.dtbo" ;;
    esac
fi
EOF

u-boot-update
grep -Fxq 'prompt 0' /boot/extlinux/extlinux.conf
grep -Fxq 'timeout 0' /boot/extlinux/extlinux.conf
grep -Eq '^[[:space:]]*fdtoverlays[[:space:]].*rk3568-uart4-m1\.dtbo([[:space:]]|$)' /boot/extlinux/extlinux.conf
