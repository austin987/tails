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

    iptables -I OUTPUT 1 ! -o lo -m owner --uid-owner debian-tor -j REJECT
    iptables -I OUTPUT 1 -d $BRIDGE_IP -j ACCEPT

If you want to test tor-not-working-but-default-bridges-are-working, you can use:

    apt install -y ipset && ipset create defaultbridges hash:ip
    grep -w obfs4 /usr/share/tails/tca/default_bridges.txt |
      grep -Po '(\d{1,3}\.){3}\d{1,3}:\d{1,5}' |
      cut -d: -f1 | sort -u |
      while read ip; do ipset add defaultbridges $ip; done
    iptables -I OUTPUT 1 ! -o lo -m owner --uid-owner debian-tor -m set ! --match-set defaultbridges dst -j REJECT

Reset TCA state
-------------

tca state is kept in `/var/lib/tca/` . That directory is owned by root, and a regular user can't
access, nor delete it.

    sudo rm -rf /var/lib/tca/

Really restart tor
---------------------

just using `systemctl restart tor@default` is probably not what you want. This is what you probably want:

    systemctl stop tor@default
    find /var/lib/tor/ -mindepth 1 -delete
    echo DisableNetwork 1 >> /etc/tor/torrc
    systemctl start tor@default

Simulate a slow network
-------------------------

    wget https://slow.vado.li/ -O slow
    chmod +x slow
    ./slow 56k

Command line options
--------------------

amensia can only run tca with no options. Any argument is ignored. However, tca *has* options. You can enable
them editing /usr/local/bin/tca, adding `sys.argv[1:]` to the list of arguments.

Debug more
----------

tca honors the debug kernel cmdline flag; if passed, its `--log-level` will default to DEBUG, not INFO.

tca will send logs to syslog when run without a tty attached (ie: on the automatic nm-dispatcher thing), but
will send logs to stderr when run from terminal. This behaviour can be changed using `--log-target`

Change interface CSS
---------------------

yes, gtk has css ;)

TCA style file is in `/usr/share/tails/tca/tca.css`.

To try real-time changes, you can edit `/usr/local/bin/tca` and look for `# "GTK_DEBUG=interactive",`.
Uncomment the  line, removing the hash. Now start `tca` again and you will have gtk inspector running!

