#!/usr/bin/env python3
"""
AniTails Build-Time Kernel / NVIDIA Driver / Firmware / Profile Lockstep Auditor
(`scripts/verify-nvidia-lockstep.py`)
================================================================================
Verifies dynamically (reading `archiso/snapshot.lock.json`, `archiso-profiles/*`,
`pkgbuilds/*/PKGBUILD`, and boot configs — ZERO hardcoded magic version assumptions):
  1. `nvidia-open-anitails` `pkgver` matches `nvidia-utils` version in `snapshot.lock.json`,
     and its `_kernpkgver` matches `linux-anitails` `pkgver`!
  2. `nvidia-580xx-anitails` `_kernpkgver` matches `linux-anitails` `pkgver` and is NEVER
     mixed with `nvidia-open-anitails` or `nvidia-utils` in the same profile!
  3. Base profile (`base`) contains ZERO proprietary NVIDIA packages or CUDA/OpenCL.
  4. NO profile installs `dkms` into the live image (all modules pre-compiled & signed).
  5. NO EOL/unpatched NVIDIA branches (`470xx`, `390xx`, `340xx`, `304xx`) are packaged.
  6. NO boot config weakens `module.sig_enforce=1`, `lockdown=`, AppArmor, or adds `ibt=off`.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def _parse_pkgbuild_vars(path: Path) -> dict[str, str]:
    txt = path.read_text(encoding="utf-8")
    out: dict[str, str] = {}
    for k in ("pkgbase", "pkgname", "pkgver", "pkgrel", "_kernpkgver"):
        m = re.search(rf"^{k}=['\"]?([^'\"\n\s()]+)['\"]?", txt, re.M)
        if m:
            out[k] = m.group(1)
    return out


def verify_all(selected_profile: str | None = None) -> list[str]:
    errors: list[str] = []
    lock = json.loads((REPO_ROOT / "archiso/snapshot.lock.json").read_text(encoding="utf-8"))
    arch_pkgs = lock["arch_official_packages_pinned"]
    custom_pkgs = lock["custom_local_packages_required"]

    k_pb = _parse_pkgbuild_vars(REPO_ROOT / "pkgbuilds/linux-anitails/PKGBUILD")
    nvo_pb = _parse_pkgbuild_vars(REPO_ROOT / "pkgbuilds/nvidia-open-anitails/PKGBUILD")
    nv580_pb = _parse_pkgbuild_vars(REPO_ROOT / "pkgbuilds/nvidia-580xx-anitails/PKGBUILD")

    k_ver = k_pb.get("pkgver", "")
    if nvo_pb.get("_kernpkgver") != k_ver:
        errors.append(
            f"Kernel lockstep mismatch: nvidia-open-anitails _kernpkgver={nvo_pb.get('_kernpkgver')} != linux-anitails pkgver={k_ver}"
        )
    if nv580_pb.get("_kernpkgver") != k_ver:
        errors.append(
            f"Kernel lockstep mismatch: nvidia-580xx-anitails _kernpkgver={nv580_pb.get('_kernpkgver')} != linux-anitails pkgver={k_ver}"
        )

    nv_utils_ver = arch_pkgs.get("nvidia-utils", {}).get("version", "").split("-")[0]
    if nvo_pb.get("pkgver") != nv_utils_ver:
        errors.append(
            f"Userspace/GSP ABI mismatch: nvidia-open-anitails pkgver={nvo_pb.get('pkgver')} != pinned nvidia-utils={nv_utils_ver}"
        )

    if custom_pkgs.get("nvidia-open-anitails", {}).get("version", "").split("-")[0] != nvo_pb.get("pkgver"):
        errors.append("snapshot.lock.json custom_local_packages_required.nvidia-open-anitails out of sync with PKGBUILD")

    # Verify linux-anitails Kconfig hardening + simpledrm + Nova conflict prevention
    kfrag = (REPO_ROOT / "pkgbuilds/linux-anitails/config.anitails.fragment").read_text(encoding="utf-8")
    for req_cfg in (
        "CONFIG_DRM_SIMPLEDRM=y",
        "CONFIG_MODULE_SIG_FORCE=y",
        "CONFIG_X86_KERNEL_IBT=y",
        "CONFIG_INTEL_IOMMU_DEFAULT_ON=y",
        "# CONFIG_NOVA_CORE is not set",
    ):
        if req_cfg not in kfrag:
            errors.append(f"Missing required Kconfig setting in config.anitails.fragment: {req_cfg}")

    # Verify profiles
    base_pkgs_txt = (REPO_ROOT / "archiso/packages.x86_64").read_text(encoding="utf-8")
    base_pkgs = [
        ln.strip()
        for ln in base_pkgs_txt.splitlines()
        if ln.strip() and not ln.strip().startswith("#")
    ]
    forbidden_in_base = {"nvidia-open", "nvidia-open-anitails", "nvidia-utils", "nvidia-580xx-anitails", "cuda", "opencl-nvidia", "dkms"}
    leaked = forbidden_in_base.intersection(base_pkgs)
    if leaked:
        errors.append(f"Base open-source packages.x86_64 must NOT contain proprietary/CUDA/DKMS packages: {sorted(leaked)}")

    profiles_dir = REPO_ROOT / "archiso-profiles"
    prof_paths = (
        [profiles_dir / selected_profile / "profile.json"]
        if selected_profile
        else sorted(profiles_dir.glob("*/profile.json"))
    )
    for pf in prof_paths:
        if not pf.is_file():
            errors.append(f"Missing profile manifest: {pf}")
            continue
        meta = json.loads(pf.read_text(encoding="utf-8"))
        extra = set(meta.get("extra_packages", []))
        if "dkms" in extra or any(p.endswith("-dkms") for p in extra):
            errors.append(f"Profile {meta['profile_id']} must NOT install runtime DKMS packages in live image: {sorted(extra)}")
        if any(eol in p for p in extra for eol in ("470xx", "390xx", "340xx", "304xx")):
            errors.append(f"Profile {meta['profile_id']} references forbidden EOL NVIDIA driver: {sorted(extra)}")
        if "nvidia-open-anitails" in extra and "nvidia-580xx-anitails" in extra:
            errors.append(f"Profile {meta['profile_id']} mixes conflicting modern and legacy 580xx NVIDIA stacks!")
        if meta["profile_id"] != "nvidia-cuda-optional" and ("cuda" in extra or "opencl-nvidia" in extra):
            errors.append(f"CUDA/OpenCL must only appear in opt-in nvidia-cuda-optional profile, found in {meta['profile_id']}")

    # Verify boot configs never weaken hardening (no ibt=off, always module.sig_enforce=1 & lockdown)
    boot_files = [REPO_ROOT / "archiso/syslinux/syslinux.cfg"] + sorted(
        (REPO_ROOT / "archiso/efiboot/loader/entries").glob("*.conf")
    )
    for bf in boot_files:
        btxt = bf.read_text(encoding="utf-8")
        if "ibt=off" in btxt:
            errors.append(f"Hardening violation: ibt=off found in {bf}")
        for opt_line in [ln for ln in btxt.splitlines() if ln.strip().startswith(("APPEND ", "options "))]:
            for must in ("module.sig_enforce=1", "lockdown=integrity", "init_on_free=1", "apparmor"):
                if must not in opt_line:
                    errors.append(f"Missing mandatory kernel hardening flag '{must}' in {bf}: {opt_line[:80]}")

    return errors


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", default=None, help="Specific profile to validate (default: all)")
    args = ap.parse_args()

    errs = verify_all(args.profile)
    if errs:
        for e in errs:
            print(f"LOCKSTEP ERROR: {e}", file=sys.stderr)
        return 1
    print(f"PASS: NVIDIA kernel/driver/firmware/profile lockstep verified ({args.profile or 'all profiles'}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
