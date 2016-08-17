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
DATE_STAMP="$(date +%Y%m%d)"
TARGET_NAME="tails-builder-${ARCHITECTURE}-${DISTRIBUTION}-${DATE_STAMP}"
TARGET_IMG="${TARGET_NAME}.qcow2"
TARGET_BOX="${TARGET_NAME}.box"

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
    --mirror "http://ftp.us.debian.org/debian" \
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
