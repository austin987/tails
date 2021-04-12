Hacking tips for TCA
=======================

This document provides tips&tricks for hacking on tca. NONE of this tricks is safe to use on a regular Tails.
They can lead to deanonymization!


Testing failures
-------------------

If you want to test failures to Tor connection, the easiest thing you can do is block any outgoing connection
from the debian-tor users

    iptables -I OUTPUT 1 ! -o lo -m owner --uid-owner debian-tor -j REJECT

If you want to test tor-not-working-but-my-bridges-are-working, you can use

    iptables -I OUTPUT 1 -d $BRIDGE_IP -j ACCEPT
    iptables -I OUTPUT 1 -m owner --uid-owner debian-tor -j REJECT

Reset state
-------------

tca state is kept in `/home/amnesia/.config/tca/` . That directory is owned by root, and a regular user can't
access, nor delete it.

    sudo rm -rf /home/amnesia/.config/tca/

Command line options
--------------------

amensia can only run tca with no options. Any argument is ignored. However, tca *has* options. You can enable
them editing /usr/local/bin/tca, adding `sys.argv[1:]` to the list of arguments.

Debug more
----------

tca honors the debug kernel cmdline flag; if passed, its `--log-level` will default to DEBUG, not INFO.

tca will send logs to syslog when run without a tty attached (ie: on the automatic nm-dispatcher thing), but
will send logs to stderr when run from terminal. This behaviour can be changed using `--log-target`
