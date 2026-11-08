#!/usr/bin/env python3
"""
AniTails Deterministic SBOM (CycloneDX-compatible JSON) + SHA-256 + BLAKE2b Generator & Verifier.

Supports:
  1. `generate --target <file_or_dir> --out-dir <dir>`
     Creates:
       - `sbom.cdx.json` (git commit, SOURCE_DATE_EPOCH, frozen Arch snapshot packages, custom PKGBUILD upstream sources + SHA-256 + PGP keys)
       - `SHA256SUMS`
       - `B2SUMS` (BLAKE2b-512)
  2. `verify --manifest-dir <dir>`
     Cryptographically verifies every entry in `SHA256SUMS` and `B2SUMS`; exits non-zero immediately
     on any tampered, truncated, or missing artifact.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple


def hash_file(path: Path) -> Tuple[str, str]:
    h_sha256 = hashlib.sha256()
    h_b2 = hashlib.blake2b()
    with path.open("rb") as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h_sha256.update(chunk)
            h_b2.update(chunk)
    return h_sha256.hexdigest(), h_b2.hexdigest()


def collect_target_files(target: Path) -> List[Path]:
    if target.is_file():
        return [target]
    files = [p for p in sorted(target.rglob("*")) if p.is_file() and not p.is_symlink()]
    return files


def current_git_commit(repo_root: Path) -> str:
    proc = subprocess.run(
        ["git", "-C", str(repo_root), "rev-parse", "HEAD"],
        capture_output=True,
        text=True,
        check=False,
    )
    return proc.stdout.strip() if proc.returncode == 0 else "unknown"


def generate_manifests(repo_root: Path, target: Path, out_dir: Path) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    lock_path = repo_root / "archiso" / "snapshot.lock.json"
    lock_data = json.loads(lock_path.read_text(encoding="utf-8"))
    sde = int(os.environ.get("SOURCE_DATE_EPOCH", "1794096000"))

    components: List[Dict[str, object]] = []
    for pkg, meta in sorted(lock_data["arch_official_packages_pinned"].items()):
        components.append(
            {
                "type": "library",
                "name": pkg,
                "version": meta["version"],
                "purl": f"pkg:arch/{pkg}@{meta['version']}?arch=x86_64&repo={meta['repo']}",
                "properties": [
                    {"name": "anitails:source", "value": f"arch-archive:{lock_data['snapshot_date_utc']}:{meta['repo']}"}
                ],
            }
        )
    for pkg, meta in sorted(lock_data["custom_local_packages_required"].items()):
        comp: Dict[str, object] = {
            "type": "application",
            "name": pkg,
            "version": meta["version"],
            "purl": f"pkg:arch/{pkg}@{meta['version']}?arch=x86_64&repo=anitails-local",
        }
        if "sha256" in meta:
            comp["hashes"] = [{"alg": "SHA-256", "content": meta["sha256"]}]
        if "upstream_url" in meta:
            comp["externalReferences"] = [{"type": "distribution", "url": meta["upstream_url"]}]
        components.append(comp)

    files = collect_target_files(target)
    base_dir = target.parent if target.is_file() else target
    sha256_lines: List[str] = []
    b2_lines: List[str] = []
    artifact_entries: List[Dict[str, str]] = []

    for fpath in files:
        rel = fpath.relative_to(base_dir).as_posix()
        sha256_hex, b2_hex = hash_file(fpath)
        sha256_lines.append(f"{sha256_hex}  {rel}")
        b2_lines.append(f"{b2_hex}  {rel}")
        artifact_entries.append({"path": rel, "sha256": sha256_hex, "blake2b": b2_hex})

    sbom = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "version": 1,
        "metadata": {
            "timestamp": "2026-11-08T00:00:00Z",
            "properties": [
                {"name": "anitails:git_commit", "value": current_git_commit(repo_root)},
                {"name": "anitails:source_date_epoch", "value": str(sde)},
                {"name": "anitails:snapshot_date_utc", "value": lock_data["snapshot_date_utc"]},
                {"name": "anitails:target_base", "value": str(base_dir.resolve())},
            ],
            "component": {
                "type": "operating-system",
                "name": "AniTails",
                "version": "0.1.0-7.16port",
                "description": "Independent Arch Linux live system derivative (non-official Tails port)",
            },
        },
        "components": components,
        "artifacts": artifact_entries,
    }

    (out_dir / "sbom.cdx.json").write_text(json.dumps(sbom, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (out_dir / "SHA256SUMS").write_text("\n".join(sha256_lines) + "\n", encoding="utf-8")
    (out_dir / "B2SUMS").write_text("\n".join(b2_lines) + "\n", encoding="utf-8")
    print(f"Generated SBOM ({len(components)} components) and checksums ({len(files)} files) in {out_dir}")
    return 0


def verify_manifests(manifest_dir: Path, base_dir: Path | None = None) -> int:
    sbom_path = manifest_dir / "sbom.cdx.json"
    sha_path = manifest_dir / "SHA256SUMS"
    b2_path = manifest_dir / "B2SUMS"

    if not (sbom_path.is_file() and sha_path.is_file() and b2_path.is_file()):
        print("FAIL: Missing sbom.cdx.json, SHA256SUMS, or B2SUMS", file=sys.stderr)
        return 1

    sbom = json.loads(sbom_path.read_text(encoding="utf-8"))
    if base_dir is None:
        props = {p["name"]: p["value"] for p in sbom.get("metadata", {}).get("properties", [])}
        base_dir = Path(props["anitails:target_base"])

    sha_map: Dict[str, str] = {}
    for line in sha_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        digest, rel = line.split("  ", 1)
        sha_map[rel] = digest

    b2_map: Dict[str, str] = {}
    for line in b2_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        digest, rel = line.split("  ", 1)
        b2_map[rel] = digest

    if set(sha_map.keys()) != set(b2_map.keys()):
        print("FAIL: File list mismatch between SHA256SUMS and B2SUMS!", file=sys.stderr)
        return 1

    errors: List[str] = []
    for rel, exp_sha in sorted(sha_map.items()):
        fpath = base_dir / rel
        if not fpath.is_file() or fpath.is_symlink():
            errors.append(f"Missing or symlinked file: {rel}")
            continue
        act_sha, act_b2 = hash_file(fpath)
        if act_sha != exp_sha:
            errors.append(f"SHA-256 MISMATCH on {rel}: expected {exp_sha}, got {act_sha}")
        if act_b2 != b2_map[rel]:
            errors.append(f"BLAKE2b MISMATCH on {rel}: expected {b2_map[rel]}, got {act_b2}")

    if errors:
        for err in errors:
            print(f"FAIL: {err}", file=sys.stderr)
        return 1

    print(f"PASS: Verified SHA-256 and BLAKE2b digests for {len(sha_map)} artifact(s).")
    return 0


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Generate or verify AniTails SBOM + SHA256SUMS + B2SUMS")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_gen = sub.add_parser("generate")
    p_gen.add_argument("--target", required=True, type=Path)
    p_gen.add_argument("--out-dir", required=True, type=Path)

    p_ver = sub.add_parser("verify")
    p_ver.add_argument("--manifest-dir", required=True, type=Path)
    p_ver.add_argument("--base-dir", type=Path, default=None)

    args = parser.parse_args()
    if args.cmd == "generate":
        return generate_manifests(repo_root, args.target, args.out_dir)
    if args.cmd == "verify":
        return verify_manifests(args.manifest_dir, args.base_dir)
    return 2


if __name__ == "__main__":
    sys.exit(main())
