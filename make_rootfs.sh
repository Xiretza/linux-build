#!/bin/bash

set -xue

export LC_ALL=C

BUILD="build"
OTHERDIR="otherfiles"
DEST="$1"
OUT_TARBALL="$2"
DEVICE=$3
FLAVOUR=$4

PACKAGES_BASE=(
	dosfstools curl xz iw rfkill netctl dialog wpa_supplicant pv networkmanager sudo
	f2fs-tools btrfs-progs zramswap
)
PACKAGES_UI=(
	mesa-git danctnix-phosh-ui-meta xdg-user-dirs noto-fonts-emoji gst-plugins-good
	lollypop gedit evince-mobile mobile-config-firefox gnome-calculator gnome-clocks
	gnome-maps megapixels gnome-usage-mobile gtherm geary-mobile purple-matrix
	purple-telegram portfolio-fm chatty kgx gnome-software-mobile gnome-contacts-mobile
	gnome-initial-setup-mobile
)
POST_INSTALL=()

if [ -z "$DEST" ] || [ -z "$OUT_TARBALL" ] || [ -z "$DEVICE" ] || [ -z "$FLAVOUR" ]; then
	echo "Usage: $0 <destination-folder> <destination-tarball> <device> <build flavour>"
	exit 1
fi

case "$DEVICE" in
	pinephone)
		PACKAGES_BASE+=(device-pine64-pinephone)
		PACKAGES_UI+=(calls)
		POST_INSTALL+=(
			"systemctl enable eg25_power"
			"systemctl enable eg25_audio_routing"
		)
		;;
	pinetab)
		PACKAGES_BASE+=(device-pine64-pinetab)
		;;
	*)
		echo "Unknown device: $DEVICE"
		exit 1
esac

case "$FLAVOUR" in
	phosh)
		PACKAGES_BASE+=(bootsplash-theme-danctnix v4l-utils)
		PACKAGES=("${PACKAGES_BASE[@]}" "${PACKAGES_UI[@]}")
		POST_INSTALL+=(
			"systemctl enable bluetooth"
			"systemctl enable phosh"
			"systemctl disable sshd"
		)
		if [[ $DEVICE = pinephone ]]; then
			POST_INSTALL+=("systemctl enable ModemManager")
		fi;
		;;
	barebone)
		PACKAGES_BASE+=(danctnix-usb-tethering dhcp)
		PACKAGES=("${PACKAGES_BASE[@]}")
		POST_INSTALL+=(
			"systemctl enable usb-tethering"
			"systemctl enable dhcpd4"
		)
		;;
	lambda)
		PACKAGES_BASE+=(
			v4l-utils danctnix-usb-tethering dhcp termite-terminfo fish vim man-db man-pages
		)
		PACKAGES=("${PACKAGES_BASE[@]}" "${PACKAGES_UI[@]}")
		POST_INSTALL+=(
			"systemctl enable usb-tethering"
			"systemctl enable dhcpd4"
			"systemctl enable bluetooth"
			"systemctl enable phosh"
		)
		if [[ $DEVICE = pinephone ]]; then
			POST_INSTALL+=("systemctl enable ModemManager")
		fi;
		;;
	*)
		echo "Unknown build flavour: $FLAVOUR"
		exit 1
esac

if [ "$EUID" -ne "0" ]; then
	echo "This script requires root."
	exit 1
fi

DEST=$(readlink --canonicalize "$DEST")

if [ ! -d "$DEST" ]; then
	mkdir -p "$DEST"
fi

if [ "$(ls -A -Ilost+found "$DEST")" ]; then
	echo "Destination $DEST is not empty. Aborting."
	exit 1
fi

source secrets

try_waiting() {
	for _ in {1..3}; do
		if "$@"; then
			rc=$?
			break
		else
			rc=$?
			sleep 1
		fi
	done
	return $rc
}

TEMP=$(mktemp --directory)
cleanup() {
	mountpoint --quiet "$DEST" && try_waiting umount --recursive "$DEST"
	if [ -d "$TEMP" ]; then
		rm -rf "$TEMP"
	fi
}
trap cleanup EXIT

ROOTFS="http://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
mkdir -p "$BUILD"
TARBALL="$BUILD/$(basename "$ROOTFS")"

wget --output-document="$TARBALL" "$ROOTFS"

# Extract with BSD tar
echo -n "Extracting ... "
bsdtar -xpf "$TARBALL" -C "$DEST"
echo "OK"

# Add qemu emulation.
cp /usr/bin/qemu-aarch64-static "$DEST/usr/bin"
cp /usr/bin/qemu-arm-static "$DEST/usr/bin"

HOST_CACHE=$(pacconf CacheDir)
GUEST_CACHE=$(pacconf --config="$DEST/etc/pacman.conf" CacheDir)

do_chroot() {
	mount -o bind "$DEST" "$DEST"

	mount -o bind /tmp "$DEST/tmp"
	mount -o bind /dev "$DEST/dev"
	chroot "$DEST" mount -t proc proc /proc
	chroot "$DEST" mount -t sysfs sys /sys

	if [[ -d $HOST_CACHE ]]; then
		mount -o bind "$HOST_CACHE" "$DEST/$GUEST_CACHE"
	fi

	chroot "$DEST" "$@"
	try_waiting umount --recursive "$DEST"
}

mv "$DEST/etc/resolv.conf" "$DEST/etc/resolv.conf.dist"
cp /etc/resolv.conf "$DEST/etc/resolv.conf"

cat "$OTHERDIR/pacman.conf" > "$DEST/etc/pacman.conf"

if [[ $FLAVOUR = barebone ]]; then
	# Barebone doesn't need more than en_US.
	echo "en_US.UTF-8 UTF-8" > "$DEST/etc/locale.gen-all"
else
	cp "$OTHERDIR/locale.gen" "$DEST/etc/locale.gen-all"
fi

mv "$DEST/etc/pacman.d/mirrorlist" "$DEST/etc/pacman.d/mirrorlist.default"

echo "Server = http://sg.mirror.archlinuxarm.org/\$arch/\$repo" > "$DEST/etc/pacman.d/mirrorlist"

echo "pinus" > "$DEST/etc/hostname"

systemd-machine-id-setup --root="$DEST"

OIFS=$IFS IFS=$'\n'
postinstall_cmds=${POST_INSTALL[*]}
IFS=$OIFS

cat > "$DEST/second-phase" <<EOF
#!/bin/sh
set -xue
pacman-key --init
pacman-key --populate archlinuxarm
killall -KILL gpg-agent
pacman -Rsn --noconfirm linux-aarch64
pacman -Syu --noconfirm
pacman -S --noconfirm --disable-download-timeout --needed ${PACKAGES[*]}

pacman -Fy

systemctl disable systemd-networkd
systemctl disable systemd-resolved

systemctl enable zramswap
systemctl enable NetworkManager

$postinstall_cmds

sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

cp /etc/locale.gen-all /etc/locale.gen
cd /usr/share/i18n/charmaps
# locale-gen can't spawn gzip when running under qemu-user, so ungzip charmap before running it
# and then gzip it back
gzip -d UTF-8.gz
locale-gen
gzip UTF-8
echo "LANG=en_US.UTF-8" > /etc/locale.conf
umount --quiet $(printf '%q' "$GUEST_CACHE")
pacman -Scc --noconfirm

userdel --remove alarm
groupadd --gid 1000 lambda
useradd \
	--create-home \
	--groups=network,video,audio,optical,storage,input,scanner,games,lp,rfkill,wheel \
	--uid=1000 \
	--gid=1000 \
	lambda
chsh --shell=/usr/bin/fish lambda

echo "lambda:$PASSWORD" | chpasswd
EOF
chmod +x "$DEST/second-phase"
do_chroot /second-phase
rm "$DEST/second-phase"

install --owner=1000 --group=1000 -dm700 "$DEST/home/lambda/.ssh"
install --owner=1000 --group=1000 -m600 -t "$DEST/home/lambda/.ssh" "$OTHERDIR/authorized_keys"

# Final touches
rm "$DEST/usr/bin/qemu-aarch64-static"
rm "$DEST/usr/bin/qemu-arm-static"
rm "$DEST/etc/locale.gen-all"
rm -f "$DEST"/*.core
rm "$DEST/etc/resolv.conf.dist" "$DEST/etc/resolv.conf"
touch "$DEST/etc/resolv.conf"

rm "$DEST/etc/pacman.d/mirrorlist"
mv "$DEST/etc/pacman.d/mirrorlist.default" "$DEST/etc/pacman.d/mirrorlist"

cp "$OTHERDIR/first_time_setup.sh" "$DEST/usr/local/sbin/"
cp "$OTHERDIR/81-blueman.rules" "$DEST/etc/polkit-1/rules.d/"

cp -r "$OTHERDIR"/systemd/* "$DEST/usr/lib/systemd/"

install -Dm644 /dev/stdin "$DEST/etc/gtk-3.0/settings.ini" <<END
[Settings]
gtk-application-prefer-dark-theme=1
END

do_chroot /usr/bin/glib-compile-schemas /usr/share/glib-2.0/schemas

# Replace Arch's with our own mkinitcpio
cp "$OTHERDIR/mkinitcpio.conf" "$DEST/etc/mkinitcpio.conf"

if [[ ${PACKAGES[*]} != *bootsplash-theme-danctnix* ]]; then
	sed -i 's/bootsplash-danctnix//g' "$DEST/etc/mkinitcpio.conf"
fi

do_chroot mkinitcpio -p linux-pine64

echo "Installed rootfs to $DEST"

# Create tarball with BSD tar
echo -n "Creating tarball ... "
bsdtar --cd "$DEST" --preserve-permissions --create --gzip --file "../$OUT_TARBALL" .
rm -rf "$DEST"

echo "Done"
