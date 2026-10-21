#!/usr/bin/env bash
# Install the newest indexed component versions from the selected OpenHD feed.
set -euo pipefail
channel="${OPENHD_COMPONENT_CHANNEL:-release}"
[[ -e /opt/additionalFiles/dev-build ]] && channel=dev-release
packages=("${OPENHD_PACKAGE:-openhd}" openhd-sys-utils open-hd-web-ui)
if [[ "${OPENHD_LITE_IMAGE:-false}" != true && "${RPI5:-false}" != true && "${OS:-}" != debian-X20 ]]; then
  qopenhd_package="${QOPENHD_PACKAGE:-qopenhd}"
  case "${OS:-}" in
    radxa-debian-rock5a|radxa-debian-rock5b) qopenhd_package=qopenhd-rk3588 ;;
    radxa-debian-rock-cm3|radxa-debian-rock-cm3-core3566|radxa-debian-rock3a) qopenhd_package=qopenhd-rk3566 ;;
  esac
  packages+=("$qopenhd_package")
fi
specs=()
for package in "${packages[@]}"; do
  newest=""
  while read -r version; do
    if [[ -z "$newest" ]] || dpkg --compare-versions "$version" gt "$newest"; then
      newest="$version"
    fi
  done < <(apt-cache madison "$package" | awk -F '|' -v feed="/openhd/$channel/" 'index($3, feed) {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
  if [[ -z "$newest" ]]; then
    echo "No $channel package indexed for $package on $(dpkg --print-architecture)" >&2
    exit 1
  fi
  echo "Selected $channel component: $package=$newest"
  specs+=("$package=$newest")
  apt-mark unhold "$package" >/dev/null
done
apt-get -y --allow-downgrades --reinstall --no-install-recommends \
  -o Acquire::Retries=5 -o Dpkg::Options::=--force-confnew install "${specs[@]}"
mkdir -p /usr/share/openhd /boot/openhd
# Updated base images may still contain the retired source pins.
rm -f /usr/share/openhd/release-components.json
manifest=/usr/share/openhd/image-components.txt
: > "$manifest"
for spec in "${specs[@]}"; do
  package="${spec%%=*}"
  expected="${spec#*=}"
  installed="$(dpkg-query -W -f='${Version}' "$package")"
  [[ "$installed" == "$expected" ]] || { echo "Component mismatch: $spec, installed $installed" >&2; exit 1; }
  printf '%s=%s\n' "$package" "$installed" >> "$manifest"
done
cat "$manifest"
cp "$manifest" /boot/openhd/image-components.txt
if [[ -f /opt/additionalFiles/image-release ]]; then
  install -m 0644 /opt/additionalFiles/image-release /usr/share/openhd/image-release
  cp /usr/share/openhd/image-release /boot/openhd/image-release
fi
