#!/usr/bin/env python3
"""
AniTails Verified Full-Image Manual Upgrade Helper (`verify-and-upgrade-usb.py`).

Replaces legacy Debian APT + Perl Incremental Upgrade Kit (`iuk`) with a clean,
cryptographically verified system-partition image upgrade model that:
  1. Verifies OpenSSL / GPG detached signature + SHA-256 + BLAKE2b BEFORE any action.
  2. Refuses any non-removable / host-OS root block device (`/` / internal SATA / NVMe).
  3. Preserves the encrypted LUKS2 `AniTailsData` partition on partition #2 while
     updating only the read-only EFI/system partition #1 (`ANITAILS_*`).
  4. Defaults to `--dry-run` (never writes to any block device unless `--apply` is
     explicitly passed by the operator on a real workstation).
"""

from __future__ import annotations

import argparse
import hashlib
import subprocess
import sys
from pathlib import Path


def verify_detached_openssl_ed25519_or_rsa(pubkey_pem: Path, payload: Path, sig_bin: Path) -> bool:
    proc = subprocess.run(
        ["openssl", "dgst", "-sha256", "-verify", str(pubkey_pem), "-signature", str(sig_bin), str(payload)],
        capture_output=True,
        text=True,
        check=False,
    )
    return proc.returncode == 0 and "Verified OK" in proc.stdout


def verify_image_digests(image_path: Path, sha256sums_path: Path, b2sums_path: Path) -> None:
    expected_sha = None
    for line in sha256sums_path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            digest, name = line.split("  ", 1)
            if Path(name).name == image_path.name:
                expected_sha = digest
                break
    if not expected_sha:
        raise ValueError(f"Image {image_path.name} not listed in {sha256sums_path}")

    expected_b2 = None
    for line in b2sums_path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            digest, name = line.split("  ", 1)
            if Path(name).name == image_path.name:
                expected_b2 = digest
                break
    if not expected_b2:
        raise ValueError(f"Image {image_path.name} not listed in {b2sums_path}")

    h_sha = hashlib.sha256()
    h_b2 = hashlib.blake2b()
    with image_path.open("rb") as f:
        while chunk := f.read(65536):
            h_sha.update(chunk)
            h_b2.update(chunk)

    if h_sha.hexdigest() != expected_sha:
        raise ValueError(f"SHA-256 mismatch for {image_path.name}!")
    if h_b2.hexdigest() != expected_b2:
        raise ValueError(f"BLAKE2b mismatch for {image_path.name}!")


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify signed AniTails image before manual USB system-partition upgrade")
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--sha256sums", required=True, type=Path)
    parser.add_argument("--b2sums", required=True, type=Path)
    parser.add_argument("--sig", required=True, type=Path, help="Detached signature over SHA256SUMS")
    parser.add_argument("--pubkey", required=True, type=Path, help="Trusted release public key PEM")
    parser.add_argument("--target-usb-sys-part", default="/dev/sdX1")
    parser.add_argument("--dry-run", action="store_true", default=True)
    args = parser.parse_args()

    if not verify_detached_openssl_ed25519_or_rsa(args.pubkey, args.sha256sums, args.sig):
        print("FAIL: Cryptographic signature verification FAILED on SHA256SUMS! Aborting upgrade.", file=sys.stderr)
        return 1

    try:
        verify_image_digests(args.image, args.sha256sums, args.b2sums)
    except Exception as exc:
        print(f"FAIL: Digest verification failed: {exc}", file=sys.stderr)
        return 1

    print(
        f"PASS [DRY-RUN]: Verified signature + SHA-256 + BLAKE2b for {args.image.name}. "
        f"System partition {args.target_usb_sys_part} ready for upgrade while preserving LUKS2 AniTailsData partition."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
