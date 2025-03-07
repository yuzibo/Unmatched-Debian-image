#!/bin/bash

source $(pwd)/scripts/boards_list.sh

echo "execute packages_list.sh"

# == kernel variables ==
PACKAGE_LIST=""
KEYRINGS="ca-certificates"
GPU_DRIVER="thead-gles-addons"
BASE_TOOLS="gawk locales binutils file tree sudo bash-completion u-boot-menu initramfs-tools openssh-server network-manager dnsmasq-base libpam-systemd ppp wireless-regdb wpasupplicant libengine-pkcs11-openssl iptables systemd-timesyncd vim usbutils dosfstools parted exfatprogs systemd-sysv pkexec arch-install-scripts bluez cloud-guest-utils"
XFCE_DESKTOP="xorg xserver-xorg-video-thead xinput xfce4 desktop-base lightdm xfce4-terminal tango-icon-theme xfce4-notifyd xfce4-power-manager network-manager-gnome xfce4-goodies pulseaudio pulseaudio-module-bluetooth alsa-utils dbus-user-session rtkit pavucontrol thunar-volman eject gvfs gvfs-backends udisks2 e2fsprogs libblockdev-crypto2 ntfs-3g polkitd blueman xarchiver"
#FONTS="fonts-crosextra-caladea fonts-crosextra-carlito fonts-dejavu fonts-liberation fonts-liberation2 fonts-linuxlibertine fonts-noto-core fonts-noto-cjk fonts-noto-extra fonts-noto-mono fonts-noto-ui-core fonts-sil-gentium-basic"
