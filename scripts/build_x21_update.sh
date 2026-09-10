#!/usr/bin/env bash
set -euo pipefail

usage="Usage: build_x21_update.sh <ohd-seed-dir> <openhd.tar.gz> <openhd-sys-utils.tar.gz> <output-dir>"
seed_dir="$(realpath "${1:?${usage}}")"
openhd_archive="$(realpath "${2:?${usage}}")"
sysutils_archive="$(realpath "${3:?${usage}}")"
output_dir="$(realpath -m "${4:?${usage}}")"

test -x "${seed_dir}/start-ohd.sh"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT
openhd_dir="${work_dir}/openhd"
sysutils_dir="${work_dir}/sysutils"
stage_dir="${work_dir}/ohd-root"
update_work="${work_dir}/swupdate"
mkdir -p "${openhd_dir}" "${sysutils_dir}" "${stage_dir}" "${update_work}" "${output_dir}"

tar -xzf "${openhd_archive}" -C "${openhd_dir}"
tar -xzf "${sysutils_archive}" -C "${sysutils_dir}"
(
  cd "${openhd_dir}"
  sha256sum -c sha256sums
)
(
  cd "${sysutils_dir}"
  sha256sum -c sha256sums
)

python3 - "${openhd_dir}/component-manifest.json" \
  "${sysutils_dir}/component-manifest.json" <<'PY'
import json
import sys

openhd = json.load(open(sys.argv[1], encoding="utf-8"))
sysutils = json.load(open(sys.argv[2], encoding="utf-8"))
expected = ((openhd, "openhd"), (sysutils, "openhd-sys-utils"))
for manifest, component in expected:
    assert manifest["schema"] == 1
    assert manifest["component"] == component
    assert manifest["platform"] == "x21b"
    assert manifest["architecture"] == "aarch64"
    assert manifest["sdk_sha256"] != "unknown"
assert openhd["sdk_sha256"] == sysutils["sdk_sha256"], "component SDK checksums differ"
assert openhd["sdk_buildroot_commit"] == sysutils["sdk_buildroot_commit"], "component Buildroot commits differ"
PY

cp -a "${seed_dir}/." "${stage_dir}/"
mkdir -p "${stage_dir}/usr/bin" "${stage_dir}/usr/lib" \
  "${stage_dir}/ohd-rw" "${stage_dir}/ohd-config"
cp -a "${openhd_dir}/usr/." "${stage_dir}/usr/"
cp -a "${sysutils_dir}/usr/." "${stage_dir}/usr/"

# X21 uses Devourer's userspace USB backend; loading an old kernel module is
# both unnecessary and unsafe across base-kernel updates.
sed -i '\|insmod /ohd/drivers/88x2eu_ohd\.ko|d' "${stage_dir}/start-ohd.sh"
rm -f "${stage_dir}/drivers/88x2eu_ohd.ko"
test -x "${stage_dir}/usr/bin/openhd"
test -x "${stage_dir}/usr/bin/openhd_sys_utils"
file "${stage_dir}/usr/bin/openhd" | grep -q 'ARM aarch64'
file "${stage_dir}/usr/bin/openhd_sys_utils" | grep -q 'ARM aarch64'

openhd_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["package_version"])' "${openhd_dir}/component-manifest.json")"
sysutils_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["package_version"])' "${sysutils_dir}/component-manifest.json")"
sdk_sha256="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sdk_sha256"])' "${openhd_dir}/component-manifest.json")"
sdk_buildroot_commit="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sdk_buildroot_commit"])' "${openhd_dir}/component-manifest.json")"
bundle_version="openhd-${openhd_version}_sysutils-${sysutils_version}"

mkfs.ubifs -x lzo -e 126976 -m 2048 -c 825 \
  -d "${stage_dir}" -F -o "${update_work}/ohd.img.ubifs"
cat >"${update_work}/ubinize.cfg" <<EOF
[ubi]
mode=ubi
vol_id=0
vol_type=dynamic
vol_name=ohd
vol_alignment=1
vol_flags=autoresize
image=${update_work}/ohd.img.ubifs
EOF
ubinize -o "${update_work}/ohd.img" -m 2048 -p 0x20000 \
  "${update_work}/ubinize.cfg"

# SWUpdate 2023.12 erases only image-size bytes for raw NAND. Padding the UBI
# image to the full mtd9 size guarantees that old UBI headers are erased.
ohd_partition_size=$((0x6400000))
ohd_image_size="$(stat -c '%s' "${update_work}/ohd.img")"
if ((ohd_image_size > ohd_partition_size)); then
  echo "OHD UBI image exceeds mtd9: ${ohd_image_size} > ${ohd_partition_size}" >&2
  exit 1
fi
head -c "$((ohd_partition_size - ohd_image_size))" /dev/zero \
  | tr '\000' '\377' >>"${update_work}/ohd.img"
test "$(stat -c '%s' "${update_work}/ohd.img")" -eq "${ohd_partition_size}"

cat >"${update_work}/sw-description" <<EOF
software =
{
    version = "${bundle_version}";
    description = "OpenHD X21B OHD partition update";
    images: (
        {
            filename = "ohd.img";
            device = "mtd9";
            type = "flash";
        }
    );
}
EOF

versioned_name="OpenHD-X21B-${openhd_version}-${sysutils_version}.ohd"
latest_name="OpenHD-X21B-latest.ohd"
(
  cd "${update_work}"
  printf '%s\n' sw-description ohd.img | cpio -ov -H crc -L \
    >"${output_dir}/${versioned_name}"
)
cp "${output_dir}/${versioned_name}" "${output_dir}/${latest_name}"

for update_name in "${versioned_name}" "${latest_name}"; do
  update_sha256="$(sha256sum "${output_dir}/${update_name}" | awk '{print $1}')"
  printf '%s  %s\n' "${update_sha256}" "${update_name}" \
    >"${output_dir}/${update_name}.sha256"
  cat >"${output_dir}/${update_name}.manifest.json" <<EOF
{
  "schema": 1,
  "platform": "x21b",
  "architecture": "aarch64",
  "openhd_package_version": "${openhd_version}",
  "sysutils_package_version": "${sysutils_version}",
  "sdk_sha256": "${sdk_sha256}",
  "sdk_buildroot_commit": "${sdk_buildroot_commit}",
  "ohd_seed_sha256": "${X21_OHD_SEED_SHA256:-unknown}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
done

latest_sha256="$(sha256sum "${output_dir}/${latest_name}" | awk '{print $1}')"
latest_size="$(stat -c '%s' "${output_dir}/${latest_name}")"
cat >"${output_dir}/openhd-x21b-updates.json" <<EOF
{
  "os_list": [
    {
      "name": "OpenHD X21B",
      "description": "SWUpdate package for an existing X21B installation",
      "icon": "https://fra1.digitaloceanspaces.com/openhd-images/Downloader/OpenHD-advanced.png",
      "subitems": [
        {
          "name": "OpenHD X21B latest",
          "description": "Replace the read-only OHD NAND partition using SWUpdate",
          "icon": "https://fra1.digitaloceanspaces.com/openhd-images/Downloader/OpenHD-advanced.png",
          "url": "https://dl.cloudsmith.io/public/openhd/dev-release/raw/files/${latest_name}",
          "image_download_size": ${latest_size},
          "extract_size": ${latest_size},
          "update_sha256": "${latest_sha256}",
          "update_destination": "root",
          "update_filename": "${latest_name}",
          "release_date": "$(date -u +%Y-%m-%d)"
        }
      ]
    }
  ]
}
EOF
echo "Created ${output_dir}/${versioned_name}"
