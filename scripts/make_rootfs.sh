#!/bin/bash

echo "execute make_rootfs"

echo "the args is $1"

make_rootfs_tarball()
{
    echo "here in \n"
    echo "the args is $1 from mkrootfs.sh"
    # use $1
    #PACKAGE_LIST="$KEYRINGS $GPU_DRIVER $BASE_TOOLS $GRAPHIC_TOOLS $XFCE_DESKTOP $BENCHMARK_TOOLS $FONTS $INCLUDE_APPS $EXTRA_TOOLS $LIBREOFFICE"
    PACKAGE_LIST="$KEYRINGS $BASE_TOOLS $BENCHMARK_TOOLS $EXTRA_TOOLS"
    #debootstrap --arch=riscv64 --no-check-gpg --keyring /usr/share/keyrings/debian-archive-keyring.gpg \
    #    --include="$PACKAGE_LIST" \
    #    unstable /tmp/riscv64-chroot \
    #    "https://deb.debian.org/debian sid main contrib non-free non-free-firmware"
    mmdebstrap --architectures=riscv64 --skip=check/empty \
        --include="$PACKAGE_LIST" \
        testing $1 \
        "deb https://deb.debian.org/debian testing main contrib non-free non-free-firmware"

    if [[ $? == 0 ]]; then
	    echo "mmdebstrap is okay"
	    return 0
    fi
}

make_rootfs()
{
    if [[ -z "$USE_TARBALL" ]]; then
        echo "env USE_TARBALL is set to the empty string!"
        echo "create rootfs"
        make_rootfs_tarball $CHROOT_TARGET
    else
	echo "here make_rootfs "
        tar xpvf $USE_TARBALL --xattrs-include='*.*' --numeric-owner -C $CHROOT_TARGET
    fi
    
    echo "execute make_rootfs next "
    # move /boot contents to other place
    if [ ! -z "$(ls -A "$CHROOT_TARGET"/boot/)" ]; then
        mkdir "$CHROOT_TARGET"/mnt/boot
        mv -v "$CHROOT_TARGET"/boot/* "$CHROOT_TARGET"/mnt/boot/
    fi
    
    echo "before execute ..."

    # Mount chroot path
    mount "$BOOT_IMG" "$CHROOT_TARGET"/boot
    mount -t proc /proc "$CHROOT_TARGET"/proc
    mount -B /sys "$CHROOT_TARGET"/sys
    mount -B /run "$CHROOT_TARGET"/run
    mount -B /dev "$CHROOT_TARGET"/dev
    mount -B /dev/pts "$CHROOT_TARGET"/dev/pts
    mount -t tmpfs tmpfs "$CHROOT_TARGET"/tmp
    mount -t tmpfs tmpfs "$CHROOT_TARGET"/var/tmp
    mount -t tmpfs tmpfs "$CHROOT_TARGET"/var/cache/apt/archives/

    # move boot contents back to /boot
    if [ ! -z "$(ls -A "$CHROOT_TARGET"/mnt/boot/)" ]; then
        mv -v "$CHROOT_TARGET"/mnt/boot/* "$CHROOT_TARGET"/boot/
        rmdir "$CHROOT_TARGET"/mnt/boot
    fi

    # apt update
    chroot "$CHROOT_TARGET" sh -c "apt update"
}
