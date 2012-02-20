#! /bin/sh

# Run only when the interface is not "lo":
if [ $1 = "lo" ]; then
   exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ $2 != "up" ]; then
   exit 0
fi

# Get LIVE_USERNAME
. /etc/live/config.d/username

# Restart Vidalia because it does not automatically reconnect to the new
# Tor instance. Use kill+start as:
# - X-GNOME-AutoRestart does not exist in Lenny's Gnome
# - we do not start Vidalia automatically anymore and *this* is the time
#   when it is supposed to start.
if killall vidalia 2> /dev/null; then
   sleep 2 # give lckdo a chance to release the lockfile
fi
export DISPLAY=':0.0'
export XAUTHORITY="`echo /var/run/gdm3/auth-for-${LIVE_USERNAME}-*/database`"
exec /bin/su -c /usr/local/bin/vidalia-wrapper "${LIVE_USERNAME}" &
