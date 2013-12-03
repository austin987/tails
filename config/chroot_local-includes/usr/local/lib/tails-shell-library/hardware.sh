#!/bin/sh

get_all_ethernet_nics() {
    /sbin/ifconfig -a | grep "Link encap:Ethernet" | cut -f 1 -d " "
}

nic_exists() {
    /sbin/ifconfig "${1}" >/dev/null 2>&1
}

nic_is_up() {
    /sbin/ifconfig | grep -qe "^${1}\>"
}

# The following "nic"-related functions require that the argument is a
# NIC that exists
get_permanent_mac_of_nic() {
    macchanger ${1} | sed -n "s/^Permanent\s*MAC:\s*\([0-9a-f:]\+\)\s.*$/\1/p"
}

get_current_mac_of_nic() {
    macchanger ${1} | sed -n "s/^Current\s*MAC:\s*\([0-9a-f:]\+\)\s.*$/\1/p"
}

nic_has_spoofed_mac() {
    [ "$(get_permanent_mac_of_nic ${1})" != "$(get_current_mac_of_nic ${1})" ]
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
# kernel module depencies of $@. To deal with circular dependencies a
# global variable MOD_REV_DEP_VISITED keeps track of already visited
# nodes, and it should be unset before the first call of this
# function.
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

# Prints a list of all modules depending on $1, including $1. It's
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
  /sbin/modprobe -r $(mod_rev_dep ${1})
}
