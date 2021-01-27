#!/bin/bash


ns=tbbNs
net='10.200.1'

set -ue

in_ns() {
    ip netns exec $ns "$@"
}

### some whitelist to make it working
iptables -A INPUT -p tcp --dport 1234 -j ACCEPT
iptables -I INPUT 1 -p tcp --dport 9050 -j ACCEPT
iptables -I OUTPUT 1 -p tcp --dport 9050 -j ACCEPT

# create namespace
ip netns del $ns 2> /dev/null
ip netns add $ns

# create veth
ip netns exec $ns ip link set dev lo up
ip link del tbb-veth || true
ip link add tbb-veth type veth peer name veth0

# setup veth
ip link set veth0 netns $ns
ip addr add $net.1/24 dev tbb-veth
ip link set dev tbb-veth up
in_ns ip addr add $net.2/24 dev veth0
in_ns ip link set dev veth0 up

# setup iptables
## forbid IP spoofing
in_ns iptables -A OUTPUT -o veth0 ! --src $net.2 -j REJECT
in_ns sysctl net.ipv4.ip_forward=0
in_ns sysctl net.ipv4.conf.all.forwarding=0
in_ns sysctl net.ipv4.conf.lo.forwarding=0
in_ns sysctl net.ipv4.conf.all.route_localnet=1

expose() {
    # $1 is netNs port
    # $2 is host port
    in_ns iptables -t nat \
        -A OUTPUT -o lo -d 127.0.0.1 -p tcp --dport "$1" \
        -j DNAT  --to-destination "$net.1:$2"
}

# letting some service available inside $tbbNs
expose 9050 9050
in_ns iptables -t nat -A POSTROUTING -j MASQUERADE

# setup host iptables
iptables -t nat -F PREROUTING
iptables -t nat -F POSTROUTING

sysctl net.ipv4.ip_forward=1
sysctl net.ipv4.conf.all.forwarding=1
sysctl net.ipv4.conf.lo.forwarding=1
sysctl net.ipv4.conf.tbb-veth.forwarding=1
# --src $net.2
iptables -t nat -A PREROUTING -p tcp --dest $net.1 --dport 9050 -j DNAT --to-destination 127.0.0.1:9050
iptables -t nat -A POSTROUTING -j MASQUERADE


# print sth
#in_ns ip link
#echo
#in_ns ip addr
in_ns iptables-save
