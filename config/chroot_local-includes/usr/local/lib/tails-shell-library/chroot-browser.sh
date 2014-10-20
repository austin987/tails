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

set_chroot_browser_name () {
    local chroot="${1}"
    local name="${2}"
    local locale="${3}"
    local ext_dir=${chroot}/"${TBB_EXT}"
    local pack top rest
    if [ "${locale}" != en-US ]; then
        pack="${ext_dir}/langpack-${locale}@firefox.mozilla.org.xpi"
        top=browser/chrome
        rest=${locale}/locale
    else
        pack="${chroot}/${TBB_INSTALL}/browser/omni.ja"
        top=chrome
        rest=en-US/locale
    fi
    local tmp=$(mktemp -d)
    local branding="${top}/${rest}/branding/brand.dtd"
    # Non-zero exit code due to non-standard ZIP archive.
    # The following steps will fail soon if the extraction failed anyway.
    7z x -o"${tmp}" "${pack}" "${branding}" || true
    sed -i "s/<"'!'"ENTITY\s\+brand\(Full\|Short\)Name.*$/<"'!'"ENTITY brand\1Name \"${name}\">/" "${tmp}/${branding}"
    (cd ${tmp} ; 7z u -tzip "${pack}" .)
    chmod a+r "${pack}"
    rm -Rf "${tmp}"
}

# Start the browser in the chroot
run_chroot_browser () {
    local chroot="${1}"
    local chroot_user="${2}"
    local local_user="${3}"

    sudo -u ${local_user} xhost +SI:localuser:${chroot_user} 2>/dev/null
    chroot ${chroot} sudo -u ${chroot_user} /bin/sh -c \
        '. /usr/local/lib/tails-shell-library/tor-browser.sh && \
         exec_firefox -DISPLAY=:0.0 \
                      -profile /home/'"${chroot_user}"'/.tor-browser/profile.default'
    sudo -u ${local_user} xhost -SI:localuser:${chroot_user} 2>/dev/null
}

# TorButton forces the Browser name to Tor Browser unless we alter its
# branding files a bit.
set_chroot_torbutton_browser_name () {
    local chroot="${1}"
    local name="${2}"
    local locale="${3}"
    local torbutton_locale_dir="${chroot}"/usr/share/xul-ext/torbutton/chrome/locale/${locale}
    if [ ! -d "${torbutton_locale_dir}" ]; then
        # Surprisingly, the default locale is en, not en-US
        torbutton_locale_dir="${chroot}"/usr/share/xul-ext/torbutton/chrome/locale/en
    fi
    sed -i "s/<"'!'"ENTITY\s\+brand\(Full\|Short\)Name.*$/<"'!'"ENTITY brand\1Name \"${name}\">/" "${torbutton_locale_dir}/brand.dtd"
}
