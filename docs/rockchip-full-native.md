# Full Rockchip images: native display and silent startup

Full ROCK 5 and ROCK 3 family recipes now select the native QOpenHD packages:

| Image family | Package | Native graphics selection |
| --- | --- | --- |
| ROCK 5A/5B and the existing CM5 full recipe | `qopenhd-native-rk3588` | Matching G610 Mali DDK, or image-provided Mesa |
| ROCK 3A, ZERO 3W, CM3/core3566 full recipes | `qopenhd-native-rk3566` | Matching G52 Mali DDK, or image-provided Mesa |

The full matrix currently builds ROCK 5A, ROCK 5B, ROCK 3A and ZERO 3W.
Other existing full recipes use the same family selection when built manually.
This change does not invent base images for additional board models.

Both QOpenHD cross-package jobs (Bullseye and Bookworm) build with
`CONFIG+=rockchip_native`. They build the pinned canonical MPP SDK for linking
and produce the two family-specific native packages. The payload contains
native AVC/HEVC decode, the independent Wayland primary presenter, secondary
EGL video, the embedded startup movie, EGL compatibility adapter, shared early
framebuffer splash and service templates. No Hantro libraries, NXP compositor
patch, FFmpeg or GStreamer decoder is linked into native QOpenHD.

`install-current-components.sh` remains the component-selection entry point
for fresh and cached full builds. It installs the newest native family package
from the selected channel, then runs `configure-rockchip-native.sh`. The helper
refuses old/incomplete QOpenHD payloads or SysUtils binaries without native
support. This keeps images from silently falling back to fpvue/Glide while
new component packages are still waiting to be published.

The helper reads the image's installed Mali package, selects the corresponding
G52/G610 and DDK version, downloads the pinned Wayland library, verifies its
SHA256 and retains the upstream license/provenance. Private EGL/GBM libraries
stay under the QOpenHD runtime. A Mesa image keeps its own graphics stack;
unknown proprietary drivers fail instead of receiving a guessed GPU/DDK.

The startup sequence is:

1. Quiet kernel/systemd display output while preserving root UUID, DT, initrd
   and serial-console settings. Kernel-update command-line templates receive
   the same flags where present.
2. Start the bounded framebuffer logo/dots animation early in userspace.
3. SysUtils resolves Ground/Air mode. In Ground mode it starts QOpenHD and its
   compositor dependency; Weston stops the framebuffer writer before taking
   DRM ownership.
4. Native MPP plays the same embedded startup movie, then the permanent Qt
   window reveals the HUD over independently presented live video.

The configuration selects `multi-user.target`, disables desktop managers and
the legacy display services, and masks the competing tty1/Plymouth splash.
SysUtils remains the Ground/Air owner; QOpenHD/compositor units are not enabled
unconditionally. Their service condition also rejects configured Air/Record.
Only the early, bounded logo and OpenHD/SysUtils units are enabled in the image.
`/etc/qopenhd-rockchip/native-video-enabled` is the full-image contract used by
SysUtils to suppress fpvue and override its old Bookworm/CM5 Glide preference.

Regular and experimental Lite workflow jobs, the Lite dispatch option and all
six Lite image recipes are removed. Previously published images are unaffected.
The native image helper still rejects `OPENHD_LITE_IMAGE=true` for compatibility
with older or external recipes. Raspberry Pi OS Lite base downloads remain the
bases of the full Raspberry Pi images.

Local validation covers actual native Debian payload contents/dependencies,
fresh/missing-package image fixtures, repeated configuration, full/Lite
selection, boot argument preservation, role gating, driver selection and
SysUtils compilation/CTest. The MPP SDK cross-build was checked as AArch64.
The ROCK 5A live native path was physically confirmed with Big Buck Bunny in
the preceding bring-up. This rollout has not yet completed new whole-image
CI, cold boots on each board, or a new physical ROCK 3 test. U-Boot/preloader
output is not modified by flashing or rewriting the bootloader.

## Bullseye package compatibility correction

The ROCK 5A deployment test caught two differences from the prototype:
Bullseye dpkg requires XZ rather than Ubuntu default zstd package compression,
and Weston 9 stock kiosk shell hardcodes grey. Native Bullseye packages now
include an ABI-matched black kiosk module built from verified Weston 9 source,
with its license and provenance. Weston 10 uses the configured black
background color. Compositor-only scanout on the ROCK 5A was verified as entirely
black. Reboot and physical handoff acceptance remain separate from that capture.

## Building the integration

Build and publish the matching QOpenHD and SysUtils component packages to the
selected component channel before starting ImageBuilder. In QOpenHD, both
`rock-bullseye-arm64` and `rock-bookworm-arm64` cross-package targets produce
the native RK3566 and RK3588 packages. SysUtils must include the
`rockchip_native` marker support. An image build intentionally fails if its
channel still serves an older component package.

Run the full image workflow target, or build individual boards from the
ImageBuilder directory with `sudo ./build.sh rock5a false false true`, replacing
`rock5a` with `rock5b`, `radxa-rock3a` or `radxa-zero3w` as needed. The final
`true` uses the existing full-image base recipe and installs current components.

The ROCK 5A warm-reboot issue remains unresolved: one reboot returned by itself,
while a subsequent measured attempt was unreachable for several minutes. No
kernel or bootloader workaround is included in this display integration.
