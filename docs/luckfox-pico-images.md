# Complete Pico images

The `New_Image_Workflow` builds all six Pico board/storage combinations on a
normal development image build or when dispatched with `target=luckfox`:
Zero, Ultra W and Ultra eMMC; Pro/Max, Plus and Mini SD card.

The job calls the canonical `OpenHD/luckfox-pico-sdk` image builder. It resolves
the current Pico SDK `main`, OpenHD `openhd-3.0` and SysUtils `dev-release` once
for the matrix. Devourer is built from the submodule revision selected by that
OpenHD commit. Buildroot builds both applications and their runtime libraries
for each board. WebUI is neither fetched nor installed.

Checks require both applications, their startup scripts, Devourer discovery,
radio configuration, the runtime dependency closure and working kernel support
for USB maintenance. Legacy broadcast kernel drivers and WebUI files fail the
image check. `/etc/openhd-image-components.json` records the source commits,
base identity and application/library checksums inside the root filesystem;
the same manifest accompanies the downloadable artifact.

Each `openhd-image-luckfox-pico-*` artifact contains a raw `.img.xz`. The three
eMMC artifacts also include a self-contained `firmware.zip` for ImageWriter's
Rockchip USB page. SD targets use the disk/card writer path. Component manifests,
checksums and paired `.pico-ohd` application updates use separate
`openhd-components-luckfox-pico-*` artifacts, so SD writing cannot accidentally
select an application update as a disk image. The base SDK images remain
separate from these images with applications installed.

Aura and Lyra use different hardware/SDK families and are outside this Pico
matrix. The historical embedded-base aliases for them are not substitutes for
this builder.
