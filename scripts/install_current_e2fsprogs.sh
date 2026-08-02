#!/usr/bin/env bash

set -euo pipefail

temp_root="${RUNNER_TEMP:-/tmp}"
work_dir="$(mktemp -d "${temp_root}/openhd-e2fsprogs.XXXXXX")"
trap 'rm -rf "${work_dir}"' EXIT

git clone --depth 1 https://github.com/tytso/e2fsprogs \
  "${work_dir}/source"
mkdir -p "${work_dir}/build"
cd "${work_dir}/build"
"${work_dir}/source/configure"
make -j"$(nproc)"
sudo make install

# Clear Bash's command lookup cache and show which resize2fs subsequent image
# stages will use. Ubuntu 22.04's 1.46.5 cannot handle newer ext4 features
# present in current Radxa base images.
hash -r
command -v resize2fs
resize2fs -V 2>&1 | head -n 1 || true
