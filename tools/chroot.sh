#!/bin/bash

[[ "$UID" != 0 ]] && exit 92

CHROOT_DIR="$1"
BUILD_DIR="$2"
ID="$3"
ARGS=("${@:4}")

mount_bind(){
    [[ `mount` =~ "$2" ]] || mount --bind "$1" "$2"
}

mount_all(){
    mount_bind "$CHROOT_DIR" "$CHROOT_DIR"
    mount_bind "$BUILD_DIR" "$CHROOT_DIR/mnt"
}

umount_all(){
    umount "${CHROOT_DIR}/mnt"
    umount "$CHROOT_DIR"
}

mount_all
trap "unmount_all" INT
if [[ `arch-chroot "$1" /usr/bin/cat /etc/passwd` =~ "$ID" ]]; then
    arch-chroot -u "$ID" "$1" "${ARGS[@]}"
fi
umount_all
trap - INT
exit 0