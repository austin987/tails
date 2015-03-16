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

# Import tor_control_setconf(), TOR_LOG
. /usr/local/lib/tails-shell-library/tor.sh

# Import tails_netconf()
. /usr/local/lib/tails-shell-library/tails-greeter.sh

# It's safest that Tor is not running when messing with its logs.
service tor stop

# We depend on grepping stuff from the Tor log (especially for
# tordate/20-time.sh), so deleting it seems like a Good Thing(TM).
rm -f "${TOR_LOG}"

# The Tor syscall sandbox is not compatible with managed proxies.
# We could possibly detect whether the user has configured any such
# thing via Tor Launcher later (e.g. in 60-tor-ready-notification.sh),
# but then we would have to restart Tor again to enable the sandbox.
# Let's avoid doing that, and enable the Sandbox only if no special Tor
# configuration is needed. Too bad users who simply need to configure
# a HTTP proxy or allowed firewall ports won't get the sandboxing, but
# much better than nothing.
if [ "$(tails_netconf)" = "direct" ]; then
   tor_set_in_torrc Sandbox 1
fi

# A SIGHUP should be enough but there's a bug in Tor. Details:
# * https://trac.torproject.org/projects/tor/ticket/1247
# * https://tails.boum.org/bugs/tor_vs_networkmanager/
restart-tor

if [ "$(tails_netconf)" = "obstacle" ]; then
   # When using a bridge Tor reports TLS cert lifetime errors
   # (e.g. when the system clock is way off) with severity "info", but
   # when no bridge is used the severity is "warn". tordate/20-time.sh
   # depends on grepping these error messages, so we temporarily
   # increase Tor's logging severity.
   tor_control_setconf "Log=\"info file ${TOR_LOG}\""

   # Enable the transports we support. We cannot do this in general,
   # when bridge mode is not enabled, since we then use seccomp
   # sandboxing.
   tor_control_setconf 'ClientTransportPlugin="obfs2,obfs3,obfs4 exec /usr/bin/obfs4proxy managed"'

   /usr/local/sbin/tails-tor-launcher &
fi
