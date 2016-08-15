#!/bin/sh
set -e
set -u

# Based on ypcs' scripts found at:
#     https://github.com/ypcs/vmdebootstrap-vagrant/

CURDIR="$(realpath $(dirname $0))"
ROOT="$1"
[ -z "${ROOT}" ] && echo "E: Missing argument!" && exit 1

cp "${CURDIR}/postinstall.sh" "${ROOT}/postinstall.sh"
chmod +x "${ROOT}/postinstall.sh"
chroot "${ROOT}" "/postinstall.sh"
rm -f "${ROOT}/postinstall.sh"
