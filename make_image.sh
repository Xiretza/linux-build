#!/bin/bash

set -xue

IMAGE_NAME="$1"
TARBALL="$2"
BOOTLOADER="$3"

if [ -z "$IMAGE_NAME" ] || [ -z "$TARBALL" ] || [ -z "$BOOTLOADER" ]; then
	echo "Usage: $0 <image name> <tarball> <bootloader>"
	exit 1
fi

if [ "$EUID" -ne 0 ]; then
	echo "This script requires root."
	exit 1
fi

if [[ $(swapon --show | wc -l) -gt 1 ]]; then
	echo "Error: found active swap space on host, this would end up in the image's fstab"
	exit 1
fi

echo "Attaching loop device"
LOOP_DEVICE=$(losetup --find)
losetup --partscan "$LOOP_DEVICE" "$IMAGE_NAME"

echo "Creating filesystems"
mkfs.vfat "${LOOP_DEVICE}p1"
mkfs.btrfs "${LOOP_DEVICE}p2"

TEMP_ROOT=$(mktemp -d)
mkdir -p "$TEMP_ROOT"

echo "Creating subvolumes"
mount -o subvol=/ "${LOOP_DEVICE}p2" "$TEMP_ROOT"
btrfs subvolume create "$TEMP_ROOT/@root"
mkdir -p "$TEMP_ROOT/@root/var"
btrfs subvolume create "$TEMP_ROOT/@root/var/cache"
btrfs subvolume create "$TEMP_ROOT/@home"
mkdir -p "$TEMP_ROOT/@home/lambda"
btrfs subvolume create "$TEMP_ROOT/@home/lambda/.cache"
chown 1000:1000 "$TEMP_ROOT/@home/lambda/.cache"
btrfs subvolume create "$TEMP_ROOT/_btrbk_snap"
btrfs subvolume set-default "$TEMP_ROOT/@root"
umount "$TEMP_ROOT"

echo "Mounting rootfs"
mount "${LOOP_DEVICE}p2" "$TEMP_ROOT"
mkdir -p "$TEMP_ROOT/btrfs_roots/rootfs"
mount -o subvol=/ "${LOOP_DEVICE}p2" "$TEMP_ROOT/btrfs_roots/rootfs"
mkdir -p "$TEMP_ROOT/home"
mount -o subvol=@home "${LOOP_DEVICE}p2" "$TEMP_ROOT/home"
mkdir -p "${TEMP_ROOT}/boot"
mount -o iocharset=iso8859-1 "${LOOP_DEVICE}p1" "${TEMP_ROOT}/boot"

echo "Unpacking rootfs archive"
bsdtar -xpf "$TARBALL" -C "$TEMP_ROOT" || true

echo "Installing bootloader"
dd if="$TEMP_ROOT/boot/$BOOTLOADER" of="$LOOP_DEVICE" bs=8k seek=1

echo "Generating fstab"
genfstab -U "$TEMP_ROOT" >> "${TEMP_ROOT}/etc/fstab"

echo "Unmounting rootfs"
umount -R "$TEMP_ROOT"
rm -rf "$TEMP_ROOT"

# Detach loop device
losetup -d "$LOOP_DEVICE"
