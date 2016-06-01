#!/bin/sh

date > /etc/vagrant_box_build_time

# Set up sudo
cp /etc/sudoers /etc/sudoers.orig
sed -i -e 's/^%sudo\W.*$/%sudo ALL=NOPASSWD:ALL/' /etc/sudoers

# Install vagrant keys
mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
curl -Lo /home/vagrant/.ssh/authorized_keys \
  'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub'
chmod 0600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# Tweak sshd to prevent DNS resolution (speed up logins)
echo 'UseDNS no' >> /etc/ssh/sshd_config

# Customize the message of the day
echo 'Welcome to your Vagrant-built virtual machine.' > /var/run/motd

# Removing leftover DHCP leases
rm /var/lib/dhcp/*.leases

# Adding a 2 sec delay to the interface up, to make the dhclient happy
echo "pre-up sleep 5" >> /etc/network/interfaces

# Clean downloaded APT packages
apt-get clean

# Remove HTTP proxy configuration
sed -e '/http::Proxy/d' -i /etc/apt/apt.conf

# Remove installation logs
rm -rf /var/log/installer

# Clean up veewee's vbox additions iso. We don't use it, actually.
rm -f /home/vagrant/VBoxGuestAdditions_*.iso

# Clean up some APT stuff that will be recreated after the first
# apt-get update during provision.
rm -rf /var/lib/apt/lists
rm -f /var/cache/apt/*pkgcache.bin

# Zero out the free space to save space in the final image:
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY

exit 0
