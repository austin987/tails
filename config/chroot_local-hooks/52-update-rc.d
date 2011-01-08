#!/bin/sh

echo "managing initscripts"

# enable custom initscripts
update-rc.d tails-detect-virtualization defaults
update-rc.d tails-disable-init-concurrency defaults
update-rc.d tails-wifi defaults

# we run Tor ourselves after HTP via NetworkManager hooks
update-rc.d tor disable
