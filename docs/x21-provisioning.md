# X21 ImageWriter provisioning

New X21 OHD images include two UBI volumes inside the existing 100 MiB NAND
partition: application UBIFS volume `ohd` (id 0, autoresize) and a static
`openhd-provision` volume (id 1, 16 reserved 126976-byte LEBs). No NAND partition
is added or moved. Both application-only updates and repacked full firmware ZIPs
carry this layout. The factory capsule has zero files and does nothing on boot.

ImageWriter replaces the static volume's payload with the user's selected config
before using its existing Rockusb writer and whole-image readback. It does not
rebuild UBIFS. SysUtils imports the capsule under `/Config` once before normal
settings processing. Firmware assembly rejects components missing this importer.
Use a matching newly built full firmware ZIP for configuration; older firmware
without the reserved volume cannot accept this configuration path.

The wire format is specified by identical `openhdprovisioning.h` headers in
ImageWriter and SysUtils: eight-byte `OHDCFG1\0`, big-endian payload length and
standard CRC32, then a big-endian file count followed by path length, data length,
UTF-8 path and file bytes for each entry. The entire capsule must fit 1984 KiB.
Allowed files are settings, QOpenHD config, certificate, Air/Ground markers and
map files. Oversized maps fail before flashing. UBI adds its own static-volume
data/header CRCs. These checks provide integrity, not an authenticity signature.

SysUtils records a completed capsule and does not reapply consumed settings.
An application update containing the empty factory capsule preserves settings
already persisted by SysUtils. This does not turn an update into a config-only
USB editor or provide Windows disk mounting.

Validate physical NAND flashing and first boot on an X21 separately from host
tests; the matching board loader and existing NAND bad-block handling are still
required.
