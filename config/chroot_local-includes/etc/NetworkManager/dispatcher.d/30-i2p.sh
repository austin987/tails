#!/bin/sh

# I2P isn't started automatically at system boot.
# Instead, it is started with this hook script.

# Don't even try to run this script if I2P is not enabled.
grep -qw "i2p" /proc/cmdline || exit 0

# don't run if interface is 'lo'
[ $1 = "lo" ] && exit 0

# Get LANG
. /etc/default/locale
export LANG

# Initialize gettext support
. gettext.sh
TEXTDOMAIN="tails"
export TEXTDOMAIN

fail() {
    /usr/local/sbin/tails-notify-user \
        "`gettext \"I2P failed to start\"`" \
        "`gettext \"Something went wrong when I2P was starting. Check the logs in /var/log/i2p for more information.\"`"
        service i2p stop # clean up, just in case
        exit 0
}

check_if_ready() {
    local COUNT=1
    # Wait up to 20 seconds for $1 to be ready. This should take a couple of seconds or less.
    until [ -r "$1" ]; do
        if [ $COUNT -eq 20 ]; then
            fail
        fi
        COUNT=$(expr $COUNT + 1)
        sleep 1
    done
}

start_i2p() {
    service i2p start
    check_if_ready "/run/i2p/i2p.pid"
}

# Run when an interface's status changes
if [ $2 = "up" ]; then
    if check_if_ready "/run/tordate/done"; then
        start_i2p
    fi
elif [ "$2" = "down" ]; then
    service i2p stop
fi
