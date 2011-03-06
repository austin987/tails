#!/bin/sh

# Run whenever an interface gets "up", not otherwise:
if [ "$2" != "up" ]; then
   exit 0
fi

IPTABLES_RULES=/etc/firewall.conf
IP6TABLES_RULES=/etc/firewall6.conf

[ -x /sbin/iptables-restore ]	|| exit 2
[ -n "$IPTABLES_RULES" ]	|| exit 3
[ -r "$IPTABLES_RULES" ]	|| exit 4

[ -x /sbin/ip6tables-restore ]	|| exit 12
[ -n "$IP6TABLES_RULES" ]	|| exit 13
[ -r "$IP6TABLES_RULES" ]	|| exit 14

/sbin/iptables-restore < "$IPTABLES_RULES"
/sbin/ip6tables-restore < "$IP6TABLES_RULES"
