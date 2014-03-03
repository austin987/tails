#! /bin/sh

# Run only when the interface is not "lo":
if [ $1 = "lo" ]; then
   exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ $2 != "up" ]; then
   exit 0
fi

# Restart Vidalia because it does not automatically reconnect to the new
# Tor instance. Use kill+start as:
# - X-GNOME-AutoRestart does not exist in Lenny's Gnome
# - we do not start Vidalia automatically anymore and *this* is the time
#   when it is supposed to start.
restart-vidalia
