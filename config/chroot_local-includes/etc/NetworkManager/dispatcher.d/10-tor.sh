#!/bin/sh

# We don't start Tor automatically so *this* is the time
# when it is supposed to start.

# Run only when the interface is not "lo":
if [ $1 = "lo" ]; then
   exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ $2 != "up" ]; then
   exit 0
fi

# Import tor_control_*(), TOR_LOG
. /usr/local/lib/tails-shell-library/tor.sh

# It's safest that Tor is not running when messing with its log and
# data dir.
service tor stop

# Workaround https://trac.torproject.org/projects/tor/ticket/2355
if grep -qw bridge /proc/cmdline; then
   rm -f /var/lib/tor/*
fi

# We depend on grepping stuff from the Tor log (especially for
# tordate/20-time.sh), so deleting it seems like a Good Thing(TM).
rm -f "${TOR_LOG}"

# A SIGHUP should be enough but there's a bug in Tor. Details:
# * https://trac.torproject.org/projects/tor/ticket/1247
# * https://tails.boum.org/bugs/tor_vs_networkmanager/
restart-tor

if grep -qw bridge /proc/cmdline; then
   # When using a bridge Tor reports TLS cert lifetime errors
   # (e.g. when the system clock is way off) with severity "info", but
   # when no bridge is used the severity is "warn". tordate/20-time.sh
   # depends on grepping these error messages, so we temporarily
   # increase Tor's logging severity.
   tor_control_setconf "Log=\"info file ${TOR_LOG}\""

   # In bridge mode Vidalia needs to start before tordate (20-time.sh)
   # since we need bridges to be configured before any consensus or
   # descriptors can be downloaded, which tordate depends on.
   restart-vidalia
fi
