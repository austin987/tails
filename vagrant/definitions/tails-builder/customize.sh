#!/bin/sh
set -e
set -u

# Based on ypcs' scripts found at:
#     https://github.com/ypcs/vmdebootstrap-vagrant/

CURDIR="$(realpath $(dirname $0))"
ROOT="$1"
[ -z "${ROOT}" ] && echo "E: Missing argument!" && exit 1

cp "${CURDIR}/postinstall.sh" "${ROOT}/postinstall.sh"
cat "${ROOT}/etc/apt/sources.list" |\
	sed -e 's/debian/debian-security/' |\
	sed -e 's/jessie/jessie\/updates/' \
	> "${ROOT}/etc/apt/sources.list.d/jessie-updates.list"
cp "${CURDIR}/../../../config/chroot_sources/tails.binary.gpg" "${ROOT}/tmp/"
chmod +x "${ROOT}/postinstall.sh"
chroot "${ROOT}" "/postinstall.sh"
rm -f "${ROOT}/postinstall.sh"
