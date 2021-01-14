#!/bin/bash

[[ "$UID" != 0 ]] && exit 92

CHROOT_DIR="$1"
BUILD_DIR="$2"
ID="$3"
USER="$4"
ARGS=("${@:5}")

mount_bind(){
    [[ `mount` =~ "$2" ]] || mount --bind "$1" "$2"
}

mount_all(){
    mount_bind "$CHROOT_DIR" "$CHROOT_DIR"
    mount_bind "$BUILD_DIR" "$CHROOT_DIR/mnt"
}

umount_all(){
    umount "${CHROOT_DIR}/mnt" 2>/dev/null
    umount "$CHROOT_DIR" 2>/dev/null
}

mount_all
trap "unmount_all" INT
if [[ ! `arch-chroot "$1" /usr/bin/cat /etc/passwd` =~ "$ID" ]]; then
    arch-chroot "$CHROOT_DIR" env ID="$ID" bash -c 'useradd -mu "${ID}" "$USER"; passwd "$USER"'
fi
arch-chroot -u "$ID" "$CHROOT_DIR" "${ARGS[@]}"
umount_all
trap - INT
exit 0