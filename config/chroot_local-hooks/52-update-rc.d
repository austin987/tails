#!/bin/sh

set -e

CUSTOM_INITSCRIPTS="
"

PATCHED_INITSCRIPTS="
alsa-utils
gdomap
haveged
hdparm
hwclock.sh
i2p
kexec-load
laptop-mode
memlockd
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
systemctl enable tails-tor-has-bootstrapped.target
systemctl enable tails-wait-until-tor-has-bootstrapped.service
systemctl enable tails-tor-has-bootstrapped-flag-file.service
systemctl enable tor-controlport-filter.service

# Enable our own systemd user unit files
systemctl --global enable tails-add-GNOME-bookmarks.service
systemctl --global enable tails-configure-keyboard.service
systemctl --global enable tails-create-tor-browser-directories.service
systemctl --global enable tails-security-check.service
systemctl --global enable tails-upgrade-frontend.service
systemctl --global enable tails-virt-notify-user.service
systemctl --global enable tails-wait-until-tor-has-bootstrapped.service

# Use socket activation only, to delay the startup of cupsd.
# In practice, on Jessie this means that cupsd is started during
# the initialization of the GNOME session, which is fine: by then,
# the persistent /etc/cups has been mounted.
# XXX: make sure it's the case on Stretch, adjust if not.
systemctl disable cups.service
systemctl enable  cups.socket

# We're starting NetworkManager, Tor and ttdnsd ourselves.
# We disable tor.service (as opposed to tor@default.service) because
# it's an important goal to never start Tor before the user has had
# a chance to choose to do so in an obfuscated way: if some other
# package enables tor@whatever.service someday, disabling tor.service
# will disable it as well, while disabling tor@default.service would not.
systemctl disable tor.service
systemctl disable NetworkManager.service
systemctl disable NetworkManager-wait-online.service
systemctl disable ttdnsd.service

# We don't run these services by default
systemctl disable gdomap.service
systemctl disable hdparm.service
systemctl disable i2p.service

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

# Do not sync the system clock to the hardware clock on shutdown
systemctl mask hwclock-save.service

# Do not run timesyncd: we have our own time synchronization mechanism
systemctl mask systemd-timesyncd.service

# Unmute and sanitize mixer levels at boot time
# (`systemctl unmask` does not support initscripts on Jessie,
# hence the manual unmasking)
dpkg-divert --add --rename --divert \
	    /lib/systemd/system/alsa-utils.service.orig \
	    /lib/systemd/system/alsa-utils.service
# Disable the ALSA state store/restore systemd services (that lack mixer
# levels unmuting/sanitizing), we use the legacy initscript instead
systemctl mask alsa-restore.service
systemctl mask alsa-state.service
systemctl mask alsa-store.service
