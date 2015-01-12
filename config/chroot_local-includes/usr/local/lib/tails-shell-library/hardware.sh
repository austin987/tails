#!/bin/sh

get_all_ethernet_nics() {
    for i in /sys/class/net/*; do
        # type = 1 means ethernet (ARPHDR_ETHER, see Linux' sources,
        # beginning of include/linux/if_arp.h)
        if [ "$(cat "${i}"/type)" = 1 ]; then
            basename "${i}"
        fi
    done
}

nic_exists() {
    [ -e /sys/class/net/"${1}" ]
}

nic_is_up() {
    [ "$(cat /sys/class/net/"${1}"/operstate)" = "up" ]
}

# The following "nic"-related functions require that the argument is a
# NIC that exists

# Will just output nothing on failure
get_current_mac_of_nic() {
    local mac
    mac="$(macchanger "${1}" | sed -n "s/^Current\s*MAC:\s*\([0-9a-f:]\+\)\s.*$/\1/p" || :)"
    if echo "${mac}:" | grep -q "^\([0-9a-fA-F]\{2\}:\)\{6\}$"; then
        echo "${mac}"
    fi
}

get_module_used_by_nic() {
    basename "$(readlink "/sys/class/net/${1}/device/driver/module")"
}

get_name_of_nic() {
  vendor=$(sed 's/^0x\(.*\)$/\1/' "/sys/class/net/${1}/device/vendor")
  device=$(sed 's/^0x\(.*\)$/\1/' "/sys/class/net/${1}/device/device")
  lspci -nn | sed -n "s/^\S\+\s\+[^:]\+:\s\+\(.*\)\s\+\[$vendor:$device\].*$/\1/p"
}

# Auxillary function for mod_rev_dep(). It recurses over the graph of
# kernel module depencies of $@ (note that it only works for loaded
# modules). To deal with circular dependencies a global variable
# MOD_REV_DEP_VISITED keeps track of already visited nodes, and it
# should be unset before the first call of this function.
mod_rev_dep_aux() {
  local mod
  local rev_deps
  for mod in ${@}; do
    if echo ${MOD_REV_DEP_VISITED} | grep -qw ${mod}; then
        continue
    fi
    MOD_REV_DEP_VISITED="${MOD_REV_DEP_VISITED} ${mod}"
    # extract the "Used by" column for $mod from lsmod
    rev_deps=$(lsmod | \
               sed -n "s/^${mod}\s\+\S\+\s\+\S\+\s\+\(\S\+\)/\1/p" | \
               tr ',' ' ')
    mod_rev_dep_aux ${rev_deps}
    echo ${mod}
  done
}

# Prints a list of all loaded modules depending on $1, including $1. It's
# ordered by descending "maximum dependency distance" from $1, so the
# output is ideal if we want to unload $1 and (by necessity) all
# modules that uses $1.
mod_rev_dep() {
  MOD_REV_DEP_VISITED=""
  mod_rev_dep_aux ${1}
}

# Unloads module $1, and all modules that (transatively) depends on
# $1 (i.e. its reverse dependencies).
unload_module_and_rev_deps() {
  for mod in $(mod_rev_dep ${1}); do
      /sbin/rmmod ${mod}
  done
}
