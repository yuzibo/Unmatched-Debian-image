#!/bin/bash

after_mkrootfs()
{
    # Add timestamp file in /etc
    if [ ! -f debian-release ]; then
        echo "$TIMESTAMP" > rootfs/etc/debian-release
    else
        cp -v debian-release rootfs/etc/debian-release
    fi

    # Install system services
    # vimer

    # Use iptables-legacy for docker

    # Chromium add "--no-sandbox --use-gl=egl" flags
    # replace "Exec=/usr/bin/chromium %U" to "Exec=/usr/bin/chromium --no-sandbox --use-gl=egl %U"

    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_CONSOLE4A}" ] || [ "${BOARD}" == "${BOARD_LAPTOP4A}" ] || [ "${BOARD}" == "${BOARD_AHEAD}" ] || [ "${BOARD}" == "${BOARD_MELES}" ]; then
	# vimer ^
#	Driver "thead"
#EndSection
#EOF
	echo "Debian no these files"
    fi

    if [ "${BOARD}" == "${BOARD_LPI4A_MAINLINE}" ]; then
        # No space left on device
        echo "skip install mpv parole th1520-vpu libgl4es th1520-npu"
    else
        # Install other packages
        #chroot "$CHROOT_TARGET" sh -c "apt install -y mpv parole th1520-vpu libgl4es th1520-npu"
	# vimer ^
        echo "skip install mpv parole th1520-vpu libgl4es th1520-npu"
    fi

    # Setup branding related
    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_CONSOLE4A}" ] || [ "${BOARD}" == "${BOARD_LAPTOP4A}" ]; then
        #chroot "$CHROOT_TARGET" sh -c "apt install -y $BRANDING "
        #rm -vr "$CHROOT_TARGET"/etc/update-motd.d
        #cp -rp addons/etc/update-motd.d "$CHROOT_TARGET"/etc/
	# vimer ^: skip above packages on debian
	echo "skip motd on debian"
    elif [ "${BOARD}" == "${BOARD_LPI4A_MAINLINE}" ]; then
        # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1029394
        chroot "$CHROOT_TARGET" sh -c "apt install -y lsb-release figlet "
        rm -vr "$CHROOT_TARGET"/etc/update-motd.d
        cp -rp addons/etc/update-motd.d "$CHROOT_TARGET"/etc/
    fi
    # vimer ^  !=
    if [ "${BOARD}" == "${BOARD_LPI4A_MAINLINE}" ]; then
        # Wallpaper
        cp -rp addons/usr/share/images/ruyisdk "$CHROOT_TARGET"/usr/share/images/
        chroot "$CHROOT_TARGET" sh -c "rm -v /usr/share/images/desktop-base/desktop-background"
        chroot "$CHROOT_TARGET" sh -c "rm -v /usr/share/images/desktop-base/login-background.svg"
        chroot "$CHROOT_TARGET" sh -c "ln -s /usr/share/images/ruyisdk/ruyi-1-1920x1080.png /usr/share/images/desktop-base/desktop-background"
        chroot "$CHROOT_TARGET" sh -c "ln -s /usr/share/images/ruyisdk/ruyi-2-1920x1080.png /usr/share/images/desktop-base/login-background.svg"
    fi

    # lpi4amain related (disable GPU, add perf)
    if [ "${BOARD}" == "${BOARD_LPI4A_MAINLINE}" ]; then
        # lpi4a-main No GPU
        if ( chroot "$CHROOT_TARGET" sh -c "systemctl list-unit-files lightdm.service" ); then
            echo "lpi4amain No GPU: Disable lightdm"
            chroot "$CHROOT_TARGET" sh -c "systemctl disable lightdm"
        fi
        # Install perf-th1520 (new perf for c9xx pmu)
        cp -rp addons/lpi4amain/perf-th1520 rootfs/bin
    fi

    # Copy files for Console4A
    if [ "${BOARD}" == "${BOARD_CONSOLE4A}" ]; then
        echo "Console4A specific: Copy files for Console4A"
        cp -rp addons/LicheeConsole4A/* rootfs/opt/
        # Install autostarts
        cp -rp addons/LicheeConsole4A/display-setup.desktop rootfs/etc/xdg/autostart/

        # Rotate lightdm screen using /opt/display-setup.sh
        sed -i 's/#greeter-setup-script=/greeter-setup-script=\/opt\/display-setup.sh/g' "$CHROOT_TARGET"/etc/lightdm/lightdm.conf 
    fi

    # Set locale to en_US.UTF-8 UTF-8
    chroot "$CHROOT_TARGET" sh -c "echo 'locales locales/default_environment_locale select en_US.UTF-8' | debconf-set-selections"
    chroot "$CHROOT_TARGET" sh -c "echo 'locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8' | debconf-set-selections"
    chroot "$CHROOT_TARGET" sh -c "rm /etc/locale.gen"
    chroot "$CHROOT_TARGET" sh -c "dpkg-reconfigure --frontend noninteractive locales"

    # Set default timezone to Asia/Shanghai
    chroot "$CHROOT_TARGET" sh -c "ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime"
    echo "Asia/Shanghai" > $CHROOT_TARGET/etc/timezone

    # Set up fstab
    chroot $CHROOT_TARGET /bin/bash << EOF
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/nvme0n1p1 /               ext4    errors=remount-ro 0       1
exit
EOF

    # apt update
    chroot "$CHROOT_TARGET" sh -c "apt update"
    
    # Add user
    chroot "$CHROOT_TARGET" sh -c "useradd -m -s /bin/bash -G adm,cdrom,floppy,sudo,input,audio,dip,video,plugdev,netdev,bluetooth,lp debian"
    chroot "$CHROOT_TARGET" sh -c "echo 'debian:debian' | chpasswd"

    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_CONSOLE4A}" ] || [ "${BOARD}" == "${BOARD_LAPTOP4A}" ]; then
        echo "lpi4a specific: Add sipeed user"
        chroot "$CHROOT_TARGET" sh -c "useradd -m -s /bin/bash -G adm,cdrom,floppy,sudo,input,audio,dip,video,plugdev,netdev,bluetooth,lp sipeed"
        chroot "$CHROOT_TARGET" sh -c "echo 'sipeed:licheepi' | chpasswd"
    fi

    # Change hostname
    chroot $CHROOT_TARGET /bin/bash << EOF
echo debian-${BOARD} > /etc/hostname

exit
EOF

    # remove openssh keys
    rm -v rootfs/etc/ssh/ssh_host_*

    # Clean apt caches
    rm -r "$CHROOT_TARGET"/var/lib/apt/lists/*
}
