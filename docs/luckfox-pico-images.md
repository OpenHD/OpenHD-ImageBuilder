# Pico images from reusable bases

The normal image workflow (`target=luckfox`) assembles all six Pico targets:
Zero, Ultra W and Ultra eMMC; Pro/Max, Plus and Mini SD card.

Board images and application builds are separate. The canonical OpenHD builder
cross-compiles current `openhd-3.0` and SysUtils `dev-release` once against the
published Pico SDK. Devourer uses the revision selected by OpenHD. The paired
archive includes the complete transitive runtime library closure and SysUtils
radio policy. WebUI is not installed. No kernel, bootloader, Buildroot or board
SDK compilation runs during this workflow.

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
