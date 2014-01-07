#! /bin/sh

# Run only when the interface is not "lo":
if [ $1 = "lo" ]; then
   exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ $2 != "up" ]; then
   exit 0
fi

# Initialize gettext support
. gettext.sh
TEXTDOMAIN="tails"
export TEXTDOMAIN

/usr/local/sbin/tails-notify-user \
   "`gettext \"Tor is now ready\"`" \
   "`gettext \"Tor is ready. You can now use the Internet.\"`"
