#!/bin/sh

set -e

CUSTOM_INITSCRIPTS="
tails-kexec
"

PATCHED_INITSCRIPTS="
gdomap
haveged
hdparm
i2p
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

echo "Configuring boot sequence"

# The patches to adjust the runlevels are applied to the chroot
# after the packages have been installed. So we need to remove them first,
# to re-install them with our settings.
insserv -r $PATCHED_INITSCRIPTS

# Re-install overriden initscripts and install our custom ones.
insserv $PATCHED_INITSCRIPTS $CUSTOM_INITSCRIPTS

### Tweak systemd unit files

# Workaround for https://bugs.debian.org/714957
systemctl enable memlockd.service

# Enable our own systemd unit files
systemctl enable tails-reconfigure-kexec.service
systemctl enable tails-reconfigure-memlockd.service
systemctl enable tails-sdmem-on-media-removal.service
systemctl enable tails-set-wireless-devices-state.service
systemctl enable tor-controlport-filter.service

# Use socket activation only, to save a bit of memory and boot time
systemctl disable cups.service
systemctl enable  cups.socket
