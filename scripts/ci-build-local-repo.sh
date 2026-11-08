#!/usr/bin/env bash
# AniTails CI Local ALPM Repository Builder (`[anitails-local]`)
# ==============================================================================
# Builds and cryptographically signs all custom packages required by
# `archiso/pacman.conf` (`[anitails-local]`, `SigLevel = Required`) inside an
# isolated x86_64 Arch Linux builder (e.g., GitHub Actions `archlinux:base-devel`
# container or clean Arch chroot/VM).
#
# SECURITY INVARIANTS ENFORCED:
#   1. NEVER weakens `SigLevel = Required` in `archiso/pacman.conf`.
#   2. NEVER enables `[testing]`, `[core-testing]`, or `[extra-testing]`.
#   3. Generates ephemeral one-time X.509 RSA-4096 kernel module signing keys
#      (`ANITAILS_KMOD_KEY` / `ANITAILS_KMOD_CERT`) in RAM (`/dev/shm`) so
#      `linux-anitails` enrolls the public cert in `SYSTEM_TRUSTED_KEYS` and
#      `nvidia-open-anitails` / `nvidia-580xx-anitails` sign `.ko` modules for
#      `module.sig_enforce=1` + `lockdown=integrity`.
#   4. Generates an ephemeral one-time OpenPGP ALPM repository signing key in RAM,
#      locally trusts its public half in the builder host's `pacman-key` keyring,
#      signs every `.pkg.tar.zst` + `anitails-local.db.tar.gz`, and then
#      IRREVERSIBLY SHREDS (`shred -u`) BOTH private keys BEFORE `mkarchiso` runs!
#   5. Official release signing (`SHA256SUMS.asc`) remains strictly offline via
#      hardware token/HSM (`./scripts/sign-release.sh`) — zero fake release keys!
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELECTED_PROFILE="base"
SNAPSHOT_MODE="pinned"
SNAPSHOT_OVERRIDE=""
LOCAL_REPO_DIR="/var/cache/anitails-local-repo"
CACHE_ROOT="${ANITAILS_CI_CACHE_DIR:-/var/cache/anitails-ci}"
VALIDATE_ONLY=0
 export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1794096000}"

usage() {
    cat <<EOF
Usage: $0 [options]
  --profile <base|nvidia-modern|nvidia-legacy-580xx|nvidia-cuda-optional>
  --snapshot-mode <pinned|pinned-or-latest-archive>
  --snapshot-date <YYYY/MM/DD>     Optional explicit frozen Arch Linux Archive date
  --repo-dir <path>                Output ALPM local repo path (default: /var/cache/anitails-local-repo)
  --cache-dir <path>               Source & ccache directory (default: /var/cache/anitails-ci)
  --validate-only                  Validate configuration, profile, and PGP key list without root build
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            SELECTED_PROFILE="${2:-}"
            shift 2
            ;;
        --snapshot-mode)
            SNAPSHOT_MODE="${2:-}"
            shift 2
            ;;
        --snapshot-date)
            SNAPSHOT_OVERRIDE="${2:-}"
            shift 2
            ;;
        --repo-dir)
            LOCAL_REPO_DIR="${2:-}"
            shift 2
            ;;
        --cache-dir)
            CACHE_ROOT="${2:-}"
            shift 2
            ;;
        --validate-only)
            VALIDATE_ONLY=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option '$1'" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "${SELECTED_PROFILE}" in
    base|nvidia-modern|nvidia-legacy-580xx|nvidia-cuda-optional) ;;
    *)
        echo "ERROR: Unsupported profile '${SELECTED_PROFILE}'." >&2
        exit 2
        ;;
esac

case "${SNAPSHOT_MODE}" in
    pinned|pinned-or-latest-archive) ;;
    *)
        echo "ERROR: Unsupported --snapshot-mode '${SNAPSHOT_MODE}' (expected pinned or pinned-or-latest-archive)." >&2
        exit 2
        ;;
esac

if [[ -n "${SNAPSHOT_OVERRIDE}" ]] && ! [[ "${SNAPSHOT_OVERRIDE}" =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]]; then
    echo "ERROR: --snapshot-date must match YYYY/MM/DD (got '${SNAPSHOT_OVERRIDE}')." >&2
    exit 2
fi

# Upstream OpenPGP keys required across pkgbuilds/* (40-hex fingerprints -> authoritative HTTPS key URL)
declare -A UPSTREAM_PGP_KEYS=(
    ["ABAF11C65A2970B130ABE3C479BE3E4300411886"]="https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/raw/main/keys/pgp/ABAF11C65A2970B130ABE3C479BE3E4300411886.asc"
    ["647F28654894E3BD457199BE38DBBDC86092693E"]="https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/raw/main/keys/pgp/647F28654894E3BD457199BE38DBBDC86092693E.asc"
    ["E27E5D8A3403A2EF66873BBCDEA66FF797772CDC"]="https://keyserver.ubuntu.com/pks/lookup?op=get&options=mr&search=0xE27E5D8A3403A2EF66873BBCDEA66FF797772CDC"
    ["2133BC600AB133E1D826D173FE43009C4607B1FB"]="https://gitlab.archlinux.org/archlinux/packaging/packages/tor/-/raw/main/keys/pgp/2133BC600AB133E1D826D173FE43009C4607B1FB.asc"
    ["B74417EDDF22AC9F9E90F49142E86A2A11F48D36"]="https://gitlab.archlinux.org/archlinux/packaging/packages/tor/-/raw/main/keys/pgp/B74417EDDF22AC9F9E90F49142E86A2A11F48D36.asc"
    ["1C1BC007A9F607AA8152C040BEA7B180B1491921"]="https://gitlab.archlinux.org/archlinux/packaging/packages/tor/-/raw/main/keys/pgp/1C1BC007A9F607AA8152C040BEA7B180B1491921.asc"
    ["EF6E286DDA85EA2A4BA7DE684E2C6E8793298290"]="https://openpgpkey.torproject.org/.well-known/openpgpkey/torproject.org/hu/kounek7zrdx745qydx6p59t9mqjpuhdf"
)

# Determine ordered PKGBUILD list for the selected profile (conflict-free isolation!)
PKGBUILDS_TO_BUILD=(
    "anitails-udev-watchdog"
    "lyrebird-anitails"
    "tor-anitails"
    "tor-browser-anitails"
    "linux-anitails"
)
case "${SELECTED_PROFILE}" in
    nvidia-modern|nvidia-cuda-optional)
        PKGBUILDS_TO_BUILD+=("nvidia-open-anitails")
        ;;
    nvidia-legacy-580xx)
        PKGBUILDS_TO_BUILD+=("nvidia-580xx-anitails")
        ;;
    base)
        # Base profile remains 100% free of proprietary NVIDIA / CUDA packages
        ;;
esac

# Run static security & lockstep checks first
"${REPO_ROOT}/scripts/build-iso.sh" --profile "${SELECTED_PROFILE}" --validate-config-only

for pkg_dir in "${PKGBUILDS_TO_BUILD[@]}"; do
    if [[ ! -f "${REPO_ROOT}/pkgbuilds/${pkg_dir}/PKGBUILD" ]]; then
        echo "ERROR: Missing PKGBUILD for '${pkg_dir}' at ${REPO_ROOT}/pkgbuilds/${pkg_dir}/PKGBUILD" >&2
        exit 1
    fi
done

if [[ "${VALIDATE_ONLY}" -eq 1 ]]; then
    echo "PASS: ci-build-local-repo validated profile='${SELECTED_PROFILE}', packages=(${PKGBUILDS_TO_BUILD[*]}), upstream_keys=${#UPSTREAM_PGP_KEYS[@]}."
    exit 0
fi

if [[ "$(id -u)" -ne 0 ]]; then
    echo "BLOCKED: ci-build-local-repo.sh requires root inside an isolated Arch Linux builder container/VM." >&2
    exit 77
fi

for host_cmd in pacman pacman-key curl python3; do
    if ! command -v "${host_cmd}" >/dev/null 2>&1; then
        echo "BLOCKED: Missing '${host_cmd}' — run inside an Arch Linux x86_64 container (archlinux:base-devel)." >&2
        exit 77
    fi
done

EPHEMERAL_KEY_DIR="/dev/shm/anitails-ephemeral-keys-$$"
cleanup_ephemeral_keys() {
    if [[ -d "${EPHEMERAL_KEY_DIR}" ]]; then
        find "${EPHEMERAL_KEY_DIR}" -type f -exec shred -u {} + 2>/dev/null || true
        rm -rf "${EPHEMERAL_KEY_DIR}"
    fi
}
report_ci_error() {
    local exit_code=$?
    echo "::error title=ci-build-local-repo failed::Exit ${exit_code} at ${BASH_SOURCE[0]}:${1} while running: ${BASH_COMMAND}"
}
trap 'report_ci_error ${LINENO}' ERR
trap cleanup_ephemeral_keys EXIT

resolve_snapshot_mirrorlist() {
    local mirror_file="${REPO_ROOT}/archiso/mirrorlist.snapshot"
    if [[ -n "${SNAPSHOT_OVERRIDE}" ]]; then
        echo "Server = https://archive.archlinux.org/repos/${SNAPSHOT_OVERRIDE}/\$repo/os/\$arch" > "${mirror_file}"
    fi

    local current_url
    current_url="$(awk -F' = ' '/^Server = /{print $2; exit}' "${mirror_file}")"
    local probe_url="${current_url//\$repo/core}"
    probe_url="${probe_url//\$arch/x86_64}/core.db"

    if curl -fsSLI --retry 3 --max-time 20 "${probe_url}" >/dev/null 2>&1; then
        echo "[snapshot] Verified pinned Arch Linux Archive snapshot: ${current_url}"
        return 0
    fi

    if [[ "${SNAPSHOT_MODE}" != "pinned-or-latest-archive" ]]; then
        echo "ERROR: Pinned snapshot '${probe_url}' is unreachable and --snapshot-mode=pinned." >&2
        exit 1
    fi

    echo "::warning::Pinned snapshot ${probe_url} returned non-200; resolving latest atomic YYYY/MM/DD snapshot on archive.archlinux.org..."
    local resolved_date
    resolved_date="$(python3 - <<'PY'
import re, sys, urllib.request

def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "AniTails-CI/1.0"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read().decode("utf-8", "replace")

years = sorted(set(re.findall(r'href="([0-9]{4})/"', fetch("https://archive.archlinux.org/repos/"))), reverse=True)
for y in years[:2]:
    months = sorted(set(re.findall(r'href="([0-9]{2})/"', fetch(f"https://archive.archlinux.org/repos/{y}/"))), reverse=True)
    for m in months[:3]:
        days = sorted(set(re.findall(r'href="([0-9]{2})/"', fetch(f"https://archive.archlinux.org/repos/{y}/{m}/"))), reverse=True)
        for d in days:
            probe = f"https://archive.archlinux.org/repos/{y}/{m}/{d}/core/os/x86_64/core.db"
            try:
                req = urllib.request.Request(probe, method="HEAD", headers={"User-Agent": "AniTails-CI/1.0"})
                with urllib.request.urlopen(req, timeout=15) as resp:
                    if resp.status == 200:
                        print(f"{y}/{m}/{d}")
                        sys.exit(0)
            except Exception:
                continue
sys.exit(1)
PY
)"
    if [[ ! "${resolved_date}" =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]]; then
        echo "ERROR: Failed to resolve an atomic YYYY/MM/DD snapshot from archive.archlinux.org!" >&2
        exit 1
    fi
    echo "Server = https://archive.archlinux.org/repos/${resolved_date}/\$repo/os/\$arch" > "${mirror_file}"
    echo "[snapshot] Pinned atomic Arch Linux Archive fallback snapshot: ${resolved_date}"
}

resolve_snapshot_mirrorlist
cp -f "${REPO_ROOT}/archiso/mirrorlist.snapshot" /etc/pacman.d/mirrorlist.snapshot
cp -f "${REPO_ROOT}/archiso/mirrorlist.snapshot" /etc/pacman.d/mirrorlist

echo "[1/6] Initializing builder pacman keyring & installing Archiso / kernel build dependencies..."
pacman-key --init
pacman-key --populate archlinux
pacman -Syu --noconfirm --needed \
    archiso base-devel bc binutils ccache cpio curl dosfstools edk2-ovmf gettext git \
    gnupg kmod libelf libisoburn mtools nftables openssl pahole perl python \
    python-yaml rsync squashfs-tools syslinux tar xz zstd

echo "[2/6] Configuring unprivileged 'builder' account & parallel makepkg environment..."
if ! id -u builder >/dev/null 2>&1; then
    useradd -m -s /bin/bash builder
fi
echo "builder ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/99-anitails-ci-builder
chmod 0440 /etc/sudoers.d/99-anitails-ci-builder

mkdir -p "${CACHE_ROOT}/sources" "${CACHE_ROOT}/ccache" "${CACHE_ROOT}/pkgs" "${LOCAL_REPO_DIR}"
chown -R builder:builder "${CACHE_ROOT}"

cat >> /etc/makepkg.conf <<EOF

# --- AniTails Deterministic Parallel CI Overrides ---
MAKEFLAGS="-j$(nproc)"
SRCDEST="${CACHE_ROOT}/sources"
CCACHE_DIR="${CACHE_ROOT}/ccache"
COMPRESSZST=(zstd -c -T0 --auto-threads=logical -19 -)
EOF

echo "[3/6] Generating ephemeral RAM-backed X.509 kmod signing key & ALPM local repo GPG key..."
install -d -m 0700 -o builder -g builder "${EPHEMERAL_KEY_DIR}" "${EPHEMERAL_KEY_DIR}/gnupg"

# Key A: One-time RSA-4096 X.509 kernel module signing keypair (enrolled in linux-anitails SYSTEM_TRUSTED_KEYS)
openssl req -new -nodes -utf8 -sha512 -days 36500 -batch -x509 \
    -newkey rsa:4096 \
    -keyout "${EPHEMERAL_KEY_DIR}/kmod.key" \
    -out "${EPHEMERAL_KEY_DIR}/kmod.pem" \
    -subj "/CN=AniTails Ephemeral CI Kernel Module Signing Key/"
chown builder:builder "${EPHEMERAL_KEY_DIR}/kmod.key" "${EPHEMERAL_KEY_DIR}/kmod.pem"
chmod 0600 "${EPHEMERAL_KEY_DIR}/kmod.key"
chmod 0644 "${EPHEMERAL_KEY_DIR}/kmod.pem"

# Key B: One-time OpenPGP key for [anitails-local] so `SigLevel = Required` is strictly honored
su - builder -c "GNUPGHOME='${EPHEMERAL_KEY_DIR}/gnupg' gpg --batch --passphrase '' --quick-generate-key 'AniTails Ephemeral Local Repo <ci-ephemeral@anitails.invalid>' rsa3072 default 1d"
REPO_GPG_FPR="$(su - builder -c "GNUPGHOME='${EPHEMERAL_KEY_DIR}/gnupg' gpg --list-secret-keys --with-colons" | awk -F: '/^fpr:/{print $10; exit}')"
su - builder -c "GNUPGHOME='${EPHEMERAL_KEY_DIR}/gnupg' gpg --armor --export '${REPO_GPG_FPR}'" > "${EPHEMERAL_KEY_DIR}/repo-signing.pub.asc"

pacman-key --add "${EPHEMERAL_KEY_DIR}/repo-signing.pub.asc"
pacman-key --lsign-key "${REPO_GPG_FPR}"

echo "[4/6] Importing & fingerprint-verifying upstream OpenPGP release keys for builder..."
su - builder -c "mkdir -p ~/.gnupg && chmod 0700 ~/.gnupg"
KEY_TMP_DIR="$(mktemp -d)"
chmod 0755 "${KEY_TMP_DIR}"
for fpr in "${!UPSTREAM_PGP_KEYS[@]}"; do
    key_url="${UPSTREAM_PGP_KEYS[${fpr}]}"
    echo "  -> Importing ${fpr} from ${key_url}..."
    if curl -fsSL --retry 4 --max-time 30 "${key_url}" -o "${KEY_TMP_DIR}/${fpr}.key"; then
        chmod 0644 "${KEY_TMP_DIR}/${fpr}.key"
        su - builder -c "gpg --batch --import '${KEY_TMP_DIR}/${fpr}.key'" || true
    fi
    if ! su - builder -c "gpg --list-keys --with-colons '${fpr}'" >/dev/null 2>&1; then
        if curl -fsSL --retry 3 --max-time 25 "https://keys.openpgp.org/vks/v1/by-fingerprint/${fpr}" -o "${KEY_TMP_DIR}/${fpr}.vks"; then
            chmod 0644 "${KEY_TMP_DIR}/${fpr}.vks"
            su - builder -c "gpg --batch --import-options restore --import '${KEY_TMP_DIR}/${fpr}.vks'" || true
        fi
    fi
    if ! su - builder -c "gpg --list-keys --with-colons '${fpr}'" >/dev/null 2>&1; then
        for ks in hkps://keyserver.ubuntu.com hkps://pgp.mit.edu; do
            if su - builder -c "gpg --batch --keyserver '${ks}' --recv-keys '${fpr}'" >/dev/null 2>&1; then
                break
            fi
        done
    fi
    if ! su - builder -c "gpg --list-keys --with-colons '${fpr}'" | grep -Fq ":${fpr}:"; then
        echo "::error title=PGP Import Failure::Failed to import/verify exact fingerprint ${fpr} (${key_url})"
        rm -rf "${KEY_TMP_DIR}"
        exit 1
    fi
done
rm -rf "${KEY_TMP_DIR}"

echo "[5/6] Building custom [anitails-local] packages for profile '${SELECTED_PROFILE}': ${PKGBUILDS_TO_BUILD[*]}"
BUILD_WORK="/var/tmp/anitails-pkgbuild-work"
rm -rf "${BUILD_WORK}"
install -d -m 0755 -o builder -g builder "${BUILD_WORK}"

for pkg_dir in "${PKGBUILDS_TO_BUILD[@]}"; do
    echo "=== Building ${pkg_dir} ==="
    cp -a "${REPO_ROOT}/pkgbuilds/${pkg_dir}" "${BUILD_WORK}/${pkg_dir}"
    chown -R builder:builder "${BUILD_WORK}/${pkg_dir}"

    su - builder -c "
        set -euo pipefail
        export SOURCE_DATE_EPOCH='${SOURCE_DATE_EPOCH}'
        export ANITAILS_KMOD_KEY='${EPHEMERAL_KEY_DIR}/kmod.key'
        export ANITAILS_KMOD_CERT='${EPHEMERAL_KEY_DIR}/kmod.pem'
        export PATH='/usr/lib/ccache/bin:'\"\${PATH}\"
        cd '${BUILD_WORK}/${pkg_dir}'
        makepkg -s --noconfirm --needed --cleanbuild --nocheck
    "

    cp -f "${BUILD_WORK}/${pkg_dir}"/*.pkg.tar.zst "${LOCAL_REPO_DIR}/"

    # If building an NVIDIA profile, install linux-anitails + linux-anitails-headers onto the
    # ephemeral builder container so nvidia-open-anitails / nvidia-580xx-anitails can compile
    # and sign out-of-tree modules against /usr/lib/modules/7.3.3-anitails1/build!
    if [[ "${pkg_dir}" == "linux-anitails" && "${SELECTED_PROFILE}" != "base" ]]; then
        pacman -U --noconfirm "${BUILD_WORK}/linux-anitails"/linux-anitails-*.pkg.tar.zst
    fi
done

echo "[6/6] Signing [anitails-local] packages & shredding ephemeral private keys BEFORE mkarchiso..."
chown -R builder:builder "${LOCAL_REPO_DIR}"
su - builder -c "
    set -euo pipefail
    export GNUPGHOME='${EPHEMERAL_KEY_DIR}/gnupg'
    cd '${LOCAL_REPO_DIR}'
    rm -f *.sig anitails-local.db* anitails-local.files*
    for pkg in *.pkg.tar.zst; do
        gpg --batch --yes --default-key '${REPO_GPG_FPR}' --detach-sign --no-armor \"\${pkg}\"
    done
    repo-add --include-sigs --verify --sign --key '${REPO_GPG_FPR}' anitails-local.db.tar.gz *.pkg.tar.zst
"
chown -R root:root "${LOCAL_REPO_DIR}"

# Irreversibly destroy ephemeral module & GPG secret keys BEFORE mkarchiso starts!
cleanup_ephemeral_keys
if [[ -d "${EPHEMERAL_KEY_DIR}" ]]; then
    echo "CRITICAL SECURITY ERROR: Ephemeral key directory was not destroyed!" >&2
    exit 1
fi

echo "PASS: Signed [anitails-local] repository ready at ${LOCAL_REPO_DIR} (all ephemeral private keys shredded)."
