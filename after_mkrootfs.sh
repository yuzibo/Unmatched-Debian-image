#!/bin/bash
#
after_mkrootfs()
{
    chroot "${ROOTFS_POINT}" sh -c "apt update"
    #rm "${ROOTFS_POINT}/setup_rootfs.sh" "${ROOTFS_POINT}/usr/bin/qemu-riscv64-static"
    cat << EOF > "${ROOTFS_POINT}"/etc/network/interfaces
auto lo
iface lo inet loopback

auto end0
iface end0 inet dhcp
EOF

    chroot "${ROOTFS_POINT}" sh -c "useradd -m -s /bin/bash -G adm,cdrom,floppy,sudo,input,audio,dip,video,plugdev,netdev rv"
    #chroot "${ROOTFS_POINT}" sh -c "echo 'rv:rv' | chpasswd"

    # Set password to 'rv'
    chroot "${ROOTFS_POINT}" sh -c "usermod --password "$(echo rv | openssl passwd -1 -stdin)" rv"

    # # update-initramfs -u
    chroot "${ROOTFS_POINT}" sh -c "rm /boot/initrd*"
    chroot "${ROOTFS_POINT}" sh -c "update-initramfs -c -k all"
    
    # Set up fstab
    cat << EOF > ${ROOTFS_POINT}/etc/fstab 
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/nvme0n1p1 /               ext4    errors=remount-ro 0       1
EOF
   
    ## Add needed modules in initrd
    chroot "${ROOTFS_POINT}" sh -c "echo "nvme" >> /etc/initramfs-tools/modules"

    chroot "${ROOTFS_POINT}" sh -c "cp /usr/lib/linux-image-*/sifive/hifive-unmatched-a00.dtb /boot/"
    chroot "${ROOTFS_POINT}" sh -c "echo U_BOOT_FDT=\"hifive-unmatched-a00.dtb\" >> /etc/default/u-boot"
    chroot "${ROOTFS_POINT}" sh -c "echo U_BOOT_PARAMETERS=\"rw rootwait console=ttySIF0,115200 earlycon\" >> /etc/default/u-boot"

    chroot "${ROOTFS_POINT}" sh -c "u-boot-update"

}
