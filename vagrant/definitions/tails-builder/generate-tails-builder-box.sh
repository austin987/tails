#!/bin/sh
set -e
set -u
set -x

# Based on ypcs' scripts found at:
#     https://github.com/ypcs/vmdebootstrap-vagrant/

GIT_DIR="$(git rev-parse --show-toplevel)"
cd "${GIT_DIR}/vagrant/definitions/tails-builder"

build_setting() {
    ruby -I "${GIT_DIR}/vagrant/lib" \
         -e "require 'tails_build_settings.rb'; print ${1}"
}

get_serial() {
    "${GIT_DIR}/auto/scripts/apt-snapshots-serials" \
        cat --print-serials-only "${1}"
}

TARGET_NAME="$(build_setting box_name)"
TARGET_IMG="${TARGET_NAME}.qcow2"
TARGET_BOX="${TARGET_NAME}.box"
ARCHITECTURE="$(build_setting ARCHITECTURE)"
DISTRIBUTION="$(build_setting DISTRIBUTION)"
HOSTNAME="vagrant-${DISTRIBUTION}"
USERNAME="vagrant"
PASSWORD="vagrant"
SIZE="20G"
LC_ALL=C

DEBIAN_SERIAL="$(get_serial debian)"
DEBIAN_SECURITY_SERIAL="$(get_serial debian-security)"
TAILS_SERIAL="$(get_serial tails)"

DEBOOTSTRAP_GNUPG_HOMEDIR=$(mktemp -d)
gpg --homedir "${DEBOOTSTRAP_GNUPG_HOMEDIR}" \
    --no-tty \
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
     DEBIAN_SERIAL=${DEBIAN_SERIAL} \
     DEBIAN_SECURITY_SERIAL=${DEBIAN_SECURITY_SERIAL} \
     TAILS_SERIAL=${TAILS_SERIAL} \
     vmdebootstrap \
     --arch "${ARCHITECTURE}" \
     --distribution "${DISTRIBUTION}" \
     --image "${TARGET_IMG}" \
     --convert-qcow2 \
     --enable-dhcp \
     --grub \
     --hostname "${HOSTNAME}" \
     --log-level "debug" \
     --mirror "http://time-based.snapshots.deb.tails.boum.org/debian/${DEBIAN_SERIAL}" \
     --debootstrapopts "keyring=${DEBOOTSTRAP_GNUPG_PUBRING}" \
     --owner "${SUDO_USER:-${USER}}" \
     --kernel-package "linux-image-${ARCHITECTURE}" \
     --root-password="${PASSWORD}" \
     --size "${SIZE}" \
     --sudo \
     --user "${USERNAME}/${PASSWORD}" \
     --customize "$(pwd)/customize.sh" \
     --verbose

bash -e -x /usr/share/doc/vagrant-libvirt/examples/create_box.sh \
    "${TARGET_IMG}" "${TARGET_BOX}"

rm -rf "${TARGET_IMG}"* "${DEBOOTSTRAP_GNUPG_HOMEDIR}"

exit 0
