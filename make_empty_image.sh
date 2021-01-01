#!/bin/sh

set -x 
set -e

IMAGE_NAME="$1"
IMAGE_SIZE="$2"

if [ -z "$IMAGE_NAME" ] || [ -z "$IMAGE_SIZE" ]; then
	echo "Usage: $0 <image name>"
	exit 1
fi

if [ "$(id -u)" -ne "0" ]; then
	echo "This script requires root (not really - but make_image.sh will fail later without root)"
	exit 1
fi

fallocate -l "$IMAGE_SIZE" "$IMAGE_NAME"

sfdisk "$IMAGE_NAME" <<EOF
label: dos
start=2048, size=+128M, type=c, bootable
type=83
EOF
