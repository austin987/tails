#!/bin/sh

# I2P isn't started automatically at system boot.
# Instead, it is started with this hook script.

# Don't even try to run this script if I2P is not enabled.
grep -qw "i2p" /proc/cmdline || exit 0

# don't run if interface is 'lo'
[ $1 = "lo" ] && exit 0

if [ $2 = "up" ]; then
    /usr/local/sbin/tails-i2p start &
fi
