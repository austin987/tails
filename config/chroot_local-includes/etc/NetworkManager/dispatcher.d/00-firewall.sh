#!/bin/sh

# Run whenever an interface gets "up", not otherwise:
if [[ $2 != "up" ]]; then
   exit 0
fi

IPTABLES_RULES=/etc/firewall.conf

[ -x /sbin/iptables-restore ]	|| exit 2
[ -n "$IPTABLES_RULES" ]	|| exit 3
[ -r "$IPTABLES_RULES" ]	|| exit 4

/sbin/iptables-restore < "$IPTABLES_RULES"
