#! /bin/sh

# Run only when the interface is not "lo":
if [ -z "$1" ] || [ "$1" = "lo" ]; then
   exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ "$2" != "up" ]; then
   exit 0
fi

# Import tor_has_bootstrapped()
. /usr/local/lib/tails-shell-library/systemd.sh

# Get LANG
. /etc/default/locale
export LANG

# Initialize gettext support
. gettext.sh
TEXTDOMAIN="tails"
export TEXTDOMAIN

while ! tor_has_bootstrapped; do
   sleep 1
done

/usr/local/sbin/tails-notify-user \
   "`gettext \"Tor is ready\"`" \
   "`gettext \"You can now access the Internet.\"`"
