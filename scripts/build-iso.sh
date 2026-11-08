#!/usr/bin/env bash
# AniTails Deterministic Archiso Build Entrypoint
# Refuses partial upgrades, testing repos, or disabled PGP verification.
# Exits 77 (BLOCKED) with actionable diagnostics if executed on a non-Arch host.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="${REPO_ROOT}/archiso"
WORK_DIR="${ANITAILS_WORK_DIR:-/var/tmp/anitails-archiso-work}"
OUT_DIR="${ANITAILS_OUT_DIR:-${REPO_ROOT}/out}"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1794096000}"

check_pacman_security() {
    local conf="${PROFILE_DIR}/pacman.conf"
    if grep -Eq '^[[:space:]]*SigLevel[[:space:]]*=.*Never' "${conf}"; then
        echo "CRITICAL SECURITY VIOLATION: SigLevel=Never detected in ${conf}!" >&2
        exit 1
    fi
    if grep -Eq '^\[(core-testing|extra-testing|testing)\]' "${conf}"; then
        echo "CRITICAL SECURITY VIOLATION: testing repository enabled in ${conf} (risks OpenSSL ABI skew)!" >&2
        exit 1
    fi
    if ! grep -Eq '^Server = https://archive\.archlinux\.org/repos/[0-9]{4}/[0-9]{2}/[0-9]{2}/\$repo/os/\$arch$' "${PROFILE_DIR}/mirrorlist.snapshot"; then
        echo "CRITICAL SECURITY VIOLATION: mirrorlist.snapshot is not pinned to a frozen Arch Linux Archive date!" >&2
        exit 1
    fi
}

check_pacman_security

if [[ "${1:-}" == "--validate-config-only" ]]; then
    echo "PASS: archiso profile pacman.conf and frozen snapshot configuration verified."
    exit 0
fi

for tool in mkarchiso pacman pacstrap mksquashfs xorriso; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "BLOCKED: missing required Arch Linux build tool '${tool}' on current host ($(uname -srm))." >&2
        echo "Next step: run './scripts/build-iso.sh' inside a clean x86_64 Arch Linux builder with archiso >= 92-1 installed." >&2
        exit 77
    fi
done

if [[ "$(id -u)" -ne 0 ]]; then
    echo "BLOCKED: mkarchiso requires root privileges inside an isolated Arch build environment." >&2
    exit 77
fi

mkdir -p "${OUT_DIR}"
cp -f "${PROFILE_DIR}/mirrorlist.snapshot" /etc/pacman.d/mirrorlist.snapshot
exec mkarchiso -v -w "${WORK_DIR}" -o "${OUT_DIR}" "${PROFILE_DIR}"
