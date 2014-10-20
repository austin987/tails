#!/bin/sh

# Import the TBB_EXT variable.
. /usr/local/lib/tails-shell-library/tor-browser.sh

# Break down the chroot and kill all of its processes
try_cleanup_browser_chroot () {
    local chroot="${1}"
    local cow="${2}"
    local user="${3}"
    local counter=0
    local ret=0
    while [ "${counter}" -le 10 ] && \
        pgrep -u ${user} 1>/dev/null 2>&1; do
        pkill -u ${user} 1>/dev/null 2>&1
        ret=${?}
        sleep 1
        counter=$((${counter}+1))
    done
    [ ${ret} -eq 0 ] || pkill -9 -u ${user} 1>/dev/null 2>&1
    for mnt in ${chroot}/dev ${chroot}/proc ${chroot} ${cow}; do
        counter=0
        while [ "${counter}" -le 10 ] && mountpoint -q ${mnt} 2>/dev/null; do
            umount ${mnt} 2>/dev/null
            sleep 1
            counter=$((${counter}+1))
        done
    done
    rmdir ${cow} ${chroot} 2>/dev/null
}

# Setup a chroot on a clean aufs "fork" of the root filesystem.
setup_browser_chroot () {
    local chroot="${1}"
    local cow="${2}"
    # FIXME: When LXC matures to the point where it becomes a viable option
    # for creating isolated jails, the chroot can be used as its rootfs.

    trap cleanup INT
    trap cleanup EXIT

    local rootfs_dir
    local rootfs_dirs_path=/lib/live/mount/rootfs
    local tails_module_path=/lib/live/mount/medium/live/Tails.module
    local aufs_dirs=

    # We have to pay attention to the order we stack the filesystems;
    # newest must be first, and remember that the .module file lists
    # oldest first, newest last.
    while read rootfs_dir; do
        rootfs_dir="${rootfs_dirs_path}/${rootfs_dir}"
        mountpoint -q "${rootfs_dir}" && \
        aufs_dirs="${rootfs_dir}=rr+wh:${aufs_dirs}"
    done < "${tails_module_path}"
    # But our copy-on-write dir must be at the very top.
    aufs_dirs="${cow}=rw:${aufs_dirs}"

    mkdir -p ${cow} ${chroot} && \
    mount -t tmpfs tmpfs ${cow} && \
    mount -t aufs -o "noatime,noxino,dirs=${aufs_dirs}" aufs ${chroot} && \
    mount -t proc proc ${chroot}/proc && \
    mount --bind /dev ${chroot}/dev

    # Workaround for #6110
    chmod -t ${cow}
}
