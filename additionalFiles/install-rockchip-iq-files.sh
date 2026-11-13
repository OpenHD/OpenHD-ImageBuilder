#!/usr/bin/env bash
set -euo pipefail

case "${OS:-}" in
    radxa-debian-rock-cm3*|radxa-debian-rock3*)
        family=rockchip-iqfiles-rk356x
        ;;
    radxa-debian-rock5*)
        family=rockchip-iqfiles
        ;;
    *) exit 0 ;;
esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
ref=e4b941ec100589076a06c8cbaa0bdc3ae6fb98ae
curl -fsSL --retry 4 "https://codeload.github.com/OpenHD/rockchip-iq-files/tar.gz/$ref" -o "$work/iq.tar.gz"
printf '%s  %s\n' f4a08c6feb672b60a8b458202ae68f4b9b3a5885dc81466cc7e9540b90e7c67b "$work/iq.tar.gz" | sha256sum -c -
tar -xf "$work/iq.tar.gz" -C "$work" "rockchip-iq-files-$ref/$family"
install -d /etc/iqfiles
for file in "$work/rockchip-iq-files-$ref/$family/"*.{json,xml}; do
    [[ -f "$file" ]] || continue
    target="/etc/iqfiles/${file##*/}"
    # Preserve tuning already installed by the base or its camera package.
    [[ -e "$target" ]] || install -m 0644 "$file" "$target"
done

if [[ "$family" == rockchip-iqfiles ]]; then
    if [[ ! -e /etc/iqfiles/imx577_IMX577_Leica.json && ! -L /etc/iqfiles/imx577_IMX577_Leica.json ]]; then
        ln -s imx477_IMX477_Leica.json /etc/iqfiles/imx577_IMX577_Leica.json
    fi
    # These profiles require Rock 5 ISP 2.4.0 / RKAIQ v6.0x6.1.
    # Stage them for selection on a matching camera stack.
    destination=/usr/share/openhd/iq-profiles/rock5-rkaiq6
    install -d "$destination"
    ref=1fc5d49c5fcf926320d48437de72d7edaaef5d2f
    while read -r file sha256; do
        curl -fsSL --retry 4 "https://raw.githubusercontent.com/avafinger/rockchip-iqfiles/$ref/Rock5/$file" -o "$work/$file"
        printf '%s  %s\n' "$sha256" "$work/$file" | sha256sum -c -
        install -m 0644 "$work/$file" "$destination/$file"
    done <<'EOF'
imx290_imx290_default.json da5fd58fcf041542287bce6faa402ae54bc1e0f55b0236178af13f0c85a4d1a6
imx708_uhq_default_4608x2592.json 830cc81d441ddb2a7baa4abc9e89bb366c26ef0eb1d72868247e662af878fc6c
EOF
    # Keep shared Sony tuning alongside the original on the matching ISP.
    ln -sfn imx290_imx290_default.json "$destination/imx327_imx327_default.json"
    ln -sfn imx290_imx290_default.json "$destination/imx462_imx462_default.json"
    # Activate the shared profile for the sensor/module names that match it
    # on RKAIQ 6. Preserve any camera-specific tuning already present.
    aiq_version=$(dpkg-query -W -f='${Version}' camera-engine-rkaiq 2>/dev/null || true)
    case "$aiq_version" in
        6.0x6.1|6.0x6.1-*)
            for sensor in imx290 imx327 imx462; do
                file="${sensor}_${sensor}_default.json"
                target="/etc/iqfiles/$file"
                if [[ ! -e "$target" && ! -L "$target" ]]; then
                    ln -s "$destination/$file" "$target"
                fi
            done
            ;;
    esac
fi
