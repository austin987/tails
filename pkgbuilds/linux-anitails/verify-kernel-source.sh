#!/usr/bin/env bash
# Standalone verifier for Linux 7.3.3 tarball SHA-256 and uncompressed PGP signature
set -euo pipefail

EXPECTED_XZ_SHA256="79c66dde66cd96877fcde8f7d36aec946b1f423d2b97b5a7b1751b75c764f3d1"
TARBALL_XZ="${1:-linux-7.3.3.tar.xz}"
TAR_SIGN="${2:-linux-7.3.3.tar.sign}"
KEYRING="${3:-}"

if [[ ! -f "${TARBALL_XZ}" ]]; then
    echo "ERROR: tarball not found: ${TARBALL_XZ}" >&2
    exit 1
fi

ACTUAL_SHA256="$(sha256sum "${TARBALL_XZ}" | awk '{print $1}')"
if [[ "${ACTUAL_SHA256}" != "${EXPECTED_XZ_SHA256}" ]]; then
    echo "CRITICAL: SHA-256 mismatch for ${TARBALL_XZ}!" >&2
    echo "  expected: ${EXPECTED_XZ_SHA256}" >&2
    echo "  actual:   ${ACTUAL_SHA256}" >&2
    exit 1
fi
echo "SHA-256 OK: ${ACTUAL_SHA256}"

if [[ ! -f "${TAR_SIGN}" ]]; then
    echo "ERROR: detached signature missing: ${TAR_SIGN}" >&2
    exit 1
fi

if [[ -n "${KEYRING}" ]]; then
    xz -cd "${TARBALL_XZ}" | gpgv --keyring "${KEYRING}" "${TAR_SIGN}" -
else
    xz -cd "${TARBALL_XZ}" | gpg --verify "${TAR_SIGN}" -
fi
echo "PGP signature verification PASSED for ${TARBALL_XZ}."
