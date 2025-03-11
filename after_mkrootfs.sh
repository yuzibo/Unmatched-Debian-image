#!/bin/bash
#
after_mkrootfs()
{
    cat << EOF > "${ROOTFS_POINT}"/etc/network/interfaces
auto lo
iface lo inet loopback

auto end0
iface end0 inet dhcp
EOF

    chroot ${ROOTFS_POINT} sh -c "chmod 0666 /dev/null"
    chroot "${ROOTFS_POINT}" sh -c "echo 'unmatched' > /etc/hostname"
    chroot "${ROOTFS_POINT}" sh -c "echo '127.0.0.1	localhost unmatched' > /etc/hosts"

    # # update-initramfs -u
    chroot "${ROOTFS_POINT}" sh -c "rm /boot/initrd*"
    chroot "${ROOTFS_POINT}" sh -c "update-initramfs -c -k all"
    
    # Set up fstab
    cat << EOF > ${ROOTFS_POINT}/etc/fstab 
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/nvme0n1p4 /               ext4    errors=remount-ro 0       1
/dev/nvme0n1p3 /boot           ext4    nodev,noexec,rw   0       2
EOF
   
    ## Add needed modules in initrd
    chroot "${ROOTFS_POINT}" sh -c "echo "nvme" >> /etc/initramfs-tools/modules"

    chroot "${ROOTFS_POINT}" sh -c "cp /usr/lib/linux-image-*/sifive/hifive-unmatched-a00.dtb /boot/"
    chroot "${ROOTFS_POINT}" sh -c "echo U_BOOT_FDT=\"hifive-unmatched-a00.dtb\" >> /etc/default/u-boot"
    chroot "${ROOTFS_POINT}" sh -c "echo 'U_BOOT_PARAMETERS=\"rw rootwait console=ttySIF0,115200 earlycon\"' >> /etc/default/u-boot"
    chroot "${ROOTFS_POINT}" sh -c "echo 'U_BOOT_ROOT=\"root=/dev/nvme0n1p4\"' >> /etc/default/u-boot"

    chroot "${ROOTFS_POINT}" sh -c "u-boot-update"

}
