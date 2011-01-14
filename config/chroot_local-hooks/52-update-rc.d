#!/bin/sh

echo "managing initscripts"

# enable custom initscripts
update-rc.d tails-detect-virtualization start 17 S .
update-rc.d tails-disable-init-concurrency defaults
update-rc.d tails-wifi start 17 S .

# we run Tor ourselves after HTP via NetworkManager hooks
update-rc.d tor disable
