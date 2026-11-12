#!/usr/bin/env bash
# AniTails Post-Build ISO Integrity, Bootloader & SBOM/Checksum Verifier
# ==============================================================================
# Verifies after `mkarchiso` completes that:
#   1. At least one `.iso` artifact exists in `--out-dir` and meets minimum sanity size.
#   2. Hybrid BIOS (`boot/syslinux`) + UEFI (`EFI/BOOT/BOOTX64.EFI`, `loader/loader.conf`)
#      + kernel (`vmlinuz-linux-anitails`), initramfs (`initramfs-linux-anitails.img`),
#      and compressed SquashFS root (`arch/x86_64/airootfs.sfs`) exist inside the ISO 9660 tree.
#   3. Zero private signing keys (`*.key`, `signing_key.pem`, `secring.gpg`) leaked into the ISO.
#   4. Generates & cryptographically self-verifies `sbom.cdx.json`, `SHA256SUMS`, and `B2SUMS`.
set -euo pipefail
trap 'echo "::error title=ci-verify-iso.sh failed::Exit $? at ${BASH_SOURCE[0]}:${LINENO} running: ${BASH_COMMAND}"' ERR

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${REPO_ROOT}/out"
MIN_ISO_BYTES=$((200 * 1024 * 1024))

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out-dir)
            OUT_DIR="${2:-}"
            shift 2
            ;;
        --min-bytes)
            MIN_ISO_BYTES="${2:-}"
            shift 2
            ;;
        *)
            echo "ERROR: Unknown argument '$1'. Usage: $0 [--out-dir <dir>] [--min-bytes <bytes>]" >&2
            exit 2
            ;;
    esac
done

shopt -s nullglob
ISO_FILES=("${OUT_DIR}"/*.iso)
shopt -u nullglob

if [[ "${#ISO_FILES[@]}" -eq 0 ]]; then
    echo "FAIL: No .iso files found in ${OUT_DIR}!" >&2
    exit 1
fi

if ! command -v xorriso >/dev/null 2>&1; then
    echo "BLOCKED: 'xorriso' (libisoburn) is required to inspect ISO 9660 tree." >&2
    exit 77
fi

for iso in "${ISO_FILES[@]}"; do
    size_bytes="$(stat -c '%s' "${iso}")"
    if (( size_bytes < MIN_ISO_BYTES )); then
        echo "FAIL: ISO ${iso} is unexpectedly small (${size_bytes} bytes < ${MIN_ISO_BYTES} bytes)!" >&2
        exit 1
    fi

    echo "[verify-iso] Auditing ISO 9660 structure & El Torito boot catalog: $(basename "${iso}") (${size_bytes} bytes)"
    xorriso_err="$(mktemp)"
    if ! env -u SOURCE_DATE_EPOCH xorriso -indev "${iso}" -report_el_torito plain >/dev/null 2>"${xorriso_err}"; then
        cat "${xorriso_err}" >&2 || true
        rm -f "${xorriso_err}"
        echo "FAIL: xorriso failed to verify El Torito boot catalog of ${iso}!" >&2
        exit 1
    fi
    if command -v bsdtar >/dev/null 2>&1; then
        iso_listing="$(bsdtar -tf "${iso}" | sed 's|^/*|/|; s|/$||')"
    else
        iso_listing="$(env -u SOURCE_DATE_EPOCH xorriso -indev "${iso}" -find / -exec echo -- 2>"${xorriso_err}")"
    fi
    rm -f "${xorriso_err}"
    if [[ -z "${iso_listing}" ]]; then
        echo "FAIL: Empty ISO 9660 file listing for ${iso}!" >&2
        exit 1
    fi

    for required_path in \
        "/EFI/BOOT/BOOTX64.EFI" \
        "/loader/loader.conf" \
        "/boot/syslinux" \
        "/arch/boot/x86_64/vmlinuz-linux-anitails" \
        "/arch/boot/x86_64/initramfs-linux-anitails.img" \
        "/arch/x86_64/airootfs.sfs"; do
        if ! grep -Fixq "${required_path}" <<<"${iso_listing}"; then
            echo "FAIL: Missing required boot/live file '${required_path}' inside ${iso}!" >&2
            exit 1
        fi
    done

    if grep -Eiq '\.(key|p12|pfx)$|signing_key\.pem|secring\.gpg' <<<"${iso_listing}"; then
        echo "CRITICAL SECURITY FAIL: Private key filename pattern detected in ISO 9660 tree of ${iso}!" >&2
        exit 1
    fi

    if command -v bsdtar >/dev/null 2>&1 && command -v unsquashfs >/dev/null 2>&1; then
        sfs_tmp="$(mktemp -d)"
        bsdtar -xf "${iso}" -C "${sfs_tmp}" arch/x86_64/airootfs.sfs
        sfs_list="$(unsquashfs -l "${sfs_tmp}/arch/x86_64/airootfs.sfs")"
        rm -rf "${sfs_tmp}"
        for req_rootfs_entry in \
            "squashfs-root/etc/anitails-finalized" \
            "squashfs-root/etc/localtime" \
            "squashfs-root/etc/locale.conf" \
            "squashfs-root/etc/systemd/system/display-manager.service" \
            "squashfs-root/etc/systemd/system/systemd-firstboot.service" \
            "squashfs-root/etc/systemd/system/sysinit.target.wants/anitails-virtio-boot-status.service" \
            "squashfs-root/etc/modprobe.d/90-all-net-blacklist.conf"; do
            if ! grep -Fxq "${req_rootfs_entry}" <<<"${sfs_list}"; then
                echo "FAIL: Missing post-pacstrap entry '${req_rootfs_entry}' inside airootfs.sfs of ${iso}!" >&2
                exit 1
            fi
        done
        echo "[verify-iso] Verified post-pacstrap finalization & GDM/firewall/watchdog symlinks inside airootfs.sfs."
    fi
done

MANIFEST_STAGE="$(mktemp -d)"
trap 'rm -rf "${MANIFEST_STAGE}"' EXIT

# Remove any previous top-level manifests before hashing so only built ISO artifacts are hashed
rm -f "${OUT_DIR}/SHA256SUMS" "${OUT_DIR}/B2SUMS" "${OUT_DIR}/sbom.cdx.json"
rm -rf "${OUT_DIR}/manifests"

python3 "${REPO_ROOT}/scripts/generate-sbom-and-checksums.py" generate \
    --target "${OUT_DIR}" \
    --out-dir "${MANIFEST_STAGE}"

python3 "${REPO_ROOT}/scripts/generate-sbom-and-checksums.py" verify \
    --manifest-dir "${MANIFEST_STAGE}" \
    --base-dir "${OUT_DIR}"

cp -f "${MANIFEST_STAGE}/SHA256SUMS" "${OUT_DIR}/SHA256SUMS"
cp -f "${MANIFEST_STAGE}/B2SUMS" "${OUT_DIR}/B2SUMS"
cp -f "${MANIFEST_STAGE}/sbom.cdx.json" "${OUT_DIR}/sbom.cdx.json"

echo "PASS: Verified ${#ISO_FILES[@]} ISO image(s) + CycloneDX SBOM + SHA256SUMS + B2SUMS in ${OUT_DIR}."
