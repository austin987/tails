#!/bin/sh

set -e

# Run only when the interface is not "lo":
if [ "$1" = "lo" ]; then
        exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ "$2" != "up" ]; then
   exit 0
fi

/usr/local/sbin/tails-additional-software upgrade
