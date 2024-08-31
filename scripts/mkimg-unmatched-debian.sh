#!/usr/bin/bash

set -euo pipefail

MODEL=${MODEL:-unmatched} # pioneer, pisces
DEVICE="/dev/loop10"
CHROOT_TARGET=rootfs
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ROOT_IMG=debian-${MODEL}-${TIMESTAMP}.img

# == packages ==
BASE_TOOLS="file tree sudo bash-completion u-boot-menu initramfs-tools openssh-server network-manager dnsmasq-base libpam-systemd ppp wireless-regdb libengine-pkcs11-openssl iptables systemd-timesyncd vim usbutils libgles2 parted  ca-certificates"
XFCE_DESKTOP="xorg xfce4 desktop-base lightdm xfce4-terminal tango-icon-theme xfce4-notifyd xfce4-power-manager network-manager-gnome xfce4-goodies pulseaudio alsa-utils dbus-user-session rtkit pavucontrol thunar-volman eject gvfs gvfs-backends udisks2 dosfstools e2fsprogs ntfs-3g polkitd exfat-fuse "
#GNOME_DESKTOP="gnome-core avahi-daemon desktop-base file-roller gnome-tweaks gstreamer1.0-libav gstreamer1.0-plugins-ugly libgsf-bin libproxy1-plugin-networkmanager network-manager-gnome"
#KDE_DESKTOP="kde-plasma-desktop"
#BENCHMARK_TOOLS="glmark2 mesa-utils vulkan-tools iperf3 stress-ng"
#FONTS="fonts-crosextra-caladea fonts-crosextra-carlito fonts-dejavu fonts-liberation fonts-liberation2 fonts-linuxlibertine fonts-noto-core fonts-noto-cjk fonts-noto-extra fonts-noto-mono fonts-noto-ui-core fonts-sil-gentium-basic"
#FONTS="fonts-noto-core fonts-noto-cjk fonts-noto-mono fonts-noto-ui-core"
EXTRA_TOOLS="i2c-tools net-tools ethtool"
DOCKER="docker.io apparmor cgroupfs-mount git needrestart xz-utils"
ADDONS="initramfs-tools firmware-amd-graphics firmware-realtek"

machine_info() {
    uname -a
    echo $(nproc)
    lscpu
    whoami
    env
    fdisk -l
    df -h
}

init() {
    # Init out folder & rootfs
    mkdir -p rootfs

    apt update

    # create flash image
    fallocate -l 4G $ROOT_IMG
}

install_deps() {
    apt install -y gdisk dosfstools g++-12-riscv64-linux-gnu build-essential \
        libncurses-dev gawk flex bison openssl libssl-dev \
        dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf mkbootimg \
        fakeroot genext2fs genisoimage libconfuse-dev mtd-utils mtools qemu-utils squashfs-tools \
        device-tree-compiler rauc u-boot-tools f2fs-tools swig mmdebstrap parted
}

qemu_setup() {
    apt install -y binfmt-support qemu-user-static curl wget
    update-binfmts --display
}

img_setup() {
    sgdisk -g --clear --set-alignment=1 \
       --new=1:34:+1M:    --change-name=1:'u-boot-spl'    --typecode=1:5b193300-fc78-40cd-8002-e86c45580b47 \
       --new=2:2082:+4M:  --change-name=2:'opensbi-uboot' --typecode=2:2e54b353-1271-4842-806f-e436d6af6985 \
       --new=3:16384:+400M:   --change-name=3:'boot'      --typecode=3:0x0700  --attributes=3:set:2  \
       --new=4:835584:-0   --change-name=4:'rootfs'       --typecode=4:0x8300 \
      $ROOT_IMG

    losetup -P ${DEVICE} $ROOT_IMG
    #parted -s -a optimal -- "${DEVICE}" mktable msdos
    #parted -s -a optimal -- "${DEVICE}" mkpart primary fat32 0% 256MiB
    #parted -s -a optimal -- "${DEVICE}" mkpart primary ext4 256MiB 1280MiB
    #parted -s -a optimal -- "${DEVICE}" mkpart primary ext4 1280MiB 100%

    #parted -s -a optimal -- "${DEVICE}" mkpart primary ext4 34MiB 100%
    #mkfs.ext4 -L debian-root -F "/dev/mapper/${LOOPDEV}"

    partprobe "${DEVICE}"

    #mkfs.vfat "${DEVICE}p1" -n EFI
    mkfs.ext4 -F -L boot "${DEVICE}p3"
    mkfs.ext4 -F -L rootfs "${DEVICE}p4"

    mount "${DEVICE}p4" "${CHROOT_TARGET}"
}

make_rootfs() {
    mmdebstrap --architectures=riscv64 \
    --skip=check/empty \
    --include="ca-certificates locales dosfstools \
        $BASE_TOOLS $EXTRA_TOOLS $ADDONS" \
    sid "${CHROOT_TARGET}" \
    "deb  http://mirror.iscas.ac.cn/debian/ sid main contrib non-free non-free-firmware"

    #debootstrap --arch=riscv64 \
    #unstable "${CHROOT_TARGET}" http://mirror.iscas.ac.cn/debian

    mount "${DEVICE}p3" "$CHROOT_TARGET/boot"
}

after_mkrootfs() {
    # Set up fstab
    cat > "$CHROOT_TARGET"/etc/fstab << EOF
/dev/nvme0n1p4 /               ext4    errors=remount-ro 0       1
/dev/nvme0n1p3 /boot           ext4    nodev,noexec,rw   0       2
EOF

    sudo chroot $CHROOT_TARGET /bin/bash << EOF
# Add user
useradd -m -s /bin/bash -G adm,sudo debian
echo 'debian:debian' | chpasswd

# Change hostname
echo Unmatched > /etc/hostname

exit
EOF

    # Add timestamp file in /etc
    if [ ! -f debian-release ]; then
        echo "$TIMESTAMP" > rootfs/etc/debian-release
    else
        cp -v debian-release rootfs/etc/debian-releasedd
    fi

    # clean up source.list
    cat > $CHROOT_TARGET/etc/apt/sources.list << EOF
deb http://mirror.iscas.ac.cn/debian/ sid main contrib non-free non-free-firmware
EOF


    # fix partition

    # Add update-u-boot config
    #cat > $CHROOT_TARGET/etc/default/u-boot << EOF
    #EOF

    # Install kernel
    sudo chroot $CHROOT_TARGET /bin/bash << EOF
apt update
apt install -y linux-image-riscv64 u-boot-menu u-boot-sifive
apt clean
echo nvme >> /etc/initramfs-tools/modules
echo U_BOOT_PARAMETERS=\"rw rootwait console=ttySIF0,115200 earlycon\" >> /etc/default/u-boot
u-boot-update
EOF

    # remove openssh keys
    rm -v $CHROOT_TARGET/etc/ssh/ssh_host_*

    # clean source
    rm -vrf $CHROOT_TARGET/var/lib/apt/lists/*

    dd if=${CHROOT_TARGET}/usr/lib/u-boot/sifive_unmatched/u-boot-spl.bin of=${DEVICE}p1 bs=4k iflag=fullblock oflag=direct conv=fsync status=progres
    dd if=${CHROOT_TARGET}/usr/lib/u-boot/sifive_unmatched/u-boot.itb of=${DEVICE}p2 bs=4k iflag=fullblock oflag=direct conv=fsync status=progress

    umount -l "$CHROOT_TARGET/boot"
    umount -l "$CHROOT_TARGET"
}


machine_info
init
install_deps
qemu_setup
img_setup
make_rootfs
after_mkrootfs

losetup -d "${DEVICE}"
