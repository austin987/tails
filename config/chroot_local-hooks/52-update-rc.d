#!/bin/sh

set -e

CUSTOM_INITSCRIPTS="
tails-detect-virtualization
tails-kexec
tails-reconfigure-kexec
tails-reconfigure-memlockd
tails-sdmem-on-media-removal
tails-set-wireless-devices-state
"

PATCHED_INITSCRIPTS="
alsa-utils
gdomap
haveged
hdparm
kexec
kexec-load
laptop-mode
memlockd
network-manager
plymouth
polipo
resolvconf
saned
spice-vdagent
tor
ttdnsd
"

# Ensure that we are using dependency based boot
if ! dpkg -s insserv >/dev/null 2>&1 || [ -f /etc/init.d/.legacy-bootordering ]; then
	echo "Dependency based boot sequencing is not configured. Aborting." >&2
	exit 1
fi

echo "configuring boot sequence"

# The patches to adjust the runlevels are applied to the chroot
# after the packages have been installed. So we need to remove them first,
# to re-install them with our settings.
insserv -r $PATCHED_INITSCRIPTS

# Re-install overriden initscripts and install our custom ones.
insserv $PATCHED_INITSCRIPTS $CUSTOM_INITSCRIPTS
