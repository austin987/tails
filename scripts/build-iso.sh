#!/usr/bin/env bash
# AniTails Deterministic Archiso Multi-Profile Build Entrypoint
# Supports conflict-free profile isolation:
#   --profile base                 (default: 100% open-source nouveau + Mesa NVK + simpledrm)
#   --profile nvidia-modern        (Turing/Ampere/Ada/Hopper/Blackwell pre-signed nvidia-open-anitails)
#   --profile nvidia-legacy-580xx  (Maxwell/Pascal/Volta isolated R580 580.196.07 profile)
#   --profile nvidia-cuda-optional (Opt-in Turing+ SM >= 7.5 compute profile with CUDA 13.4)
#
# Refuses partial upgrades, testing repos, runtime DKMS in live session, or disabled PGP verification.
# Exits 77 (BLOCKED) with actionable diagnostics if executed on a non-Arch host.
set -euo pipefail
trap 'echo "::error title=build-iso.sh failed::Exit $? at ${BASH_SOURCE[0]}:${LINENO} running: ${BASH_COMMAND}"' ERR

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_PROFILE_DIR="${REPO_ROOT}/archiso"
PROFILES_META_DIR="${REPO_ROOT}/archiso-profiles"
SELECTED_PROFILE="base"
VALIDATE_ONLY=0
WORK_DIR="${ANITAILS_WORK_DIR:-/var/tmp/anitails-archiso-work}"
OUT_DIR="${ANITAILS_OUT_DIR:-${REPO_ROOT}/out}"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1794096000}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            SELECTED_PROFILE="${2:-}"
            shift 2
            ;;
        --validate-config-only)
            VALIDATE_ONLY=1
            shift
            ;;
        *)
            echo "ERROR: Unknown argument '$1'. Usage: $0 [--profile base|nvidia-modern|nvidia-legacy-580xx|nvidia-cuda-optional] [--validate-config-only]" >&2
            exit 2
            ;;
    esac
done

PROFILE_JSON="${PROFILES_META_DIR}/${SELECTED_PROFILE}/profile.json"
if [[ ! -f "${PROFILE_JSON}" ]]; then
    echo "ERROR: Unknown AniTails build profile '${SELECTED_PROFILE}' (missing ${PROFILE_JSON})." >&2
    exit 2
fi

check_pacman_security() {
    local conf="${BASE_PROFILE_DIR}/pacman.conf"
    if grep -Eq '^[[:space:]]*SigLevel[[:space:]]*=.*Never' "${conf}"; then
        echo "CRITICAL SECURITY VIOLATION: SigLevel=Never detected in ${conf}!" >&2
        exit 1
    fi
    if grep -Eq '^\[(core-testing|extra-testing|testing)\]' "${conf}"; then
        echo "CRITICAL SECURITY VIOLATION: testing repository enabled in ${conf} (risks OpenSSL ABI skew)!" >&2
        exit 1
    fi
    if ! grep -Eq '^Server = https://archive\.archlinux\.org/repos/[0-9]{4}/[0-9]{2}/[0-9]{2}/\$repo/os/\$arch$' "${BASE_PROFILE_DIR}/mirrorlist.snapshot"; then
        echo "CRITICAL SECURITY VIOLATION: mirrorlist.snapshot is not pinned to a frozen Arch Linux Archive date!" >&2
        exit 1
    fi
}

check_pacman_security
python3 "${REPO_ROOT}/scripts/verify-nvidia-lockstep.py" --profile "${SELECTED_PROFILE}"

if [[ "${VALIDATE_ONLY}" -eq 1 ]]; then
    echo "PASS: archiso profile '${SELECTED_PROFILE}', pacman.conf, frozen snapshot, and NVIDIA lockstep verified."
    exit 0
fi

for tool in mkarchiso pacman pacstrap mksquashfs xorriso; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "BLOCKED: missing required Arch Linux build tool '${tool}' on current host ($(uname -srm))." >&2
        echo "Next step: run './scripts/build-iso.sh --profile ${SELECTED_PROFILE}' inside a clean x86_64 Arch Linux builder with archiso >= 92-1 installed." >&2
        exit 77
    fi
done

if [[ "$(id -u)" -ne 0 ]]; then
    echo "BLOCKED: mkarchiso requires root privileges inside an isolated Arch build environment." >&2
    exit 77
fi

# Stage an isolated profile copy if extra profile packages are selected so nvidia-modern
# and nvidia-legacy-580xx never collide inside the base repository tree.
STAGE_DIR="${WORK_DIR}/profile-${SELECTED_PROFILE}"
rm -rf "${STAGE_DIR}"
mkdir -p "${WORK_DIR}" "${OUT_DIR}"
cp -a "${BASE_PROFILE_DIR}" "${STAGE_DIR}"

python3 - "${PROFILE_JSON}" "${STAGE_DIR}/packages.x86_64" "${STAGE_DIR}/profiledef.sh" "${SELECTED_PROFILE}" <<'PY'
import json, pathlib, re, sys
meta = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
pkg_file = pathlib.Path(sys.argv[2])
prof_sh = pathlib.Path(sys.argv[3])
prof_name = sys.argv[4]

extra = meta.get("extra_packages", [])
if extra:
    txt = pkg_file.read_text(encoding="utf-8")
    txt += "\n# --- Profile-Specific Packages (" + prof_name + ") ---\n" + "\n".join(extra) + "\n"
    pkg_file.write_text(txt, encoding="utf-8")

if prof_name != "base":
    sh_txt = prof_sh.read_text(encoding="utf-8")
    sh_txt = re.sub(r'^iso_name="anitails"', f'iso_name="anitails-{prof_name}"', sh_txt, flags=re.M)
    prof_sh.write_text(sh_txt, encoding="utf-8")
PY

cp -f "${STAGE_DIR}/mirrorlist.snapshot" /etc/pacman.d/mirrorlist.snapshot
exec mkarchiso -v -w "${WORK_DIR}/mkarchiso-${SELECTED_PROFILE}" -o "${OUT_DIR}" "${STAGE_DIR}"
