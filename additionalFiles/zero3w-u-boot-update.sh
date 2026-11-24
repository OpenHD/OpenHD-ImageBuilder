#!/bin/sh
# The Radxa Bullseye generator reads U_BOOT_PROMPT but hardcodes prompt 1.
set -eu

vendor=/usr/sbin/u-boot-update.distrib
generator=$(mktemp)
trap 'rm -f -- "$generator"' EXIT HUP INT TERM
sed 's/^prompt 1$/prompt ${U_BOOT_PROMPT}/' "$vendor" > "$generator"
if ! grep -Fxq 'prompt ${U_BOOT_PROMPT}' "$generator"; then
    echo 'Unsupported u-boot-update prompt template for the Zero 3W image.' >&2
    exit 1
fi
sh "$generator" "$@"
