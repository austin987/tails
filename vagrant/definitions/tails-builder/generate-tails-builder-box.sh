#!/bin/sh

set -e
set -u
set -x

GIT_DIR="$(git rev-parse --show-toplevel)"

build_setting() {
    ruby -I "${GIT_DIR}/vagrant/lib" \
         -e "require 'tails_build_settings.rb'; print ${1}"
}

get_serial() {
    (
        cd "${GIT_DIR}/vagrant/definitions/tails-builder/"
        "${GIT_DIR}"/auto/scripts/apt-snapshots-serials \
            cat --print-serials-only "${1}"
    )
}

SPECFILE="$(mktemp)"
TARGET_NAME="$(build_setting box_name)"
TARGET_FS_TAR="${TARGET_NAME}.tar"
TARGET_IMG="${TARGET_NAME}.img"
TARGET_QCOW2="${TARGET_NAME}.qcow2"
TARGET_BOX="${TARGET_NAME}.box"
DISTRIBUTION="$(build_setting DISTRIBUTION)"
HOSTNAME="vagrant-${DISTRIBUTION}"
USERNAME="vagrant"
PASSWORD="vagrant"

DEBIAN_SERIAL="$(get_serial debian)"
DEBIAN_SECURITY_SERIAL="$(get_serial debian-security)"
TAILS_SERIAL="$(get_serial tails)"

DEBOOTSTRAP_GNUPG_HOMEDIR="$(mktemp -d)"
gpg --homedir "${DEBOOTSTRAP_GNUPG_HOMEDIR}" \
    --no-tty \
    --import config/chroot_sources/tails.chroot.gpg
DEBOOTSTRAP_GNUPG_PUBRING="${DEBOOTSTRAP_GNUPG_HOMEDIR}/pubring.kbx"
if [ ! -e "${DEBOOTSTRAP_GNUPG_PUBRING}" ]; then
    DEBOOTSTRAP_GNUPG_PUBRING="${DEBOOTSTRAP_GNUPG_HOMEDIR}/pubring.gpg"
fi

# Create specification file for vmdb2
cat > "${SPECFILE}" <<EOF
steps:
  - mkimg: "{{ output }}"
    size: 20G

  - mklabel: msdos
    device: "{{ output }}"

  - mkpart: primary
    device: "{{ output }}"
    start: 1M
    end: 10M
    tag: unused

  - mkpart: primary
    device: "{{ output }}"
    start: 10M
    end: 100%
    tag: rootfs

  - kpartx: "{{ output }}"

  - mkfs: ext4
    partition: rootfs
    label: smoke

  - mount: rootfs

  - unpack-rootfs: rootfs

  - debootstrap: ${DISTRIBUTION}
    mirror: http://time-based.snapshots.deb.tails.boum.org/debian/${DEBIAN_SERIAL}
    keyring: ${DEBOOTSTRAP_GNUPG_PUBRING}
    target: rootfs
    unless: rootfs_unpacked

  - cache-rootfs: rootfs
    unless: rootfs_unpacked

  - create-file: /etc/network/interfaces.d/wired
    contents: |
      auto eth0
      iface eth0 inet dhcp
      iface eth0 inet6 auto

  - chroot: rootfs
    shell: echo ${HOSTNAME} > /etc/hostname

  - copy-file: /tmp/tails.binary.gpg
    src: config/chroot_sources/tails.binary.gpg

  - apt: install
    packages:
      - gnupg
    mirror: http://time-based.snapshots.deb.tails.boum.org/debian/${DEBIAN_SERIAL}
    tag: rootfs
    unless: rootfs_unpacked

  - chroot: rootfs
    shell: apt-key add /tmp/tails.binary.gpg

  - create-file: /etc/apt/apt.conf.d/99recommends
    contents: |
      APT::Install-Recommends "false";
      APT::Install-Suggests "false";

  - create-file: /etc/apt/apt.conf.d/99retries
    contents: |
      APT::Acquire::Retries "20";

  - create-file: /etc/apt/apt.conf.d/99periodic
    contents: |
      APT::Periodic::Enable "0";

  - chroot: rootfs
    shell: |
      sed -e 's/${DISTRIBUTION}/${DISTRIBUTION}-updates/' /etc/apt/sources.list \
        > "/etc/apt/sources.list.d/${DISTRIBUTION}-updates.list"

  - create-file: /etc/apt/sources.list.d/${DISTRIBUTION}-security.list
    contents: |
      deb http://time-based.snapshots.deb.tails.boum.org/debian-security/${DEBIAN_SECURITY_SERIAL}/ ${DISTRIBUTION}/updates main

  - create-file: /etc/apt/sources.list.d/tails.list
    contents: |
      deb http://time-based.snapshots.deb.tails.boum.org/tails/${TAILS_SERIAL}/ builder-jessie main

  - create-file: /etc/apt/preferences.d/tails
    contents: |
      Package: *
      Pin: release o=Tails,n=builder-jessie
      Pin-Priority: 99

  - create-file: /etc/apt/preferences.d/live-build
    contents: |
      Package: live-build
      Pin: release o=Tails,n=builder-jessie
      Pin-Priority: 999

  - create-file: /etc/apt/preferences.d/${DISTRIBUTION}-backports
    contents: |
      Package: *
      Pin: release n=${DISTRIBUTION}-backports
      Pin-Priority: 100

  - chroot: rootfs
    shell: apt update

  - apt: install
    packages:
      - apt-cacher-ng
      - ca-certificates
      - curl
      - dbus
      - debootstrap
      - dosfstools
      - dpkg-dev
      - gdisk
      - gettext
      - gir1.2-udisks-2.0
      - git
      - grub2
      - ikiwiki
      - intltool
      - libfile-slurp-perl
      - libimage-magick-perl
      - liblist-moreutils-perl
      - libtimedate-perl
      - libyaml-syck-perl
      - linux-image-amd64
      - live-build
      - lsof
      - mtools
      - openssh-server
      - po4a
      - psmisc
      - python3-gi
      - rsync
      - ruby
      - sudo
      - time
      - udisks2
      - wget
    mirror: http://time-based.snapshots.deb.tails.boum.org/debian/${DEBIAN_SERIAL}
    tag: rootfs
    unless: rootfs_unpacked

  - chroot: rootfs
    shell: apt-get -y dist-upgrade

  - chroot: rootfs
    shell: |
      echo "UseDNS no" >>/etc/ssh/sshd_config
      sed -i 's/^AcceptEnv/#AcceptEnv/' /etc/ssh/sshd_config

  - create-file: /tmp/localepurge.txt
    contents: |
      localepurge  localepurge/dontbothernew     boolean false
      localepurge  localepurge/quickndirtycalc   boolean true
      localepurge  localepurge/mandelete         boolean true
      localepurge  localepurge/use-dpkg-feature  boolean false
      localepurge  localepurge/showfreedspace    boolean true
      localepurge  localepurge/verbose           boolean false
      localepurge  localepurge/remove_no         note
      localepurge  localepurge/nopurge           multiselect en, en_US, en_US.UTF-8
      localepurge  localepurge/none_selected     boolean false

  - chroot: rootfs
    shell: |
      debconf-set-selections < /tmp/localepurge.txt
      apt-get -y install localepurge
      localepurge
      apt-get -y remove localepurge
      rm -f /tmp/localepurge.txt

  - chroot: rootfs
    shell: systemctl mask systemd-tmpfiles-clean.timer

  - chroot: rootfs
    shell: systemctl disable apt-cacher-ng.service

  - chroot: rootfs
    shell: |
      sed -i 's,^GRUB_TIMEOUT=5,GRUB_TIMEOUT=1,g' /etc/default/grub
      perl -pi -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="([^"]*)"$/GRUB_CMDLINE_LINUX_DEFAULT="\\1 mitigations=off"/' \
        /etc/default/grub

  - grub: bios
    tag: rootfs
    console: serial

  - chroot: rootfs
    shell: |
      adduser --gecos '' --disabled-password ${USERNAME}
      echo "${USERNAME}:${PASSWORD}" | chpasswd
      echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USERNAME}
      mkdir -p /home/${USERNAME}/.ssh
      chmod 0700 /home/${USERNAME}/.ssh
      chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

  - chroot: rootfs
    shell: |
      install -o 1000 -g 1000 -m 0700 /dev/null /home/${USERNAME}/.ssh/authorized_keys
      echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" > /home/${USERNAME}/.ssh/authorized_keys

  - chroot: rootfs
    shell: |
      apt-get -y autoremove
      apt-get clean
      rm -rf \
        /var/lib/apt/lists/* \
        /var/lib/apt/lists/partial/* \
        /var/cache/apt/*.bin \
        /var/cache/apt/archives/*.deb \
        /var/log/installer \
        /var/lib/dhcp/*
EOF

rm -f "${TARGET_NAME}"*
sudo "${http_proxy:+http_proxy=$http_proxy}" vmdb2 "${SPECFILE}" \
     --output "${TARGET_IMG}" -v --log vmdb2.log \
     --rootfs-tarball "${TARGET_FS_TAR}"
qemu-img convert -O qcow2 "${TARGET_IMG}" "${TARGET_QCOW2}"
bash -e -x "${GIT_DIR}/vagrant/definitions/tails-builder/create_box.sh" \
     "${TARGET_QCOW2}" "${TARGET_BOX}"
rm -f "${SPECFILE}" "${TARGET_IMG}" "${TARGET_QCOW2}" "${TARGET_FS_TAR}" vmdb2.log
