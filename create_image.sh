#!/bin/bash

set -ex

# It woule be good to test it outside of Docker
OUT_DIR="$1"

ROOTFS_IMG="nvme-rootfs.img"
U_BOOT_IMG="sd-uboot.img"
NVME_ROOTFS_IMG="${OUT_DIR}/${ROOTFS_IMG}"
SD_UBOOT_IMG="${OUT_DIR}/${U_BOOT_IMG}"
SD_DD_OPTS="bs=4k iflag=fullblock oflag=direct conv=fsync status=progress"
PACKAGES_LIST="sudo openssh-server openntpd"

source $(pwd)/after_mkrootfs.sh

if [ -f ${NVME_ROOTFS_IMG} ]; then
    echo "deleting nvme rootfs image..."
    rm ${NVME_ROOTFS_IMG}
fi

echo "Creating Blank nvme rootfs Image ${NVME_ROOTFS_IMG}"

# allocate 3G space for image
dd if=/dev/zero of="${NVME_ROOTFS_IMG}" bs=1M count=3072

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

# rv64-port from mmdebstrap
cp -a /builder/rv64-port/* "${ROOTFS_POINT}"

mount -t proc /proc "${ROOTFS_POINT}/proc"
mount -t sysfs /sys "${ROOTFS_POINT}/sys"
mount -o bind /dev "${ROOTFS_POINT}/dev"

# install packages
chroot "${ROOTFS_POINT}" sh -c "export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true; apt update"
chroot "${ROOTFS_POINT}" sh -c "export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true; apt install ${PACKAGES_LIST} -y"

# save spl and itb file for u-boot
cp ${ROOTFS_POINT}/usr/lib/u-boot/sifive_unmatched/u-boot-spl.bin ./u-boot-spl.bin
cp ${ROOTFS_POINT}/usr/lib/u-boot/sifive_unmatched/u-boot.itb ./u-boot.itb

# need improve here also, we do not need another script
after_mkrootfs

# rv:rv
chroot "${ROOTFS_POINT}" sh -c "useradd -m -s /bin/bash -G adm,cdrom,floppy,sudo,input,audio,dip,video,plugdev,netdev rv"
chroot "${ROOTFS_POINT}" sh -c "echo 'rv:rv' | chpasswd"

# root: unmatched
ROOT_PASSWORD_HASH="$(echo 'unmatched' | openssl passwd -1 -stdin)"
chroot "${ROOTFS_POINT}" sh -c "usermod --password '$ROOT_WORD_HASH' root"
#chroot "${ROOTFS_POINT}" sh -c "usermod --password "$(echo 'unmatched' | openssl passwd -1 -stdin)" root"

rm -v "${ROOTFS_POINT}"/etc/ssh/ssh_host_*
chroot "${ROOTFS_POINT}" sh -c "apt clean" 
rm -r "${ROOTFS_POINT}"/var/lib/apt/lists/*

sed -i 's/^DAEMON_OPTS="/DAEMON_OPTS="-s /' "${ROOTFS_POINT}"/etc/default/openntpd

umount "${ROOTFS_POINT}/proc"
umount "${ROOTFS_POINT}/sys"
umount "${ROOTFS_POINT}/dev"


umount "${ROOTFS_POINT}" 

kpartx -d ${NVME_ROOTFS_IMG}

echo "Creating Blank sd uboot Image ${SD_UBOOT_IMG}"
dd if=/dev/zero of="${SD_UBOOT_IMG}" bs=1M count=6

sgdisk -g --clear --set-alignment=1 \
       --new=1:34:+1M:    --change-name=1:'u-boot-spl'    --typecode=1:5b193300-fc78-40cd-8002-e86c45580b47 \
       --new=2:2082:+4M:  --change-name=2:'opensbi-uboot' --typecode=2:2e54b353-1271-4842-806f-e436d6af6985 \
       ${SD_UBOOT_IMG} 

# text=$(kpartx -av "${SD_UBOOT_IMG}")
#echo "${text}"
SD_LOOPDEV=$(kpartx -av "${SD_UBOOT_IMG}"| awk '{print $3}' | awk 'NR==1 {print $1}'| awk -F 'p' '{print $2}')
echo "sd ${SD_LOOPDEV}"

# need review this
dd if=./u-boot-spl.bin of="/dev/mapper/loop${SD_LOOPDEV}p1" ${SD_DD_OPTS}

dd if=./u-boot.itb of="/dev/mapper/loop${SD_LOOPDEV}p2" ${SD_DD_OPTS}

kpartx -d ${SD_UBOOT_IMG}

echo "Finishing sd u-boot image"

# Now compress the image
echo "Compressing the image: ${NVME_ROOTFS_IMG}"

(cd "${OUT_DIR}" && xz -T0 "${NVME_ROOTFS_IMG}")

echo "Compressing the image: ${SD_ROOTFS_IMG}"

(cd "${OUT_DIR}" && xz -T0 "${SD_ROOTFS_IMG}")

echo "Finishing the image..."
