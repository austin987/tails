#!/usr/bin/env bash
# AniTails End-to-End Live OS Boot Verifier (QEMU BIOS USB3 + UEFI OVMF CD-ROM)
# ==============================================================================
# Boots the unmodified built `.iso` image in TWO distinct firmware/media/GPU modes:
#   1. Legacy BIOS + USB 3.0 Flash Stick (`isohdpfx.bin` -> `syslinux` + `virtio-vga` KMS)
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

capture_qmp_screen_ocr() {
    local qmp_sock="$1"
    local ppm_file="$2"
    if [[ ! -S "${qmp_sock}" ]]; then
        return 0
    fi
    python3 - "${qmp_sock}" "${ppm_file}" <<'PY' 2>/dev/null || true
import json, socket, sys, time
sock_path, ppm_path = sys.argv[1], sys.argv[2]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(3.0)
s.connect(sock_path)
s.recv(4096)
s.sendall(b'{"execute":"qmp_capabilities"}\n')
time.sleep(0.2)
s.recv(4096)
cmd = json.dumps({"execute": "screendump", "arguments": {"filename": ppm_path}}).encode() + b"\n"
s.sendall(cmd)
time.sleep(0.5)
s.recv(4096)
s.close()
PY
    if [[ -s "${ppm_file}" ]] && command -v tesseract >/dev/null 2>&1; then
        tesseract "${ppm_file}" stdout 2>/dev/null | tr -s '\n' | tail -n 25 || true
    fi
}

diagnose_direct_kernel_serial() {
    if ! command -v bsdtar >/dev/null 2>&1; then
        return 0
    fi
    echo "=== [boot-test] Running 45s direct kernel+initramfs serial trace for root-cause inspection ===" >&2
    local diag_dir="${WORK_TMP}/direct-diag"
    local diag_log="${WORK_TMP}/direct-serial.log"
    mkdir -p "${diag_dir}"
    bsdtar -xf "${ISO_FILE}" -C "${diag_dir}" \
        arch/boot/x86_64/vmlinuz-linux-anitails \
        arch/boot/x86_64/initramfs-linux-anitails.img \
        loader/entries/01-anitails-x86_64-linux.conf 2>/dev/null || return 0

    local kopts
    kopts="$(awk '/^options[[:space:]]+/{sub(/^options[[:space:]]+/,""); print; exit}' "${diag_dir}/loader/entries/01-anitails-x86_64-linux.conf" | sed 's/\bquiet\b//g')"
    kopts="${kopts} earlyprintk=serial,ttyS0,115200 console=ttyS0,115200 loglevel=7 systemd.log_level=info"

    timeout 45 qemu-system-x86_64 \
        "${ACCEL_ARGS[@]}" \
        -m 3072 \
        -smp 2 \
        -machine q35 \
        -vga std \
        -drive "file=${ISO_FILE},media=cdrom,readonly=on" \
        -net none \
        -kernel "${diag_dir}/arch/boot/x86_64/vmlinuz-linux-anitails" \
        -initrd "${diag_dir}/arch/boot/x86_64/initramfs-linux-anitails.img" \
        -append "${kopts}" \
        -serial "file:${diag_log}" \
        -display none \
        -no-reboot >/dev/null 2>&1 || true

    if [[ -s "${diag_log}" ]]; then
        local err_excerpt tail_excerpt
        err_excerpt="$(grep -iE 'panic|error|fail|denied|corrupt|unable|interactive|timeout|reject|missing|emergency' "${diag_log}" | tail -n 25 | sed 's/%/%25/g; s/\r/%0D/g; :a;N;$!ba;s/\n/%0A/g' || true)"
        tail_excerpt="$(tail -n 35 "${diag_log}" | sed 's/%/%25/g; s/\r/%0D/g; :a;N;$!ba;s/\n/%0A/g')"
        [[ -n "${err_excerpt}" ]] && echo "::error title=Direct Kernel Serial Errors::${err_excerpt}"
        echo "::error title=Direct Kernel Serial Tail::${tail_excerpt}"
    fi
}

run_boot_mode() {
    local mode="$1"
    local status_file="${WORK_TMP}/status-${mode}.log"
    local serial_file="${WORK_TMP}/serial-${mode}.log"
    local qemu_err="${WORK_TMP}/qemu-${mode}.err"
    local qmp_sock="${WORK_TMP}/qmp-${mode}.sock"
    local vnc_sock="${WORK_TMP}/vnc-${mode}.sock"
    local ppm_file="${WORK_TMP}/screen-${mode}.ppm"
    : > "${status_file}"
    : > "${serial_file}"
    rm -f "${qmp_sock}" "${vnc_sock}" "${ppm_file}"

    local -a mode_args=()
    if [[ "${mode}" == "bios" ]]; then
        mode_args=(
            -machine pc
            -vga virtio
            -device qemu-xhci,id=xhci0
            -drive "if=none,id=usbdisk0,format=raw,readonly=on,file=${ISO_FILE}"
            -device "usb-storage,bus=xhci0.0,drive=usbdisk0,bootindex=1,removable=on"
        )
    elif [[ "${mode}" == "uefi" ]]; then
        cp -f "${OVMF_VARS}" "${WORK_TMP}/efivars-${mode}.fd"
        mode_args=(
            -machine q35
            -drive "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}"
            -drive "if=pflash,format=raw,file=${WORK_TMP}/efivars-${mode}.fd"
            -vga std
            -drive "file=${ISO_FILE},media=cdrom,readonly=on"
            -boot d
        )
    fi

    echo "=== [boot-test] Starting ${mode^^} Live Boot of $(basename "${ISO_FILE}") ==="
    qemu-system-x86_64 \
        "${ACCEL_ARGS[@]}" \
        -m 3072 \
        -smp 2 \
        "${mode_args[@]}" \
        -net none \
        -device virtio-serial-pci \
        -chardev "file,id=status0,path=${status_file}" \
        -device "virtserialport,chardev=status0,name=org.anitails.status" \
        -serial "file:${serial_file}" \
        -qmp "unix:${qmp_sock},server=on,wait=off" \
        -vnc "unix:${vnc_sock}" \
        -no-reboot \
        2>"${qemu_err}" &
    QEMU_PID=$!

    local elapsed=0
    while (( elapsed < TIMEOUT_SECS )); do
        if grep -Fq "ANITAILS_OS_BOOT_READY" "${serial_file}" "${status_file}" 2>/dev/null; then
            echo "PASS [${mode^^}]:"
            grep -F "ANITAILS_" "${serial_file}" "${status_file}" 2>/dev/null || true
            kill "${QEMU_PID}" 2>/dev/null || true
            wait "${QEMU_PID}" 2>/dev/null || true
            QEMU_PID=""
            return 0
        fi
        if grep -Fq "ANITAILS_OS_BOOT_FAILED" "${serial_file}" "${status_file}" 2>/dev/null; then
            local ocr_txt
            ocr_txt="$(capture_qmp_screen_ocr "${qmp_sock}" "${ppm_file}")"
            echo "FAIL [${mode^^}]: Guest reported boot failure:" >&2
            cat "${serial_file}" "${status_file}" >&2
            [[ -n "${ocr_txt}" ]] && printf "=== Screen OCR ===\n%s\n" "${ocr_txt}" >&2
            local diag
            diag="$( { cat "${serial_file}" "${status_file}"; [[ -n "${ocr_txt}" ]] && printf "ScreenOCR:\n%s\n" "${ocr_txt}"; } | tail -n 40 | sed 's/%/%25/g; s/\r/%0D/g; :a;N;$!ba;s/\n/%0A/g' )"
            echo "::error title=OS Boot Failure (${mode^^})::${diag}"
            kill "${QEMU_PID}" 2>/dev/null || true
            wait "${QEMU_PID}" 2>/dev/null || true
            QEMU_PID=""
            return 1
        fi
        if ! kill -0 "${QEMU_PID}" 2>/dev/null; then
            echo "FAIL [${mode^^}]: QEMU exited prematurely before reaching live desktop!" >&2
            cat "${qemu_err}" "${serial_file}" "${status_file}" >&2 || true
            local pdiag
            pdiag="$(cat "${qemu_err}" "${serial_file}" "${status_file}" | tail -n 35 | sed 's/%/%25/g; s/\r/%0D/g; :a;N;$!ba;s/\n/%0A/g')"
            echo "::error title=QEMU Premature Exit (${mode^^})::${pdiag:-QEMU exited before guest virtio status}"
            QEMU_PID=""
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    local ocr_txt
    ocr_txt="$(capture_qmp_screen_ocr "${qmp_sock}" "${ppm_file}")"
    echo "FAIL [${mode^^}]: Timed out after ${TIMEOUT_SECS}s waiting for ANITAILS_OS_BOOT_READY!" >&2
    cat "${qemu_err}" "${serial_file}" "${status_file}" >&2 || true
    [[ -n "${ocr_txt}" ]] && printf "=== Screen OCR ===\n%s\n" "${ocr_txt}" >&2
    local tdiag
    tdiag="$( { cat "${qemu_err}" "${serial_file}" "${status_file}"; [[ -n "${ocr_txt}" ]] && printf "ScreenOCR:\n%s\n" "${ocr_txt}"; } | tail -n 35 | sed 's/%/%25/g; s/\r/%0D/g; :a;N;$!ba;s/\n/%0A/g' )"
    echo "::error title=OS Boot Timeout (${mode^^})::Timed out after ${TIMEOUT_SECS}s. Logs: ${tdiag}"
    kill -9 "${QEMU_PID}" 2>/dev/null || true
    wait "${QEMU_PID}" 2>/dev/null || true
    QEMU_PID=""
    return 1
}

OVERALL_RC=0
run_boot_mode bios || OVERALL_RC=1
run_boot_mode uefi || OVERALL_RC=1

if [[ "${OVERALL_RC}" -ne 0 ]]; then
    diagnose_direct_kernel_serial
    exit "${OVERALL_RC}"
fi

if [[ -f "${OUT_DIR}/SHA256SUMS" ]]; then
    (cd "${OUT_DIR}" && sha256sum -c SHA256SUMS)
fi

echo "PASS: Both Legacy BIOS (USB3) and UEFI (OVMF) Live OS boot tests reached GDM + amnesia GNOME session cleanly!"
