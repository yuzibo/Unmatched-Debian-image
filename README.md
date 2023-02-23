This is a document describing how to make Debian riscv64 images run on nvme.
If you want to make the image run on sd card, please refer to [debian wiki](https://wiki.debian.org/InstallingDebianOn/SiFive/%20HiFiveUnmatched)

The host OS is Debian sid on x86.

# 0

## Ready for nvme-rootfs and sd-uboot blank image files:

```bash
sudo dd if=/dev/zero of=nvme-rootfs.img bs=1M count=4096

sudo dd if=/dev/zero of=sd-uboot.img bs=1M count=6

```

## Partition image with correct disk IDs
```bash
sudo sgdisk -g --clear --set-alignment=1 \
       --new=1:34:-1   --change-name=1:'rootfs'        --typecode=1:0x0700 --attributes=3:set:2  \
        nvme-rootfs.img

sudo sgdisk -g --clear --set-alignment=1 \
       --new=1:34:+1M:    --change-name=1:'u-boot-spl'    --typecode=1:5b193300-fc78-40cd-8002-e86c45580b47 \
       --new=2:2082:+4M:  --change-name=2:'opensbi-uboot' --typecode=2:2e54b353-1271-4842-806f-e436d6af6985 \
        sd-uboot.img
```

## Mount image in loop device
```bash
# nvme
sudo losetup --partscan --find --show nvme-rootfs.img
/dev/loop0

# sd 
sudo losetup --partscan --find --show sd-uboot.img
/dev/loop1
```

## format partitions
```bash
sudo mkfs.ext4 /dev/loop0p1
mke2fs 1.46.6 (1-Feb-2023)
Discarding device blocks: done
Creating filesystem with 1048576 4k blocks and 262144 inodes
Filesystem UUID: 95cccf61-eb81-4d1e-be76-1bd55cfa461b
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912, 819200, 884736
...
# labeled the partition
sudo e2label /dev/loop0p1 rootfs
```

Next is install debian sid+riscv-port on image

## mount root partition
```bash
sudo mount /dev/loop0  /mnt
```

## install base files
```bash
sudo apt-get install debootstrap qemu-user-static binfmt-support debian-ports-archive-keyring

sudo debootstrap --arch=riscv64 --keyring /usr/share/keyrings/debian-ports-archive-keyring.gpg --include=debian-ports-archive-keyring,ca-certificates  unstable /mnt http://deb.debian.org/debian-ports
```

## chroot into base filesystem and made basic configuration
```bash
sudo chroot /mnt
```

The next operation is in the chroot created above.

### basic configuration
```bash
apt update

# Set up basic networking
cat >>/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Set root passwd, here is 'sifive'
passwd
New password:
Retype new password:
passwd: password updated successfully

# Set hostname
echo unmatched > /etc/hostname

# Set up fstab
root@dev:/# cat > /etc/fstab <<EOF
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/nvme0n1p1 /               ext4    errors=remount-ro 0       1
EOF

# Install kernel and bootloader infrastructure
apt-get install linux-image-riscv64 u-boot-menu u-boot-sifive
apt-get clean

# add needed modules in initrd
echo "nvme" >> /etc/initramfs-tools/modules

# update-initramfs -u
rm /boot/initrd*
update-initramfs -c -k all

# cp your latest dtb file,e.g, cp /usr/lib/linux-image-xx-riscv64
# need you confirm it here
cp /usr/lib/linux-image-xx-riscv64/sifive/hifive-unmatched-a00.dtb /boot/


echo U_BOOT_FDT=\"hifive-unmatched-a00.dtb\" >> /etc/default/u-boot
echo U_BOOT_PARAMETERS=\"rw rootwait console=ttySIF0,115200 earlycon\" >> /etc/default/u-boot
u-boot-update

# Install ssh server,ntp and dhclient
apt-get install openssh-server openntpd ntpdate dhcpcd-base
apt-get clean

# set the time immediately at startup
sed -i 's/^DAEMON_OPTS="/DAEMON_OPTS="-s /' /etc/default/openntpd

# exit chroot
exit
```

Remove bash history

```bash
sudo rm /mnt/root/.bash_history
```

## Setup bootloaders on sd card
```bash
sudo dd if=/mnt/usr/lib/u-boot/sifive_unmatched/u-boot-spl.bin of=/dev/loop1p1 bs=4k iflag=fullblock oflag=direct conv=fsync status=progress

sudo dd if=/mnt/usr/lib/u-boot/sifive_unmatched/u-boot.itb of=/dev/loop1p2 bs=4k iflag=fullblock oflag=direct conv=fsync status=progress
```

## Finish and write image to nvme and sd card

```bash
sudo umount /mnt

sudo losetup -d /dev/loop0

sduo losetup -d /dev/loop1

# take care of writing to the correct nvme-device
sudo dd if=nvme-rootfs.img of=/dev/[nvme-device] bs=64k iflag=fullblock oflag=direct conv=fsync status=progress

sudo dd if=sd-uboot.img of=/dev/[sd-device] bs=64k iflag=fullblock oflag=direct conv=fsync status=progress
```

# Notes

## bootloader on sd card
At present, the bootloader still needs to be dd to the sd card to run on nvme. You can flash fresh sd-uboot img follow above instructions or you can use the pre-built [image](./image/sd-uboot.img) to dd it to sd cards.

```bash
sudo dd if=sd-uboot.img of=/dev/sdcard-device bs=64k iflag=fullblock oflag=direct conv=fsync status=progress
```

## login
Please use the serial port to log in at first. ssh accessing for root does not work. If you does not get ip, please use `ifup eth0` to active it. Sometime the nic is called `end0`.

If you are stuck on serial port logging, please wait minutes due to it will be crashed due to radeon cards on my Unmatched boards. This is not big iedal at last. This is todo debug.

## resize nvme
Maye you need reszie nvme volume with cmd below:

```bash
parted -f -s /dev/nvme0n1 print
echo 'yes' | parted ---pretend-input-tty /dev/nvme0n1 resizepart 1  20GB
resize2fs /dev/nvme0n1p1
```

## TODO

Docker ci scripts (WIP)

# Thanks 

Thanks to [wangliu-iscas](https://github.com/wangliu-iscas) for testing.
