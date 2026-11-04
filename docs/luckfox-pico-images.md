# Pico images from reusable bases

The normal image workflow (`target=luckfox`) assembles seven Pico targets:
Zero, Ultra W and Ultra eMMC; Pro/Max, Plus and Mini SD card; and Mini B NAND.

Board images and application builds are separate. The canonical OpenHD builder
cross-compiles current `openhd-3.0` and SysUtils `dev-release` once against the
published Pico SDK. Devourer uses the revision selected by OpenHD. The paired
archive includes the complete transitive runtime library closure and SysUtils
radio policy. WebUI is not installed. No kernel, bootloader, Buildroot or board
SDK compilation runs during this workflow.

Pico applications use the native RKAIQ and Rockit VI/VENC camera worker.
GStreamer is disabled when compiling OpenHD. Assembly rejects binaries linking
GStreamer or missing the Rockit/RKAIQ runtime libraries, and records the native
camera backend in the embedded component manifest.

The assembler downloads the existing verified board base, mounts its ext4 root
partition, and replaces application files, libraries and startup scripts. It
checks ARM ELF dependencies, Devourer discovery, radio configuration, checksums
and absence of WebUI/legacy broadcast drivers. Every byte outside rootfs must
remain unchanged, including the bootloader, kernel, OEM files and both GPTs.
Source commits, base checksum and installed runtime checksums are recorded in
`/etc/openhd-image-components.json` and the companion artifact.

Published bases are reused from Cloudsmith. On the first assembly the newest
successful complete six-board SDK base build seeds these permanent files from
its verified GitHub artifacts. Board support changes require an explicit new
base build and publication; application updates do not rebuild the base.

Each `openhd-image-luckfox-pico-*` artifact contains a raw `.img.xz`. eMMC targets
also include `firmware.zip` containing the matching base loader and the updated
complete disk for ImageWriter's Rockchip USB page. SD image artifacts contain
only the disk image, because ImageWriter streams the first artifact entry.
Manifests, checksums and paired `.pico-ohd` application slot updates live in
separate `openhd-components-luckfox-pico-*` artifacts. Slots update applications
and runtime libraries, not the kernel or complete operating system.

Aura and Lyra are separate families and are not part of this matrix.

## Mini B NAND

Select `luckfox-pico-mini-nand` in the normal image workflow to assemble only
the 128 MiB NAND target. It also participates in `all` and `luckfox` builds.
The SDK must first supply the corresponding reusable NAND base (see the SDK's
`docs/pico-mini-nand.md`). Existing SD Mini bases are never used for this target.

NAND assembly uses a minimal rootfs seed and preserves the base's bootloader,
kernel, OEM and userdata images byte for byte. It injects the current paired
OpenHD/SysUtils native-camera build, Devourer policies and transitive ELF library
closure, rejects GStreamer/Python/slot updates, and regenerates only rootfs as
UBI/UBIFS. Each partition is checked against the 120 MiB layout, retaining 8 MiB
outside the partitions and UBI metadata/bad-block space internally.

Its `openhd-image-luckfox-pico-mini-nand` artifact contains `firmware.zip` with
Rockchip `update.img`, matching loader and individual partitions. It has no
`.img.xz` SD image and no `.pico-ohd` application slots. Flash the complete NAND
firmware with a compatible Rockchip tool; stock offsets differ.

USB defaults to host for a radio. ImageWriter's review page offers "Enable
Ethernet link over USB" to select USB device mode instead. SysUtils applies
the provisioned choice before Wi-Fi detection. A new base advertising
`usb_role_switching` is required; older fixed-role bases are rejected.
NAND rootfs includes a 248 KiB static UBI provisioning volume; ImageWriter
preserves all application/UBIFS blocks when storing the selection. USB
Ethernet and ADB cannot share the connector with a host-mode radio.
Native MIS5001 capture defaults to 1280x720 at 60 fps.
