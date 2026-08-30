#!/bin/bash
#
# runtime-mount.sh — bind the host runtime pseudo-filesystems into a chroot /
# rootfs target and tear them down again afterwards.
#
# Provides:
#   mount_runtime   <target>
#   unmount_runtime <target>

set -euo pipefail

mount_runtime() {
    local dir="${1:?usage: mount_runtime <target>}"

    mkdir -p "$dir" "$dir/proc" "$dir/sys" "$dir/dev" \
        "$dir/dev/pts" "$dir/dev/shm" "$dir/run" \
        "$dir/sys/fs/cgroup" 2>/dev/null || true

    mount -t proc proc "$dir/proc" 2>/dev/null || true
    mount -t sysfs sysfs "$dir/sys" 2>/dev/null || true
    mount -t tmpfs tmpfs "$dir/run" 2>/dev/null || true

    if [ -d /dev ] && [ -d "$dir/dev" ]; then
        if ! mountpoint -q "$dir/dev" 2>/dev/null; then
            mount --rbind /dev "$dir/dev" 2>/dev/null \
                || mount -o bind /dev "$dir/dev" 2>/dev/null || true
        fi
    fi

    # An rbind of /dev already carries pts and shm; only fall back explicitly.
    if [ -d "$dir/dev/pts" ] && ! mountpoint -q "$dir/dev/pts" 2>/dev/null; then
        mount -t devpts devpts "$dir/dev/pts" 2>/dev/null || true
    fi
    if [ -d "$dir/dev/shm" ] && ! mountpoint -q "$dir/dev/shm" 2>/dev/null; then
        mount -t tmpfs tmpfs "$dir/dev/shm" 2>/dev/null || true
    fi

    if [ -d /sys/fs/cgroup ] && [ -d "$dir/sys/fs/cgroup" ] \
        && ! mountpoint -q "$dir/sys/fs/cgroup" 2>/dev/null; then
        mount -t cgroup2 none "$dir/sys/fs/cgroup" 2>/dev/null || true
    fi
}

unmount_runtime() {
    local dir="${1:?usage: unmount_runtime <target>}"
    local m

    for m in "$dir/dev/shm" "$dir/dev/pts" "$dir/dev" \
        "$dir/sys/fs/cgroup" "$dir/run" "$dir/sys" "$dir/proc"; do
        if mountpoint -q "$m" 2>/dev/null; then
            umount -R "$m" 2>/dev/null || umount -l "$m" 2>/dev/null \
                || echo "warning: failed to unmount ${m}" >&2
        fi
    done
}