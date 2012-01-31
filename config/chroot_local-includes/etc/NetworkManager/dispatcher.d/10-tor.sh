#!/bin/sh

# We don't start Tor automatically so *this* is the time
# when it is supposed to start.

# Run only when the interface is not "lo":
if [ $1 = "lo" ]; then
   exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ $2 != "up" ]; then
   exit 0
fi

# Workaround https://trac.torproject.org/projects/tor/ticket/2355
if grep -qw bridge /proc/cmdline; then
   rm -f /var/lib/tor/*
fi

# A SIGHUP should be enough but there's a bug in Tor. Details:
# * https://trac.torproject.org/projects/tor/ticket/1247
# * https://tails.boum.org/bugs/tor_vs_networkmanager/
service tor restart

# In bridge mode Vidalia needs to start before tordate (20-time.sh)
# since we need bridges to be configured before any consensus or
# descriptors can be downloaded, which tordate depends on.
if grep -qw bridge /proc/cmdline; then
   /etc/NetworkManager/dispatcher.d/60-vidalia.sh $@
fi
