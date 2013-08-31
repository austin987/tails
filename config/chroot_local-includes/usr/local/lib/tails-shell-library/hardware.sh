#!/bin/sh

get_all_ethernet_nics() {
    /sbin/ifconfig -a | grep "Link encap:Ethernet" | cut -f 1 -d " "
}

nic_is_up() {
    /sbin/ifconfig | grep -qe "^${1}\>"
}

nic_is_wireless() {
    /sbin/iwconfig ${1} >/dev/null 2>&1
}
