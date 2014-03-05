#! /bin/sh

# Run only when the interface is not "lo":
if [ $1 = "lo" ]; then
   exit 0
fi

if [ "${2}" = "up" ]; then
   # Restart Vidalia because it does not automatically reconnect to the new
   # Tor instance. Use kill+start as:
   # - X-GNOME-AutoRestart does not exist in Lenny's Gnome
   # - we do not start Vidalia automatically anymore and *this* is the time
   #   when it is supposed to start.
   restart-vidalia
elif [ "${2}" = "down" ]; then
   killall vidalia
fi
