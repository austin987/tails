#!/bin/sh

# Run whenever an interface gets "up", not otherwise:
if [ "$2" != "up" ]; then
   exit 0
fi

/usr/sbin/ferm /etc/ferm/ferm.conf
