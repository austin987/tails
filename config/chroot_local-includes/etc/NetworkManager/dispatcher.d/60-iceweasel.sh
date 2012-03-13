#! /bin/sh

# Run only when the interface is not "lo":
if [ $1 = "lo" ]; then
   exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ $2 != "up" ]; then
   exit 0
fi

# There's nothing to do if Iceweasel is already running
if pidof firefox-bin 1>/dev/null 2>&1; then
   exit 0
fi

# Get LIVE_USERNAME
. /etc/live/config.d/username
export DISPLAY=':0.0'
export XAUTHORITY="`echo /var/run/gdm3/auth-for-${LIVE_USERNAME}-*/database`"
exec /bin/su -c iceweasel &
