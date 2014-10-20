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
