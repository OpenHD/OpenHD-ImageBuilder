#!/usr/bin/env bash
set -euo pipefail

usage="Usage: repack_x21_firmware.sh <firmware.zip> <update.ohd> <output.zip>"
firmware_archive="$(realpath "${1:?${usage}}")"
ohd_update="$(realpath "${2:?${usage}}")"
output_archive="$(realpath -m "${3:?${usage}}")"

test -s "${firmware_archive}"
test -s "${ohd_update}"

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT
firmware_dir="${work_dir}/firmware-zip"
ohd_dir="${work_dir}/ohd-update"
mkdir -p "${firmware_dir}" "${ohd_dir}" "$(dirname "${output_archive}")"

# A full X21B archive has exactly one OHD partition at this path.
ohd_entry="output/firmware/ohd.img"
entry_count="$(unzip -Z1 "${firmware_archive}" | grep -Fxc "${ohd_entry}" || true)"
if [[ "${entry_count}" -ne 1 ]]; then
  echo "Expected exactly one ${ohd_entry} in ${firmware_archive}, found ${entry_count}" >&2
  exit 1
fi

unzip -q "${firmware_archive}" -d "${firmware_dir}"
(
  cd "${ohd_dir}"
  cpio -id --quiet --no-absolute-filenames ohd.img <"${ohd_update}"
)

new_ohd_image="${ohd_dir}/ohd.img"
test -s "${new_ohd_image}"
test "$(stat -c '%s' "${new_ohd_image}")" -eq "$((0x6400000))"
install -m 0644 "${new_ohd_image}" "${firmware_dir}/${ohd_entry}"

rm -f "${output_archive}"
(
  cd "${firmware_dir}"
  zip -q -r "${output_archive}" .
)

expected_sha256="$(sha256sum "${new_ohd_image}" | awk '{print $1}')"
embedded_sha256="$(unzip -p "${output_archive}" "${ohd_entry}" | sha256sum | awk '{print $1}')"
if [[ "${embedded_sha256}" != "${expected_sha256}" ]]; then
  echo "Repacked firmware contains the wrong OHD partition checksum" >&2
  exit 1
fi

echo "Created ${output_archive} with updated ${ohd_entry} (${embedded_sha256})"
