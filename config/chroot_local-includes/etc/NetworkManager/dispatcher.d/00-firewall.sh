#!/bin/sh

set -e

# Run whenever an interface gets "up", not otherwise:
if [ "$2" != "up" ]; then
   exit 0
fi

[ -x /usr/sbin/ferm ] || exit 2
/usr/sbin/ferm /etc/ferm/ferm.conf
