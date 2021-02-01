#!/bin/sh

# We don't start Tor automatically so *this* is the time
# when it is supposed to start.

# Run only when the interface is not "lo":
if [ -z "$1" ] || [ "$1" = "lo" ]; then
    exit 0
fi

if [ "$2" = "up" ]; then
    : # go on, that's what this script is for
elif [ "${2}" = "down" ]; then
    systemctl --no-block stop tails-tor-has-bootstrapped.target
    exit 0
else
    exit 0
fi

# Import tor_control_setconf(), TOR_LOG
. /usr/local/lib/tails-shell-library/tor.sh

# It's safest that Tor is not running when messing with its logs.
systemctl stop tor@default.service

# We depend on grepping stuff from the Tor log (especially for
# tordate/20-time.sh), so deleting it seems like a Good Thing(TM).
rm -f "${TOR_LOG}"

# We would like Tor to be started during init time, even before the
# network is up, and then send it a SIGHUP here to make it start
# bootstrapping swiftly, but it doesn't work because of a bug in
# Tor. Details:
# * https://trac.torproject.org/projects/tor/ticket/1247
# * https://tails.boum.org/bugs/tor_vs_networkmanager/
# To work around this we restart Tor, but not using restart-tor since
# it validates that bootstraping succeeds. That cannot happen until
# Tor Launcher has started (below) and the user is done configuring
# it.
systemctl restart tor@default.service

/usr/local/sbin/tails-tor-launcher &

# Wait until the user has done the Tor Launcher configuration.
until [ "$(tor_control_getconf DisableNetwork)" = 0 ]; do
    sleep 1
done
