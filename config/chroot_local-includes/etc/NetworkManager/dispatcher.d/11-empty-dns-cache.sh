#! /bin/sh

# Rationale: todo/empty_dns_cache_after_restarting_Tor

# Run only when the interface is not "lo":
if [ "$1" = "lo" ]; then
   exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ "$2" != "up" ]; then
   exit 0
fi

/usr/sbin/pdnsd-ctl -c /var/cache/pdnsd -q \
   empty-cache '+.onion' '+.exit'
