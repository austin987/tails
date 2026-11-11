#!/usr/bin/env bash
# AniTails End-to-End Live OS Boot Verifier (QEMU BIOS + UEFI OVMF)
# ==============================================================================
# Boots the unmodified built `.iso` image in TWO distinct firmware/graphics modes:
#   1. Legacy BIOS (`syslinux` + `virtio-vga` KMS)
#   2. Modern UEFI (`edk2-ovmf` -> `BOOTX64.EFI` `systemd-boot` + `stdvga`/`bochs-drm` KMS)
#
# Asserts that each mode boots all the way into the live operating system:
#   - Kernel `7.3.3-anitails1` unpacks zstd initramfs & mounts SquashFS + tmpfs overlayfs
#   - `nftables.service` loads `table inet anitails_filter`
#   - `anitails-create-netns.service` brings up `tbb` isolated namespace
#   - `gdm.service` starts Wayland and auto-logs in user `amnesia` (`gnome-session`/`gnome-shell`)
#   - System stays alive post-login (no false-positive media-removal shutdown)
set -euo pipefail

OUT_DIR="out"
TIMEOUT_SECS=210

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out-dir)
            OUT_DIR="${2:-}"
            shift 2
            ;;
        --timeout)
            TIMEOUT_SECS="${2:-}"
            shift 2
            ;;
        *)
            echo "ERROR: Unknown argument '$1'. Usage: $0 [--out-dir <dir>] [--timeout <sec>]" >&2
            exit 2
            ;;
    esac
done

shopt -s nullglob
ISO_FILES=("${OUT_DIR}"/*.iso)
shopt -u nullglob

if [[ "${#ISO_FILES[@]}" -eq 0 ]]; then
    echo "::error title=Boot Test Error::No .iso file found in ${OUT_DIR}"
    exit 1
fi
ISO_FILE="${ISO_FILES[0]}"

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    echo "BLOCKED: qemu-system-x86_64 is not installed on this host." >&2
    exit 77
fi

OVMF_CODE=""
OVMF_VARS=""
for pair in \
    "/usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd" \
    "/usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd" \
    "/usr/share/edk2/x64/OVMF_CODE.4m.fd:/usr/share/edk2/x64/OVMF_VARS.4m.fd" \
    "/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd:/usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd"; do
    c="${pair%%:*}"
    v="${pair##*:}"
    if [[ -f "${c}" && -f "${v}" ]]; then
        OVMF_CODE="${c}"
        OVMF_VARS="${v}"
        break
    fi
done

if [[ -z "${OVMF_CODE}" ]]; then
    echo "BLOCKED: OVMF UEFI firmware files not found on host." >&2
    exit 77
fi

ACCEL_ARGS=(-accel tcg -cpu max)
if [[ -c /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
    ACCEL_ARGS=(-enable-kvm -cpu host)
    echo "[boot-test] Hardware KVM acceleration enabled (/dev/kvm)."
else
    echo "[boot-test] /dev/kvm unavailable; falling back to TCG software emulation."
    TIMEOUT_SECS=$((TIMEOUT_SECS + 180))
fi

WORK_TMP="$(mktemp -d)"
cleanup() {
    if [[ -n "${QEMU_PID:-}" ]] && kill -0 "${QEMU_PID}" 2>/dev/null; then
        kill -9 "${QEMU_PID}" 2>/dev/null || true
    fi
    rm -rf "${WORK_TMP}"
}
trap cleanup EXIT

run_boot_mode() {
    local mode="$1"
    local status_file="${WORK_TMP}/status-${mode}.log"
    local serial_file="${WORK_TMP}/serial-${mode}.log"
    local qemu_err="${WORK_TMP}/qemu-${mode}.err"
    : > "${status_file}"
    : > "${serial_file}"

    local -a mode_args=()
    if [[ "${mode}" == "bios" ]]; then
        mode_args=(-vga none -device virtio-vga)
    elif [[ "${mode}" == "uefi" ]]; then
        cp -f "${OVMF_VARS}" "${WORK_TMP}/efivars-${mode}.fd"
        mode_args=(
            -drive "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}"
            -drive "if=pflash,format=raw,file=${WORK_TMP}/efivars-${mode}.fd"
            -vga std
        )
    fi

    echo "=== [boot-test] Starting ${mode^^} Live Boot of $(basename "${ISO_FILE}") ==="
    qemu-system-x86_64 \
        "${ACCEL_ARGS[@]}" \
        -m 3072 \
        -smp 2 \
        -machine q35 \
        "${mode_args[@]}" \
        -drive "file=${ISO_FILE},media=cdrom,readonly=on" \
        -boot d \
        -net none \
        -device virtio-serial-pci \
        -chardev "file,id=status0,path=${status_file}" \
        -device "virtserialport,chardev=status0,name=org.anitails.status" \
        -serial "file:${serial_file}" \
        -display none \
        -no-reboot \
        2>"${qemu_err}" &
    QEMU_PID=$!

    local elapsed=0
    while (( elapsed < TIMEOUT_SECS )); do
        if grep -Fq "ANITAILS_OS_BOOT_READY" "${status_file}" 2>/dev/null; then
            echo "PASS [${mode^^}]: $(cat "${status_file}")"
            kill "${QEMU_PID}" 2>/dev/null || true
            wait "${QEMU_PID}" 2>/dev/null || true
            QEMU_PID=""
            return 0
        fi
        if grep -Fq "ANITAILS_OS_BOOT_FAILED" "${status_file}" 2>/dev/null; then
            echo "FAIL [${mode^^}]: Guest reported boot failure:" >&2
            cat "${status_file}" >&2
            local diag
            diag="$(tail -n 35 "${status_file}" | sed 's/%/%25/g; s/\r/%0D/g; :a;N;$!ba;s/\n/%0A/g')"
            echo "::error title=OS Boot Failure (${mode^^})::${diag}"
            kill "${QEMU_PID}" 2>/dev/null || true
            wait "${QEMU_PID}" 2>/dev/null || true
            QEMU_PID=""
            return 1
        fi
        if ! kill -0 "${QEMU_PID}" 2>/dev/null; then
            echo "FAIL [${mode^^}]: QEMU exited prematurely before reaching live desktop!" >&2
            cat "${qemu_err}" >&2 || true
            cat "${serial_file}" >&2 || true
            cat "${status_file}" >&2 || true
            local pdiag
            pdiag="$(cat "${qemu_err}" "${serial_file}" "${status_file}" | tail -n 30 | sed 's/%/%25/g; s/\r/%0D/g; :a;N;$!ba;s/\n/%0A/g')"
            echo "::error title=QEMU Premature Exit (${mode^^})::${pdiag:-QEMU exited before guest virtio status}"
            QEMU_PID=""
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    echo "FAIL [${mode^^}]: Timed out after ${TIMEOUT_SECS}s waiting for ANITAILS_OS_BOOT_READY!" >&2
    cat "${qemu_err}" >&2 || true
    cat "${serial_file}" >&2 || true
    cat "${status_file}" >&2 || true
    local tdiag
    tdiag="$(cat "${qemu_err}" "${serial_file}" "${status_file}" | tail -n 30 | sed 's/%/%25/g; s/\r/%0D/g; :a;N;$!ba;s/\n/%0A/g')"
    echo "::error title=OS Boot Timeout (${mode^^})::Timed out after ${TIMEOUT_SECS}s. Logs: ${tdiag}"
    kill -9 "${QEMU_PID}" 2>/dev/null || true
    QEMU_PID=""
    return 1
}

run_boot_mode bios
run_boot_mode uefi

if [[ -f "${OUT_DIR}/SHA256SUMS" ]]; then
    (cd "${OUT_DIR}" && sha256sum -c SHA256SUMS)
fi

echo "PASS: Both Legacy BIOS and UEFI Live OS boot tests reached GDM + amnesia GNOME session cleanly!"
