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

cat << EOF | fdisk "$IMAGE_NAME"
o
n
p
1
2048
+128M
t
c
n
p
2


t
2
83
a
1
w
EOF
