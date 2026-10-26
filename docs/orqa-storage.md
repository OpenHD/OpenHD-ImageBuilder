# ORQA Air/Ground storage

New ORQA flash bundles include a FAT32 configuration volume labelled `openhd`
and a FAT32 recording volume labelled `recordings`. They mount at `/Config`
and `/Video`; `/Videos` is a compatibility alias. Both filesystems are readable
and writable by Windows when the eMMC is exposed as a disk (for example by
a supported USB mass-storage mode or reader). Adding partitions does not by
itself expose the board's soldered eMMC to Windows over USB.

The first four vendor partitions (`kernel`, `recovery`, `nvram`, `rootfs`)
keep their exact indices, offsets and GUIDs. The original `data` extent is
split into a 128 MiB ext4 `data` partition, a 128 MiB FAT32 `config` partition,
and a FAT32 `recordings` partition using the remaining space. The GPT checksums
are regenerated. The generated UUU script initializes these three volumes
when flashing the image. **This is a fresh-flash layout: flashing it replaces
the old data partition and recordings. It is not an in-place upgrade.**

To select Ground mode from Windows, create an empty `openhd/ground.txt` file
on the `openhd` volume. To select Air mode, create `openhd/air.txt`. Keep only
one role marker. SysUtils consumes the marker at boot and persists the mode.
The default remains Air. `settings.json` at the volume root, or
`openhd/settings.json`, uses the standard SysUtils configuration schema.
The volume includes a README and example marker filenames which do not change
the mode until renamed. Safely eject storage before disconnecting it.

QOpenHD and its independent GL compositor are installed for Ground mode, with
SysUtils owning their startup. Air mode does not automatically start the UI.
The recording partition provides storage; a video backend must separately
implement and enable recording. In particular, creating this volume does not
add recording support to the native NXP encoder. FAT32 limits a single file
to 4 GiB. Actual NXP boot, Windows mounting and physical recording still need
verification on a freshly flashed board.
