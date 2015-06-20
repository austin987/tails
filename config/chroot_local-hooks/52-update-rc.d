#!/bin/sh

set -e

CUSTOM_INITSCRIPTS="
"

PATCHED_INITSCRIPTS="
gdomap
haveged
hdparm
hwclock.sh
i2p
kexec-load
laptop-mode
memlockd
resolvconf
saned
spice-vdagent
tor
ttdnsd
"

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
systemctl enable tails-autotest-remote-shell.service
systemctl enable tails-reconfigure-kexec.service
systemctl enable tails-reconfigure-memlockd.service
systemctl enable tails-sdmem-on-media-removal.service
systemctl enable tails-set-wireless-devices-state.service
systemctl enable tails-wait-until-tor-has-bootstrapped.service
systemctl enable tor-controlport-filter.service

# Enable our own systemd user unit files
systemctl --global enable tails-add-GNOME-bookmarks.service
systemctl --global enable tails-configure-keyboard.service
systemctl --global enable tails-create-tor-browser-directories.service
systemctl --global enable tails-security-check.service
systemctl --global enable tails-upgrade-frontend.service
systemctl --global enable tails-virt-notify-user.service
systemctl --global enable tails-wait-until-tor-has-bootstrapped.service
systemctl --global enable tails-warn-about-disabled-persistence.service

# Use socket activation only, to save a bit of memory and boot time
systemctl disable cups.service
systemctl enable  cups.socket

# We're starting NetworkManager ourselves
systemctl disable NetworkManager.service
systemctl disable NetworkManager-wait-online.service

# Don't hide tails-kexec's shutdown messages with an empty splash screen
for suffix in halt kexec poweroff reboot shutdown ; do
   systemctl mask "plymouth-${suffix}.service"
done

# systemd-networkd fallbacks to Google's nameservers when no other nameserver
# is provided by the network configuration. In Jessie, this service is disabled
# by default, but it feels safer to make this explicit. Besides, it might be
# that systemd-networkd vs. firewall setup ordering is suboptimal in this respect,
# so let's avoid any risk of DNS leaks here.
systemctl mask systemd-networkd.service
