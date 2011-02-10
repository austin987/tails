#!/bin/sh

echo "managing initscripts"

# enable custom initscripts
update-rc.d tails-detect-virtualization start 17 S .
update-rc.d tails-kexec                    stop 85 0 6 .
update-rc.d tails-wifi start 17 S .
update-rc.d memlockd start 22 2 3 4 5 .
update-rc.d tails-sdmem-on-media-removal start 23 2 3 4 5 . stop 01 0 6

# we run Tor ourselves after HTP via NetworkManager hooks
update-rc.d tor disable

# we reboot/halt using kexec->sdmem
update-rc.d -f halt   remove
update-rc.d -f reboot remove

# we provide our own tails-kexec initscript (more friendly to ejected CD/USB)
update-rc.d -f kexec  remove

# we use kexec on halt too => enable kexec-load initscript on runlevel 0 as well
update-rc.d -f kexec-load remove
update-rc.d kexec-load stop 18 0 6 .
