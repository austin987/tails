#!/usr/bin/env bash
# AniTails External Release Signing Tool
#
# STRICT SECURITY POLICY:
# - Release signing keys MUST be generated and stored OUTSIDE the build environment
#   (e.g., offline air-gapped workstation or hardware OpenPGP smartcard / YubiKey / Nitrokey).
# - This script NEVER generates ephemeral or fake keys to claim an official release.
# - If no external signing key fingerprint (`ANITAILS_RELEASE_GPG_FPR`) is provided,
#   exits 77 (`BLOCKED`) truthfully.
set -euo pipefail

MANIFEST_DIR="${1:-}"
GPG_FPR="${ANITAILS_RELEASE_GPG_FPR:-}"

if [[ -z "${MANIFEST_DIR}" || ! -d "${MANIFEST_DIR}" ]]; then
    echo "Usage: ANITAILS_RELEASE_GPG_FPR=<40-HEX-FPR> $0 <manifest-dir>" >&2
    exit 2
fi

for f in SHA256SUMS B2SUMS sbom.cdx.json; do
    if [[ ! -f "${MANIFEST_DIR}/${f}" ]]; then
        echo "ERROR: Missing required release manifest ${MANIFEST_DIR}/${f}" >&2
        exit 1
    fi
done

if [[ -z "${GPG_FPR}" ]]; then
    echo "BLOCKED: ANITAILS_RELEASE_GPG_FPR is not set. Release signing requires an external offline/HSM OpenPGP key outside the build environment; refusing to generate a fake key." >&2
    exit 77
fi

if ! command -v gpg >/dev/null 2>&1; then
    echo "BLOCKED: 'gpg' binary is not installed in this environment." >&2
    exit 77
fi

for f in SHA256SUMS B2SUMS sbom.cdx.json; do
    gpg --batch --yes --armor --detach-sign --local-user "${GPG_FPR}" \
        --output "${MANIFEST_DIR}/${f}.asc" "${MANIFEST_DIR}/${f}"
done

echo "Signed SHA256SUMS, B2SUMS, and sbom.cdx.json with external key ${GPG_FPR}."
