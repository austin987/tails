#!/bin/sh
set -e
set -u

# Based on ypcs' scripts found at:
#     https://github.com/ypcs/vmdebootstrap-vagrant/

echo "$(date)" > /var/lib/vagrant_box_build_time

export DEBIAN_FRONTEND="noninteractive"

echo "I: Add sudo permissions to user vagrant..."
cat > /etc/sudoers.d/vagrant << EOF
vagrant         ALL=(ALL) NOPASSWD: ALL
EOF

echo "I: Add pubkey for vagrant..."
mkdir -p /home/vagrant/.ssh
cat > /home/vagrant/.ssh/authorized_keys << EOF
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key
EOF
chown -R vagrant:vagrant /home/vagrant
chmod 0700 /home/vagrant/.ssh

echo "I: Configuring APT..."
cat > /etc/apt/apt.conf.d/99recommends << EOF
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF

echo "I: Installing extra dependencies..."
apt-get -y install grub2 openssh-server curl
sed -i 's,^GRUB_TIMEOUT=5,GRUB_TIMEOUT=1,g' /etc/default/grub

echo "I: Disable DNS checks to speed-up SSH logins..."
echo "UseDNS no" >>/etc/ssh/sshd_config

# By default, Debian's ssh client forwards the locale env vars, and by
# default, Debian's sshd accepts them. The locale used while building
# could have affects on the resulting image, so let's fix on a single
# locale for all (namely the one we won't purge below).
echo "I: Disable sshd AcceptEnv..."
sed -i 's/^AcceptEnv/#AcceptEnv/' /etc/ssh/sshd_config

echo "I: Running localepurge..."
TEMPFILE="$(mktemp)"

cat > "${TEMPFILE}" << EOF
localepurge  localepurge/dontbothernew     boolean false
localepurge  localepurge/quickndirtycalc   boolean true
localepurge  localepurge/mandelete         boolean true
localepurge  localepurge/use-dpkg-feature  boolean false
localepurge  localepurge/showfreedspace    boolean true
localepurge  localepurge/verbose           boolean false
localepurge  localepurge/remove_no         note
localepurge  localepurge/nopurge           multiselect en, en_US, en_US.UTF-8
localepurge  localepurge/none_selected     boolean false
EOF

debconf-set-selections < "${TEMPFILE}"
apt-get -y install localepurge
localepurge
apt-get -y remove localepurge
rm -f "${TEMPFILE}"

echo "I: Cleaning up..."
apt-get -y autoremove
apt-get clean
rm -rf \
   /var/lib/apt/lists/* \
   /var/lib/apt/lists/partial/* \
   /var/cache/apt/*.bin \
   /var/cache/apt/archives/*.deb \
   /var/log/installer \
   /var/lib/dhcp/* \
    || :

echo "I: Zeroing out the free space to save space in the final image..."
dd if=/dev/zero of=/EMPTY bs=1M || :
rm -f /EMPTY || :

exit 0
