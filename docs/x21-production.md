# Production X21B images

Run the private `OpenHD/OpenHD-X21B` workflow on `master` with its default
`camera=arducam_openhd` to build the qualified base, camera driver, rootfs,
applications and matching SDK. Product camera provisioning data is supplied
inside that private workflow; firmware source is not copied into ImageBuilder.

The base publisher uploads immutable versioned firmware and filesystem seed
files, then updates `openhd-x21b-base-latest.json` last. The index contains their
SHA256/size, exact source revisions, SDK checksum and normal storage contract.

Run **New_Image_Workflow** on `dev-release`, target **x21-update**. It fetches
and verifies that base/seed pair, then chooses the newest available OpenHD and
SysUtils components that share the base SDK and Buildroot revision. Application
source revisions may advance independently; kernel/library ABI compatibility
is required. There is no fallback to an older full firmware image.

Outputs are:

- `firmware-*.zip`: complete firmware with the selected base kernel/rootfs and
  newly assembled applications, suitable for the normal X21 flashing tools.
- `OpenHD-X21B-full-*.ohd_base`: SWUpdate package with applications plus the
  inactive A/B bootloader, kernel and rootfs. This is the normal published update.
- `OpenHD-X21B-applications-*.ohd`: applications only, retained as an artifact.
  It does not install kernel or camera driver changes.
- Base/application manifests and full-update SHA256 for provenance/verification.

The updater chooses the inactive slot for a full update. Use the standard
partition layout: 100 MiB OHD and 64 MiB A/B boot/rootfs. ImageBuilder rejects
enlarged debug layouts, writable base rootfs, saved bench settings and diagnostic
captures. Factory images use an empty writable settings directory; flashing an
OHD partition replaces its contents. Normal OpenHD startup preserves existing
settings rather than resetting them.

The camera source changes are in the primary native `master` branches.
OpenHD uses `openhd-3.0`; QOpenHD uses `dev-release`. Public camera naming is
`arducam_openhd`. Detailed hardware documentation and raw provisioning payloads
are maintained privately by the product build.

Packaging checks run with:

```sh
python3 -m unittest discover -s scripts/tests -p test_x21_production.py -v
```

They exercise both A/B update choices, actual CPIO extraction and checksums,
fresh base images, wrong-SDK rejection and exclusion of bench state. A completed
image build does not replace a physical flash-and-boot validation on the board.
