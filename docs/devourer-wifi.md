# Broadcast radio drivers in images

Current OpenHD images use Devourer/libusb for supported Realtek broadcast USB
adapters. ImageBuilder no longer installs the separate AU/BU/CU/EU driver
packages in Lite board profiles or the minimal x86 image.

Fresh-image package installation and both update modes run
`additionalFiles/prepare-devourer-image.sh`. It purges installed legacy broadcast
driver packages, removes their named modules even when bundled in a kernel
package, refreshes module dependencies and existing initramfs files, and writes
a persistent modprobe policy. That policy prevents a later kernel package update
from reintroducing competing driver initialization. The script never unloads
host drivers or resets USB hardware; it runs inside the image chroot.

Cleanup targets AU/BU/CU/EU and 8852BU USB drivers, including their matching
in-tree USB implementations. It retains shared wireless modules, onboard/PCI
drivers, firmware and networking tools needed for hotspot/client connectivity.
The old x86 cleanup that deleted complete Realtek/rtw88 directories is replaced
by this module-specific policy.

X20 follows the same policy: its AU package and forced module load are removed.
The Luckfox Buildroot recipe now pins OpenHD 3.0 and the matching Devourer source;
the SDK builder disables vendor USB driver configuration instead of cloning EU.
The desktop x86 installer no longer clones or installs AU/BU DKMS drivers.
X21 update packaging removes its EU module and startup insmod command.
Image preparation rejects OpenHD packages without the Devourer backend before
removing any installed driver package.

The SysUtils EU ownership fix is also needed for upgrades of existing installed
systems; ImageBuilder cleanup affects newly generated images. Neither change
proves that every USB disconnect has the same cause.

Run `bash scripts/tests/test_devourer_image.sh` to verify package selection,
compressed-module removal, usrmerge handling, retained onboard/PCI drivers,
idempotence and X20 coverage. A full image build and boot are separate
release checks.
