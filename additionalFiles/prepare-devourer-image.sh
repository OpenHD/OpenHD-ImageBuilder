#!/usr/bin/env bash
# Image/chroot preparation only. Never unload drivers or touch live USB devices.
set -euo pipefail

is_legacy_broadcast_package() {
    case "${1%%:*}" in
        rtl8812au-*|rtl88x2bu-*|rtl88x2cu-*|rtl88x2eu-*|rtl8852bu-*|8852bu-dkms)
            return 0 ;;
        *) return 1 ;;
    esac
}

is_legacy_broadcast_module() {
    local name="${1##*/}"
    name="${name,,}"
    name="${name%.zst}"
    name="${name%.xz}"
    name="${name%.gz}"
    name="${name%.ko}"
    case "${name//-/_}" in
        88xxau_ohd|88xxau_wfb|88x2au_ohd|88x2bu_ohd|88x2cu_ohd|88x2eu_ohd|8852bu_ohd|\
        rtl88xxau_ohd|rtl88x2au_ohd|rtl88x2bu_ohd|rtl88x2cu_ohd|rtl88x2eu_ohd|rtl8852bu_ohd|\
        8812au|8814au|88xxau|88x2bu|88x2cu|88x2eu|8852bu|\
        rtl8812au|rtl8814au|rtl88x2bu|rtl88x2cu|rtl88x2eu|rtl8852bu|\
        rtw88_8812au|rtw88_8822bu|rtw88_8822cu|rtw89_8852bu)
            return 0 ;;
        *) return 1 ;;
    esac
}

remove_legacy_broadcast_packages() {
    local package status
    local -a packages=()
    local inventory
    inventory="$(dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n')"
    while read -r package status; do
        [[ "$status" == installed ]] || continue
        if is_legacy_broadcast_package "$package"; then
            packages+=("$package")
        fi
    done <<< "$inventory"
    if ((${#packages[@]})); then
        # No wildcards or autoremove: retain onboard Wi-Fi and kernel packages.
        apt-mark unhold "${packages[@]}"
        apt-get -y purge "${packages[@]}"
    fi
}

prepare_devourer_image() {
    local target_root="${1:-/}"
    target_root="$(realpath -e "$target_root")"
    if [[ "$target_root" == / ]]; then
        local openhd_binary
        openhd_binary="$(command -v openhd)"
        if ! grep -a -q 'Devourer identified' "$openhd_binary"; then
            echo "Image requires a Devourer-enabled OpenHD package before removing drivers." >&2
            return 1
        fi
        remove_legacy_broadcast_packages
    fi

    local module modules_root version
    local -a module_roots=()
    # Resolve usrmerge aliases once. Operate only on individual radio modules,
    # never a complete wireless directory containing onboard/PCI drivers.
    for modules_root in "$target_root/lib/modules" "$target_root/usr/lib/modules"; do
        [[ -d "$modules_root" ]] || continue
        modules_root="$(realpath -e "$modules_root")"
        if [[ "$target_root" != / && "$modules_root" != "$target_root/"* ]]; then
            echo "Module path escapes target image: $modules_root" >&2
            return 1
        fi
        [[ " ${module_roots[*]} " == *" $modules_root "* ]] || module_roots+=("$modules_root")
    done
    for modules_root in "${module_roots[@]}"; do
        while IFS= read -r -d '' module; do
            if is_legacy_broadcast_module "$module"; then
                echo "Removing Devourer-replaced module: $module"
                rm -f -- "$module"
            fi
        done < <(find "$modules_root" \( -type f -o -type l \) \
            \( -name '*.ko' -o -name '*.ko.xz' -o -name '*.ko.gz' -o -name '*.ko.zst' \) -print0)
    done

    mkdir -p "$target_root/etc/modprobe.d"
    # A subsequent kernel package update may restore a bundled module. Keep it
    # from competing with Devourer until the next image cleanup.
    cat > "$target_root/etc/modprobe.d/90-openhd-devourer.conf" <<'EOF'
# OpenHD broadcast USB radios are owned by Devourer/libusb.
# Onboard/PCI Wi-Fi and shared wireless core drivers remain available.
EOF
    for module in 88XXau_ohd 88XXau_wfb 88x2au_ohd 88x2bu_ohd 88x2cu_ohd 88x2eu_ohd 8852bu_ohd \
        rtl88xxau_ohd rtl88x2au_ohd rtl88x2bu_ohd rtl88x2cu_ohd rtl88x2eu_ohd rtl8852bu_ohd \
        8812au 8814au 88XXau 88x2bu 88x2cu 88x2eu 8852bu \
        rtl8812au rtl8814au rtl88x2bu rtl88x2cu rtl88x2eu rtl8852bu \
        rtw88_8812au rtw88_8822bu rtw88_8822cu rtw89_8852bu; do
        printf 'blacklist %s\ninstall %s /bin/false\n' "$module" "$module" \
            >> "$target_root/etc/modprobe.d/90-openhd-devourer.conf"
    done

    for modules_root in "${module_roots[@]}"; do
        while IFS= read -r -d '' version; do
            depmod -b "$target_root" -a "${version##*/}"
        done < <(find "$modules_root" -mindepth 1 -maxdepth 1 -type d -print0)
    done
    # Rebuild existing initramfs files so they cannot retain removed drivers.
    if [[ "$target_root" == / ]] && command -v update-initramfs >/dev/null 2>&1; then
        update-initramfs -u -k all
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    prepare_devourer_image "$@"
fi
