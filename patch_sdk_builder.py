with open("scripts/sdk_builder.sh", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add set -euo pipefail
if "set -euo pipefail" not in content:
    content = content.replace("#!/usr/bin/env bash", "#!/usr/bin/env bash\nset -euo pipefail")

# 2. Add dos2unix for Orqa
orqa_block_old = """  if [[ "$PLATFORMIDENT" == "Orqa" ]]; then
    echo "Executing Orqa Yocto build process..."
    sudo mkdir -p /home/orqa"""
orqa_block_new = """  if [[ "$PLATFORMIDENT" == "Orqa" ]]; then
    echo "Executing Orqa Yocto build process..."
    sudo apt-get update && sudo apt-get install -y dos2unix
    dos2unix build.sh setup-environment || true
    sed -i 's/\\r$//' build.sh setup-environment || true
    sudo mkdir -p /home/orqa"""
content = content.replace(orqa_block_old, orqa_block_new)

# 3. Add pillow removal for luckfox
luckfox_block_old = """    # Patch all luckfox defconfigs
    for defconf in sysdrv/tools/board/buildroot/*_defconfig; do"""
luckfox_block_new = """    # Remove python-pillow from all luckfox defconfigs to prevent build failure on Ubuntu 24.04
    sed -i 's/BR2_PACKAGE_PYTHON_PILLOW=y/# BR2_PACKAGE_PYTHON_PILLOW is not set/g' sysdrv/tools/board/buildroot/*_defconfig || true

    # Patch all luckfox defconfigs
    for defconf in sysdrv/tools/board/buildroot/*_defconfig; do"""
content = content.replace(luckfox_block_old, luckfox_block_new)

with open("scripts/sdk_builder.sh", "w", encoding="utf-8", newline="\n") as f:
    f.write(content)
print("Patched sdk_builder.sh")
