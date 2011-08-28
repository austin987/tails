#! /bin/sh

# Run only when the interface is not "lo":
if [ $1 = "lo" ]; then
   exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ $2 != "up" ]; then
   exit 0
fi

PIDFILE=/var/run/tor/tor.pid

# Get LIVE_USERNAME
. /etc/live/config.d/username

# Workaround https://trac.torproject.org/projects/tor/ticket/2355
if grep -qw bridge /proc/cmdline; then
    rm -f /var/lib/tor/*
fi

# We don't start Tor automatically anymore so *this* is the time when
# it is supposed to start.
# Note: as we disabled the initscript automatic startup, we cannot use
# invoke-rc.d: it would silently ignore our request. That's why we use
# the good old direct initscript invocation rather than any fancy
# frontend.
if [ -r "${PIDFILE}" ]; then
    # A SIGHUP should be enough but there's a bug in Tor. Details:
    # * https://bugs.torproject.org/flyspray/index.php?do=details&id=1247
    # * https://tails.boum.org/bugs/tor_vs_networkmanager/
    /etc/init.d/tor restart
else
    /etc/init.d/tor start
fi

# Restart ttdnsd
service ttdnsd restart

# Restart Vidalia because it does not automatically reconnect to the new
# Tor instance. Use kill+start as:
# - X-GNOME-AutoRestart does not exist in Lenny's Gnome
# - we do not start Vidalia automatically anymore and *this* is the time
#   when it is supposed to start.
killall vidalia
sleep 2 # give lckdo a chance to release the lockfile
export DISPLAY=':0.0'
export XAUTHORITY="`echo /var/run/gdm3/auth-for-${LIVE_USERNAME}-*/database`"
exec /bin/su -c /usr/local/bin/vidalia-wrapper "${LIVE_USERNAME}" &
