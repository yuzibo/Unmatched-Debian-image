#!/bin/bash

# It woule be good to test it outside of Docker
OUT_DIR="$1"

ROOTFS_IMG="nvme-rootfs.img"
U_BOOT_IMG="sd-uboot.img"
NVME_ROOTFS_IMG="${OUT_DIR}/${ROOTFS_IMG}"
SD_UBOOT_IMG="${OUT_DIR}/${U_BOOT_IMG}"
SD_DD_OPTS="bs=4k iflag=fullblock oflag=direct conv=fsync status=progress"

source $(pwd)/after_mkrootfs.sh

mount_chroot_path()
{
    mount -t proc /proc "${ROOTFS_POINT}"/proc
    mount -B /sys "${ROOTFS_POINT}"/sys
    mount -B /run "${ROOTFS_POINT}"/run
    mount -B /dev "${ROOTFS_POINT}"/dev
}

if [ -f ${NVME_ROOTFS_IMG} ]; then
    echo "deleting nvme rootfs image..."
    rm ${NVME_ROOTFS_IMG}
fi

dd if=/dev/zero of="${SD_UBOOT_IMG}" bs=1M count=6

echo "Creating Blank sd uboot Image ${SD_UBOOT_IMG}"

 sgdisk -g --clear --set-alignment=1 \
       --new=1:34:+1M:    --change-name=1:'u-boot-spl'    --typecode=1:5b193300-fc78-40cd-8002-e86c45580b47 \
       --new=2:2082:+4M:  --change-name=2:'opensbi-uboot' --typecode=2:2e54b353-1271-4842-806f-e436d6af6985 \
       ${SD_UBOOT_IMG} 

# text=$(kpartx -av "${SD_UBOOT_IMG}")
#echo "${text}"
SD_LOOPDEV=$(kpartx -av "${SD_UBOOT_IMG}"| awk '{print $3}' | awk 'NR==1 {print $1}'| awk -F 'p' '{print $2}')
echo "sd ${SD_LOOPDEV}"

# need review this

dd if=/builder/rv64-port/usr/lib/u-boot/sifive_unmatched/u-boot-spl.bin of="/dev/mapper/loop${SD_LOOPDEV}p1" ${SD_DD_OPTS}

dd if=/builder/rv64-port/usr/lib/u-boot/sifive_unmatched/u-boot.itb of="/dev/mapper/loop${SD_LOOPDEV}p2" ${SD_DD_OPTS}

kpartx -d ${SD_UBOOT_IMG}

echo "Finishing sd u-boot image"

dd if=/dev/zero of="${NVME_ROOTFS_IMG}" bs=1M count=4096

echo "Creating Blank nvme rootfs Image ${NVME_ROOTFS_IMG}"

#truncate -s "${DISK_MB}M" "${NVME_ROOTFS_IMG}"

sgdisk -g --clear --set-alignment=1 \
       --new=1:34:-1   --change-name=1:'rootfs'        --typecode=1:0x0700 --attributes=3:set:2  \
       ${NVME_ROOTFS_IMG} 

#LOOPDEV=$(kpartx -av "${NVME_ROOTFS_IMG}")
#echo "print ${LOOPDEV}"
LOOPDEV=$(kpartx -av "${NVME_ROOTFS_IMG}"| awk '{print $3}')
echo "Nvme ${LOOPDEV}"

if [ -z ${LOOPDEV} ]; then
    echo "loopdev is empty"
    exit 1
fi
#LOOP="$(losetup -f --partscan --show "${NVME_ROOTFS_IMG}")"
#echo "testing ${LOOP}" 
#LOOPDEV="${LOOP}"
echo "Partitioning loopback device ${LOOPDEV}"

mkfs.ext4 -L rootfs -F "/dev/mapper/${LOOPDEV}"

# Copy Files, first the rootfs partition
echo "Mounting  partitions ${LOOPDEV}"
ROOTFS_POINT=/nvme_rootfs
mkdir -p "${ROOTFS_POINT}"

mount "/dev/mapper/${LOOPDEV}" "${ROOTFS_POINT}"

#mount ${LOOPDEV} /mnt
#mmdebstrap --architectures=riscv64 sid ${ROOTFS_POINT} https://deb.debian.org/debian
#

cp -a /builder/rv64-port/* "${ROOTFS_POINT}"

# Copy the rootfs
cp /usr/bin/qemu-riscv64-static ${ROOTFS_POINT}/usr/bin/
ls /

echo "ls the currently dir:"
ls ./
#chroot "${ROOTFS_POINT}" qemu-riscv64-static /bin/sh /setup_rootfs.sh

#mount_chroot_path

chroot "${ROOTFS_POINT}" sh -c "apt update" 

after_mkrootfs
#rm "${ROOTFS_POINT}/setup_rootfs.sh" "${ROOTFS_POINT}/usr/bin/qemu-riscv64-static"
#cat << EOF > "${ROOTFS_POINT}"/etc/network/interfaces
#auto lo
#iface lo inet loopback

#auto end0
#iface end0 inet dhcp
#EOF

#chroot "${ROOTFS_POINT}" sh -c "useradd -m -s /bin/bash -G adm,cdrom,floppy,sudo,input,audio,dip,video,plugdev,netdev,bluetooth rv"
#chroot "${ROOTFS_POINT}" sh -c "echo 'rv:rv' | chpasswd"


umount "${ROOTFS_POINT}" 

rm -rf "${ROOTFS_POINT}"

kpartx -d ${NVME_ROOTFS_IMG}

# Now compress the image
echo "Compressing the image: ${NVME_ROOTFS_IMG}"

(cd "${OUT_DIR}" && xz -T0 "${NVME_ROOTFS_IMG}")

