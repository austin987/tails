#!/bin/sh
set -e
set -u

# Based on ypcs' scripts found at:
#     https://github.com/ypcs/vmdebootstrap-vagrant/

SERIAL="${1}"
COMMENT="${2:-}"
ARCHITECTURE="amd64"
DISTRIBUTION="jessie"
USERNAME="vagrant"
PASSWORD="vagrant"
SIZE="20G"
HOSTNAME="vagrant-${DISTRIBUTION}"
TARGET_NAME="tails-builder-${ARCHITECTURE}-${DISTRIBUTION}-${SERIAL}"
if [ -n "${COMMENT}" ]; then
   TARGET_NAME="${TARGET_NAME}-${COMMENT}"
fi
TARGET_IMG="${TARGET_NAME}.qcow2"
TARGET_BOX="${TARGET_NAME}.box"
LC_ALL=C

SECURITY_SERIAL="$(
    cd ../../.. && \
    auto/scripts/apt-snapshots-serials get-latest debian-security | \
        sed s/^debian-security:[^0-9]*// \
)"

DEBOOTSTRAP_GNUPG_HOMEDIR=$(mktemp -d)
gpg --homedir "${DEBOOTSTRAP_GNUPG_HOMEDIR}" \
    --import ../../../config/chroot_sources/tails.chroot.gpg
DEBOOTSTRAP_GNUPG_PUBRING="${DEBOOTSTRAP_GNUPG_HOMEDIR}/pubring.kbx"
if [ ! -e "${DEBOOTSTRAP_GNUPG_PUBRING}" ]; then
    DEBOOTSTRAP_GNUPG_PUBRING="${DEBOOTSTRAP_GNUPG_HOMEDIR}/pubring.gpg"
fi

# vmdebootstrap will fail if some of the files it wants to create
# already exists
rm -f "${TARGET_NAME}".*

sudo ${http_proxy:+http_proxy="$http_proxy"} \
     LC_ALL=${LC_ALL} \
     ARCHITECTURE=${ARCHITECTURE} \
     DISTRIBUTION=${DISTRIBUTION} \
     SECURITY_SERIAL=${SECURITY_SERIAL} \
     SERIAL=${SERIAL} \
     vmdebootstrap \
     --arch "${ARCHITECTURE}" \
     --distribution "${DISTRIBUTION}" \
     --image "${TARGET_IMG}" \
     --convert-qcow2 \
     --enable-dhcp \
     --grub \
     --hostname "${HOSTNAME}" \
     --log-level "debug" \
     --mirror "http://time-based.snapshots.deb.tails.boum.org/debian/${SERIAL}" \
     --debootstrapopts "keyring=${DEBOOTSTRAP_GNUPG_PUBRING}" \
     --owner "${SUDO_USER:-${USER}}" \
     --kernel-package "linux-image-${ARCHITECTURE}" \
     --root-password="${PASSWORD}" \
     --size "${SIZE}" \
     --sudo \
     --user "${USERNAME}/${PASSWORD}" \
     --customize "$(pwd)/customize.sh" \
     --verbose

/usr/share/doc/vagrant-libvirt/examples/create_box.sh \
    "${TARGET_IMG}" "${TARGET_BOX}"

rm -rf "${TARGET_IMG}"* "${DEBOOTSTRAP_GNUPG_HOMEDIR}"

exit 0
