#!/bin/sh
set -e
set -u

# Based on ypcs' scripts found at:
#     https://github.com/ypcs/vmdebootstrap-vagrant/

echo "$(date)" > /var/lib/vagrant_box_build_time

export DEBIAN_FRONTEND="noninteractive"

echo "I: Adding sudo permissions to user vagrant..."
cat > /etc/sudoers.d/vagrant << EOF
vagrant         ALL=(ALL) NOPASSWD: ALL
EOF

echo "I: Adding pubkey for vagrant..."
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
cat > /etc/apt/apt.conf.d/99retries << EOF
APT::Acquire::Retries "20";
EOF
# This effectively disables apt-daily*.{timer,service}, which might
# interfere with an ongoing build. We run apt-get
# {update,dist-upgrade,clean} ourselves in setup-tails-builder.
cat > /etc/apt/apt.conf.d/99periodic << EOF
APT::Periodic::Enable "0";
EOF

echo "I: Installing Tails APT repo signing key..."
apt-get -y install gnupg
apt-key add /tmp/tails.binary.gpg

echo "I: Adding standard APT suites..."
cat "/etc/apt/sources.list" | \
	sed -e 's/buster/buster-updates/' \
	> "/etc/apt/sources.list.d/buster-updates.list"

echo "deb http://time-based.snapshots.deb.tails.boum.org/debian-security/${DEBIAN_SECURITY_SERIAL}/ buster/updates main" \
	> "/etc/apt/sources.list.d/buster-security.list"

echo "I: Adding our builder-jessie suite with live-build and po4a..."
echo "deb http://time-based.snapshots.deb.tails.boum.org/tails/${TAILS_SERIAL}/ builder-jessie main" > "/etc/apt/sources.list.d/tails.list"
sed -e 's/^[[:blank:]]*//' > /etc/apt/preferences.d/tails <<EOF
	Package: *
	Pin: release o=Tails,n=builder-jessie
	Pin-Priority: 99
EOF
sed -e 's/^[[:blank:]]*//' > /etc/apt/preferences.d/live-build <<EOF
	Package: live-build
	Pin: release o=Tails,n=builder-jessie
	Pin-Priority: 999
EOF
# Install po4a 0.47 for now (#17005)
sed -e 's/^[[:blank:]]*//' > /etc/apt/preferences.d/po4a <<EOF
	Package: po4a
	Pin: release o=Tails,n=builder-jessie
	Pin-Priority: 999
EOF

sed -e 's/^[[:blank:]]*//' > /etc/apt/preferences.d/buster-backports << EOF
	Package: *
	Pin: release n=buster-backports
	Pin-Priority: 100
EOF

apt-get update

echo "I: Installing Vagrant dependencies..."
apt-get -y install ca-certificates curl grub2 openssh-server wget

echo "I: Configuring GRUB..."
sed -i 's,^GRUB_TIMEOUT=5,GRUB_TIMEOUT=1,g' /etc/default/grub

echo "I: Installing Tails build dependencies..."
apt-get -y install \
        debootstrap \
        dosfstools \
        dpkg-dev \
        eatmydata \
        faketime \
        gdisk \
        gettext \
        gir1.2-udisks-2.0 \
        git \
        ikiwiki \
        intltool \
        libfile-chdir-perl \
        libfile-slurp-perl \
        libhtml-scrubber-perl \
        libhtml-template-perl \
        liblist-moreutils-perl \
        libtext-multimarkdown-perl \
        libtimedate-perl \
        liburi-perl libhtml-parser-perl \
        libxml-simple-perl \
        libyaml-libyaml-perl po4a \
        libyaml-perl \
        libyaml-syck-perl \
        live-build \
        lsof \
        mtools \
        perlmagick \
        psmisc \
        python3-gi \
        rsync \
        ruby \
        syslinux \
        syslinux-common \
        syslinux-utils \
        time \
        udisks2 \
        whois

# Ensure we can use timedatectl
apt-get -y install dbus

# Start apt-cacher-ng inside the VM only if the "in-VM proxy" is to be used.
echo "I: Installing the caching proxy..."
apt-get -o Dpkg::Options::="--force-confold" -y install apt-cacher-ng
systemctl disable apt-cacher-ng.service

echo "I: Upgrading system..."
apt-get -y dist-upgrade

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

echo "I: Disabling irrelevant timers"
# By default we reboot the system between each build, which makes this
# timer useless. Besides, it is started 15 minutes after boot, which
# has potential to interfere with an ongoing build.
systemctl mask systemd-tmpfiles-clean.timer

echo "I: Cleaning up..."
apt-get -y autoremove
apt-get clean
rm -rf \
   /var/lib/apt/lists/* \
   /var/lib/apt/lists/partial/* \
   /var/cache/apt/*.bin \
   /var/cache/apt/archives/*.deb \
   /var/log/installer \
   /var/lib/dhcp/*

exit 0
