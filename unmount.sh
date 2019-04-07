#!/bin/bash

# apt dependencies: qemu qemu-user-static binfmt-support

set -e
set -o xtrace

DATA_DIR="$PWD/work/02-Kernel"
MNT_DIR="$DATA_DIR/mnt"

function unmount {
	sudo umount -l "$MNT_DIR/sys" || true
	sudo umount -l "$MNT_DIR/proc" || true
	sudo umount -l "$MNT_DIR/dev/pts" || true
	sudo umount -l "$MNT_DIR/dev" || true

	sudo umount -l "$MNT_DIR/boot" || true
	sudo umount -l "$MNT_DIR/etc/resolv.conf" || true
	sudo umount -l "$MNT_DIR" || true
	sudo umount -l "$MNT_DIR/var/cache" || true
}

unmount
