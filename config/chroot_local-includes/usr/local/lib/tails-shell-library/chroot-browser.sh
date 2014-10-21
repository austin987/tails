#!/bin/sh

# Import the TBB_INSTALL, TBB_PROFILE and TBB_EXT variables, and
# configure_xulrunner_app_locale().
. /usr/local/lib/tails-shell-library/tor-browser.sh

# Import windows_camouflage_is_enabled()
. /usr/local/lib/tails-shell-library/tails-greeter.sh

# Import try_for().
. /usr/local/lib/tails-shell-library/common.sh

# Break down the chroot and kill all of its processes
try_cleanup_browser_chroot () {
    local chroot="${1}"
    local cow="${2}"
    local user="${3}"
    try_for 10 "pkill -u ${user} 1>/dev/null 2>&1" 0.1 || \
        pkill -9 -u ${user} 1>/dev/null 2>&1
    for mnt in ${chroot}/dev ${chroot}/proc ${chroot} ${cow}; do
        try_for 10 "umount ${mnt} 2>/dev/null" 0.1
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
    mount --bind /dev ${chroot}/dev || \
        return 1

    # Workaround for #6110
    chmod -t ${cow}
}

set_chroot_browser_locale () {
    local chroot="${1}"
    local browser_user="${2}"
    local locale="${3}"
    local browser_profile="${chroot}/home/${browser_user}/.tor-browser/profile.default"
    configure_xulrunner_app_locale "${browser_profile}" "${locale}"
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

# Set the chroot's DNS servers (IPv4 only)
configure_chroot_dns_servers () {
    local chroot="${1}" ; shift
    local ip4_nameservers="${@}"

    rm -f ${chroot}/etc/resolv.conf
    for ns in ${ip4_nameservers}; do
        echo "nameserver ${ns}" >> ${chroot}/etc/resolv.conf
    done
    chmod a+r ${chroot}/etc/resolv.conf
}

set_chroot_browser_permissions () {
    local chroot="${1}"
    local browser_user="${2}"
    local browser_conf="${chroot}/home/${browser_user}/.tor-browser"
    chown -R ${browser_user}:${browser_user} "${browser_conf}"
}

configure_chroot_browser () {
    local chroot="${1}" ; shift
    local browser_name="${1}" ; shift
    local browser_user="${1}" ; shift
    local startpage="${1}" ; shift
    # Now $@ is a list of paths (that must be valid after chrooting)
    # to extensions to enable.

    # Prevent sudo from complaining about failing to resolve the 'amnesia' host
    echo "127.0.0.1 localhost amnesia" > ${chroot}/etc/hosts

    # Create a fresh browser profile for the clearnet user
    local browser_conf="${chroot}/home/${browser_user}/.tor-browser"
    local browser_profile="${browser_conf}/profile.default"
    local browser_ext="${browser_profile}"/extensions
    mkdir -p "${browser_profile}" "${browser_ext}"

    # Select extensions to enable
    local extension
    while [ -n "${*}" ]; do
        extension="${1}" ; shift
        ln -s "${extension}" "${browser_ext}"
    done

    # Set preferences
    local browser_prefs="${browser_profile}"/preferences/prefs.js
    mkdir -p "$(dirname "${browser_prefs}")"
    cp /usr/share/tails/"${browser_name}"/prefs.js "${browser_prefs}"

    # Set start page to something that explains what's going on
    echo 'user_pref("browser.startup.homepage", "'${startpage}'");' >> \
        "${browser_prefs}"

    # Customize the GUI
    local browser_chrome="${browser_profile}/chrome/userChrome.css"
    mkdir -p "$(dirname "${browser_chrome}")"
    cp /usr/share/tails/"${browser_name}"/userChrome.css ${browser_chrome}

    # Remove all bookmarks
    rm -f ${chroot}/"${TBB_PROFILE}"/bookmarks.html
    rm -f ${browser_profile}/bookmarks.html
    rm -f ${browser_profile}/places.sqlite

    # Set an appropriate theme, except if we're using Windows
    # camouflage.
    if ! windows_camouflage_is_enabled; then
        cat /usr/share/tails/"${browser_name}"/theme.js >> "${browser_prefs}"
    else
        # The tails-activate-win8-theme script requires that the
        # browser profile is writable by the user running the script.
        set_chroot_browser_permissions ${chroot} ${browser_user}
        # The camouflage activation script requires a dbus server for
        # properly configuring GNOME, so we start one in the chroot
        chroot ${chroot} sudo -H -u ${browser_user} sh -c 'eval `dbus-launch --auto-syntax`; tails-activate-win8-theme' || :
    fi
}
