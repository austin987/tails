#!/bin/sh

# Ensure that we are using dependency based boot
if ! dpkg -s insserv >/dev/null 2>&1 || [ -f /etc/init.d/.legacy-bootordering ]; then
	echo "Dependency based boot sequencing is not configured. Aborting." >&2
	exit 1
fi

echo "managing initscripts"

# enable custom initscripts
update-rc.d tails-detect-virtualization start 17 S .
update-rc.d tails-kexec                    stop 85 0 6 .
update-rc.d tails-reconfigure-kexec start 23 2 3 4 5 .
update-rc.d tails-reconfigure-memlockd start 23 2 3 4 5 .
update-rc.d tails-sdmem-on-media-removal start 24 2 3 4 5 . stop 01 0 6

# Start memlockd before media removal watchdog and skip stop on shutdown to
# keep files needed by tails-kexec properly in memory.
update-rc.d -f memlockd remove
sed -e '/^### BEGIN INIT INFO$/,/^### END INIT INFO$/ {
          s/^\(# Required-Stop:\).*$/\1/
          s/^\(# Default-Stop:\).*$/\1/
        }' -i /etc/init.d/memlockd
update-rc.d memlockd start 22 2 3 4 5 .

# we run Tor ourselves after HTP via NetworkManager hooks
update-rc.d tor disable

# we provide our own tails-kexec initscript (more friendly to ejected CD/USB)
update-rc.d -f kexec  remove

# we use kexec on halt too => enable kexec-load initscript on runlevel 0 as well
update-rc.d -f kexec-load remove
update-rc.d kexec-load stop 18 0 6 .

# i2p should not start per default. At some point we want some script to start
# i2p during init if so selected in tails-greeter, but ATM users have to start
# the i2p script manually.

update-rc.d -f i2p remove

# we only want hdparm so that laptop-mode-tools can use it
update-rc.d hdparm disable

# don't use plymouth at shutdown/reboot
# (plymouth.postinst creates links using update-rc.d,
# so we cannot disable the links it creates by using LSB headers)
rm -f /etc/rc[06].d/*plymouth

# gdomap is not used between processes running as the same user on the same host
update-rc.d gdomap disable

# we start NetworkManager ourselves, via tails-greeter, at PostLogin time
update-rc.d network-manager disable
