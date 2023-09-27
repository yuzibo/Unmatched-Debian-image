#!/bin/sh
#
#
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

/var/lib/dpkg/info/dash.preinst install
/var/lib/dpkg/info/base-passwd.preinst install
/var/lib/dpkg/info/sgml-base.preinst install
mkdir -p /etc/sgml
dpkg --configure -a
mount proc -t proc /proc
dpkg --configure -a
umount /proc
# Needed because we get permissions problems for some reason
chmod 0666 /dev/null

#
# Change root password to 'sifive'
#
usermod --password "$(echo sifive | openssl passwd -1 -stdin)" root

#
# Add a new user rv
#
mkdir -p /home/rv
useradd --password dummy \
    -G cdrom,floppy,sudo,audio,dip,video,plugdev \
    --home-dir /home/rv --shell /bin/bash rv
chown rv:rv /home/rv
# Set password to 'rv'
usermod --password "$(echo rv | openssl passwd -1 -stdin)" rv

# update-initramfs -u
rm /boot/initrd*
update-initramfs -c -k all

# Set up fstab
cat > /etc/fstab <<EOF
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/nvme0n1p1 /               ext4    errors=remount-ro 0       1
EOF

# Set hostname
echo unmatched > /etc/hostname

# 
cat >> /etc/hosts << EOF
127.0.0.1       unmatched
EOF

# Add needed modules in initrd
echo "nvme" >> /etc/initramfs-tools/modules

# cp your latest dtb file,e.g, cp /usr/lib/linux-image-xx-riscv64
# need you confirm it here
cp /usr/lib/linux-image-*/sifive/hifive-unmatched-a00.dtb /boot/
echo U_BOOT_FDT=\"hifive-unmatched-a00.dtb\" >> /etc/default/u-boot
echo U_BOOT_PARAMETERS=\"rw rootwait console=ttySIF0,115200 earlycon\" >> /etc/default/u-boot

u-boot-update

# 
# Enable system services
#
#systemctl enable systemd-resolved.service

# Update source list 

rm -rf /etc/apt/sources.list.d/multistrap-debian.list

cat > /etc/apt/sources.list <<EOF
deb https://mirror.iscas.ac.cn/debian sid main non-free-firmware
EOF

#
# Clean apt cache on the system
#
apt-get clean

# set the time immediately at startup
sed -i 's/^DAEMON_OPTS="/DAEMON_OPTS="-s /' /etc/default/openntpd

rm -rf /var/cache/*
find /var/lib/apt/lists -type f -not -name '*.gpg' -print0 | xargs -0 rm -f
find /var/log -type f -print0 | xargs -0 truncate --size=0
