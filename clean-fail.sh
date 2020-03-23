#!/bin/bash


for stage in 01-Baseimage 02-Kernel 03-Packages 04-Support 05-Wifibroadcast
do
    umount work*/$stage/mnt/boot
    umount work*/$stage/mnt/dev/pts
    umount work*/$stage/mnt/dev
    umount work*/$stage/mnt/etc/resolv.conf 
    umount work*/$stage/mnt/proc
    umount work*/$stage/mnt/sys
    umount work*/$stage/mnt/
done

losetup -D
