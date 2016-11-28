#!/bin/sh
set -e
set -u

# Based on ypcs' scripts found at:
#     https://github.com/ypcs/vmdebootstrap-vagrant/

ARCHITECTURE="amd64"
DISTRIBUTION="jessie"
USERNAME="vagrant"
PASSWORD="vagrant"
SIZE="20G"
HOSTNAME="vagrant-${DISTRIBUTION}"
TARGET_NAME=$(grep -Po "tails-builder-${ARCHITECTURE}-${DISTRIBUTION}-\d{10}" ../../Vagrantfile)
SERIAL=$(echo "${TARGET_NAME}" | grep -Po '\d{10}')
TARGET_IMG="${TARGET_NAME}.qcow2"
TARGET_BOX="${TARGET_NAME}.box"

DEBOOTSTRAP_GNUPG_HOMEDIR=$(mktemp -d)
gpg --homedir "${DEBOOTSTRAP_GNUPG_HOMEDIR}" \
    --import ../../../config/chroot_sources/tails.chroot.gpg

sudo vmdebootstrap \
    --arch "${ARCHITECTURE}" \
    --distribution "${DISTRIBUTION}" \
    --image "${TARGET_IMG}" \
    --convert-qcow2 \
    --enable-dhcp \
    --grub \
    --hostname "${HOSTNAME}" \
    --log-level "debug" \
    --mbr \
    --mirror "http://time-based.snapshots.deb.tails.boum.org/debian/${SERIAL}" \
    --debootstrapopts "keyring=${DEBOOTSTRAP_GNUPG_HOMEDIR}/pubring.gpg" \
    --owner "${SUDO_USER:-${USER}}" \
    --kernel-package "linux-image-${ARCHITECTURE}" \
    --package "ca-certificates" \
    --package "wget" \
    --root-password="${PASSWORD}" \
    --size "${SIZE}" \
    --sudo \
    --user "${USERNAME}/${PASSWORD}" \
    --customize "$(pwd)/customize.sh" \
    --verbose

/usr/share/vagrant-plugins/vagrant-libvirt/tools/create_box.sh \
    "${TARGET_IMG}" "${TARGET_BOX}"

rm -f "${TARGET_IMG}"*

exit 0
