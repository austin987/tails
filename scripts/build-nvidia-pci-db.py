#!/usr/bin/env python3
"""
AniTails Authoritative NVIDIA PCI & Subsystem Hardware Database Builder
=======================================================================
Builds `/usr/share/anitails/gpu/nvidia-pci-db.json` deterministically from:
  1. NVIDIA/open-gpu-kernel-modules 615.78.08 (pinned Arch [extra] snapshot)
  2. NVIDIA/open-gpu-kernel-modules 620.70.06 (latest R620 production branch)
  3. NVIDIA/open-gpu-kernel-modules 580.196.07 & Appendix A R580/legacy rules
  4. pciutils/pciids `pci.ids` silicon die codenames & subsystem tables

Never infers support from marketing strings ("GTX"/"RTX") alone: every device
entry is keyed by 4-hex PCI device ID (`10de:xxxx`) plus `subvendor:subdevice`
overrides where identical silicon/device IDs map to distinct SKUs (e.g.
Quadro RTX 6000 vs Quadro RTX 8000 on `10de:1e30`, or Fermi `10de:1140`
sold under 610M/710M/720M/820M OEM subsystem IDs).
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import tarfile
import urllib.request
from pathlib import Path

OPEN_TAGS = {
    "615.78.08": "https://codeload.github.com/NVIDIA/open-gpu-kernel-modules/tar.gz/refs/tags/615.78.08",
    "620.70.06": "https://codeload.github.com/NVIDIA/open-gpu-kernel-modules/tar.gz/refs/tags/620.70.06",
    "580.196.07": "https://codeload.github.com/NVIDIA/open-gpu-kernel-modules/tar.gz/refs/tags/580.196.07",
}
PCIIDS_URL = "https://codeload.github.com/pciutils/pciids/tar.gz/refs/heads/master"

ARCHITECTURE_POLICIES = {
    "Vera_Rubin": {
        "generation_label": "Vera Rubin (GR100, 2026+)",
        "has_gsp": True,
        "recommended_profile": "nvidia-modern",
        "primary_driver": "nvidia-open (>= 620.70.06 tren R620; 615.78.08 chua co GR100)",
        "fallback_driver": "simpledrm (UEFI GOP / BMC VGA)",
        "firmware": "nvidia-utils GSP firmware (gsp_*.bin == driver version)",
        "wayland_support": "Co (GBM/DRM KMS voi nvidia_drm.modeset=1 fbdev=1 neu co display engine)",
        "xorg_policy": "Khong bat mac dinh (chi opt-in anitails.xorg_fallback=1)",
        "acceleration": "Compute/3D (tren R620 620.70.06); da so SKU NVL72 la 0x0302 headless",
        "cuda_min_sm": "13.0",
        "cuda_13_4_compatible": True,
        "default_test_status": "Chua kiem thu",
    },
    "Blackwell": {
        "generation_label": "Blackwell (GB100/GB102/GB20x/GB10/B200/B300/RTX 50/RTX PRO Blackwell)",
        "has_gsp": True,
        "recommended_profile": "nvidia-modern",
        "primary_driver": "nvidia-open-anitails (615.78.08 / 620.70.06 — BAT BUOC open kernel modules)",
        "fallback_driver": "simpledrm + Mesa llvmpipe (tren ban Base ISO hoac Safe Mode)",
        "firmware": "nvidia-utils GSP firmware (gsp_ga10x.bin / GB20x FMC == driver version)",
        "wayland_support": "Co (GNOME Wayland GBM + explicit sync; nvidia_drm.modeset=1 fbdev=1)",
        "xorg_policy": "Khong bat mac dinh (chi opt-in anitails.xorg_fallback=1)",
        "acceleration": "Day du 3D/Vulkan/Video tren profile nvidia-modern; Chi hien thi co ban tren profile base (nouveau tren Linux 7.3 chua ho tro tang toc 3D Blackwell)",
        "cuda_min_sm": "10.0",
        "cuda_13_4_compatible": True,
        "default_test_status": "Du kien ho tro",
    },
    "Hopper": {
        "generation_label": "Hopper (GH100 / H100 / H200 / H800 / GH200)",
        "has_gsp": True,
        "recommended_profile": "nvidia-modern",
        "primary_driver": "nvidia-open-anitails (615.78.08 / 620.70.06)",
        "fallback_driver": "BMC VGA / iGPU + simpledrm (da so Hopper la 3D controller 0x0302 khong co cong xuat hinh)",
        "firmware": "nvidia-utils GSP firmware (gsp_ga10x.bin == driver version)",
        "wayland_support": "Qua GPU hien thi phu (BMC/iGPU); Hopper la card Data Center headless (0x0302)",
        "xorg_policy": "Khong bat mac dinh",
        "acceleration": "Compute/Vulkan headless tren nvidia-modern; ho tro NVIDIA Confidential Computing",
        "cuda_min_sm": "9.0",
        "cuda_13_4_compatible": True,
        "default_test_status": "Du kien ho tro",
    },
    "Ada_Lovelace": {
        "generation_label": "Ada Lovelace (AD10x / GeForce RTX 40 / RTX Ada / L4 / L40 / L40S)",
        "has_gsp": True,
        "recommended_profile": "nvidia-modern",
        "primary_driver": "nvidia-open-anitails (615.78.08) hoac nouveau + Mesa NVK (profile base)",
        "fallback_driver": "nouveau + Mesa NVK -> simpledrm + llvmpipe",
        "firmware": "nvidia-modern: GSP gsp_ga10x.bin (615.78.08); base: linux-firmware-nvidia (ad10x GSP)",
        "wayland_support": "Co (GNOME Wayland native tren ca nvidia-modern va base nouveau/NVK)",
        "xorg_policy": "Khong bat mac dinh (chi opt-in anitails.xorg_fallback=1)",
        "acceleration": "Day du OpenGL/Vulkan tren nvidia-modern; OpenGL (zink/nvc0) + Vulkan 1.4 (NVK) tren base",
        "cuda_min_sm": "8.9",
        "cuda_13_4_compatible": True,
        "default_test_status": "Du kien ho tro",
    },
    "Ampere": {
        "generation_label": "Ampere (GA100 / GA10x / GeForce RTX 30 / RTX A-series / A100 / A10 / A30 / A40)",
        "has_gsp": True,
        "recommended_profile": "nvidia-modern",
        "primary_driver": "nvidia-open-anitails (615.78.08) hoac nouveau + Mesa NVK (profile base)",
        "fallback_driver": "nouveau + Mesa NVK -> simpledrm + llvmpipe",
        "firmware": "nvidia-modern: GSP gsp_ga10x.bin (615.78.08); base: linux-firmware-nvidia (ga10x GSP)",
        "wayland_support": "Co (GNOME Wayland native tren ca nvidia-modern va base nouveau/NVK)",
        "xorg_policy": "Khong bat mac dinh (chi opt-in anitails.xorg_fallback=1)",
        "acceleration": "Day du OpenGL/Vulkan tren nvidia-modern; OpenGL + Vulkan 1.4 (NVK) tren base",
        "cuda_min_sm": "8.0",
        "cuda_13_4_compatible": True,
        "default_test_status": "Du kien ho tro",
    },
    "Turing": {
        "generation_label": "Turing (TU10x / TU11x / GeForce GTX 16 / RTX 20 / Quadro RTX / T4 / MX450 / MX550)",
        "has_gsp": True,
        "recommended_profile": "nvidia-modern",
        "primary_driver": "nvidia-open-anitails (615.78.08) hoac nouveau + Mesa NVK (profile base)",
        "fallback_driver": "nouveau + Mesa NVK -> simpledrm + llvmpipe",
        "firmware": "nvidia-modern: GSP gsp_tu10x.bin (615.78.08); base: linux-firmware-nvidia (tu10x/tu11x GSP)",
        "wayland_support": "Co (GNOME Wayland native; luu y RTD3 Turing chi ho tro Video Memory Off)",
        "xorg_policy": "Khong bat mac dinh (chi opt-in anitails.xorg_fallback=1)",
        "acceleration": "Day du OpenGL/Vulkan tren nvidia-modern; OpenGL + Vulkan 1.4 (NVK) tren base",
        "cuda_min_sm": "7.5",
        "cuda_13_4_compatible": True,
        "default_test_status": "Du kien ho tro",
    },
    "Volta": {
        "generation_label": "Volta (GV100 / TITAN V / Quadro GV100 / Tesla V100)",
        "has_gsp": False,
        "recommended_profile": "base",
        "primary_driver": "nouveau + Mesa NVK (profile base) hoac nvidia-580xx-anitails 580.196.07 (profile legacy tuy chon)",
        "fallback_driver": "simpledrm + Mesa llvmpipe",
        "firmware": "linux-firmware-nvidia (gv100 signed ACR/Falcon) hoac proprietary 580.196.07",
        "wayland_support": "Co tren nouveau/Mesa; Co (GBM modeset=1) tren 580.196.07",
        "xorg_policy": "Khong bat mac dinh",
        "acceleration": "OpenGL/NVK tren base (gioi han reclocking); Day du 3D tren profile nvidia-legacy-580xx; KHONG ho tro boi nvidia-open hay CUDA 13.4!",
        "cuda_min_sm": "7.0",
        "cuda_13_4_compatible": False,
        "default_test_status": "Du kien ho tro",
    },
    "Pascal": {
        "generation_label": "Pascal (GP10x / GeForce GT 1010-GTX 1080 Ti / TITAN Xp / MX150-MX350 / Quadro P / Tesla P)",
        "has_gsp": False,
        "recommended_profile": "base",
        "primary_driver": "nouveau + Mesa NVK (profile base) hoac nvidia-580xx-anitails 580.196.07 (profile legacy tuy chon)",
        "fallback_driver": "simpledrm + Mesa llvmpipe",
        "firmware": "linux-firmware-nvidia (gp10x signed PMU/ACR/GR) hoac proprietary 580.196.07",
        "wayland_support": "Co tren nouveau/Mesa; Co (GBM modeset=1 fbdev=1) tren 580.196.07",
        "xorg_policy": "Khong bat mac dinh",
        "acceleration": "KMS + OpenGL + Vulkan (NVK, gioi han PMU reclocking o muc xung boot) tren base; Day du 3D tren nvidia-legacy-580xx; KHONG ho tro boi nvidia-open hay CUDA 13.4!",
        "cuda_min_sm": "6.0",
        "cuda_13_4_compatible": False,
        "default_test_status": "Du kien ho tro",
    },
    "Maxwell": {
        "generation_label": "Maxwell (GM10x / GM20x / GTX 745-750 Ti / GTX 950-980 Ti / TITAN X / MX110-130 / Quadro K620-K2200 & M-series / Tesla M)",
        "has_gsp": False,
        "recommended_profile": "base",
        "primary_driver": "nouveau + Mesa NVK (profile base) hoac nvidia-580xx-anitails 580.196.07 (profile legacy tuy chon)",
        "fallback_driver": "simpledrm + Mesa llvmpipe",
        "firmware": "linux-firmware-nvidia (gm20x signed ACR/GR; GM10x khong doi signed fw) hoac proprietary 580.196.07",
        "wayland_support": "Co tren nouveau/Mesa; Co (GBM modeset=1 fbdev=1) tren 580.196.07",
        "xorg_policy": "Khong bat mac dinh",
        "acceleration": "KMS + OpenGL + Vulkan (NVK; GM20x gioi han reclocking) tren base; Day du 3D tren nvidia-legacy-580xx; KHONG ho tro boi nvidia-open hay CUDA 13.4!",
        "cuda_min_sm": "5.0",
        "cuda_13_4_compatible": False,
        "default_test_status": "Du kien ho tro",
    },
    "Kepler": {
        "generation_label": "Kepler (GK10x / GK110 / GK208 / GeForce GT 630-GTX 780 Ti / TITAN / GT 710-740 / 820M[0fed] / 920M / Quadro K / Tesla K)",
        "has_gsp": False,
        "recommended_profile": "base",
        "primary_driver": "nouveau (nve0 Gallium OpenGL + experimental NVK) — TU CHOI 470xx EOL (yeu cau ibt=off & khong va bao mat)",
        "fallback_driver": "simpledrm + Mesa llvmpipe (Safe Mode)",
        "firmware": "In-kernel / linux-firmware-nvidia (khong can GSP)",
        "wayland_support": "Co qua nouveau KMS + GNOME Wayland",
        "xorg_policy": "Khong bat mac dinh",
        "acceleration": "OpenGL 4.3 (nouveau nve0) + Vulkan thuc nghiem (NVK); KHONG dong goi proprietary 470xx EOL vi pha IBT & Linux 7.3!",
        "cuda_min_sm": "3.0",
        "cuda_13_4_compatible": False,
        "default_test_status": "Du kien ho tro",
    },
    "Fermi": {
        "generation_label": "Fermi (GF10x / GF11x / GeForce 400-500 / GT 610-630 / GT 730[0f02] / 710M-820M[1140] / Quadro 600-7000 / Tesla C2050-M2090)",
        "has_gsp": False,
        "recommended_profile": "base",
        "primary_driver": "nouveau (nvc0 Gallium OpenGL) — TU CHOI 390xx EOL",
        "fallback_driver": "simpledrm + Mesa llvmpipe (Safe Mode)",
        "firmware": "linux-firmware-nvidia / ctxsw in-tree (khong co GSP)",
        "wayland_support": "Co qua nouveau KMS hoac simpledrm + llvmpipe",
        "xorg_policy": "Khong bat mac dinh",
        "acceleration": "OpenGL 4.3 co ban (nouveau nvc0, KHONG ho tro Vulkan NVK); hoac Chi hien thi co ban (llvmpipe) trong Safe Mode",
        "cuda_min_sm": "2.0",
        "cuda_13_4_compatible": False,
        "default_test_status": "Du kien ho tro",
    },
    "Tesla_NV50": {
        "generation_label": "Pre-Fermi Tesla NV50 (G80-G98 / GT200-GT218 / GeForce 8/9/100/200/300 / NVS 3100M / Quadro FX / Tesla C870-C1060)",
        "has_gsp": False,
        "recommended_profile": "base",
        "primary_driver": "nouveau (nv50 Gallium OpenGL 3.3) hoac simpledrm + llvmpipe — TU CHOI 340xx EOL",
        "fallback_driver": "simpledrm / VESA + Mesa llvmpipe (Safe Mode)",
        "firmware": "Khong yeu cau GSP firmware",
        "wayland_support": "Co ban qua nouveau KMS hoac Safe Mode simpledrm + llvmpipe",
        "xorg_policy": "Khong bat mac dinh",
        "acceleration": "OpenGL 3.3 co ban (nv50, khong Vulkan) hoac Chi hien thi co ban (Safe Mode tren cac laptop GT218M/Optimus doi dau nhu 10de:0a6c)",
        "cuda_min_sm": "1.0",
        "cuda_13_4_compatible": False,
        "default_test_status": "Chi hien thi co ban",
    },
    "Curie_NV40": {
        "generation_label": "Curie NV40 (GeForce 6 / GeForce 7 / Quadro FX 540-5500, 304xx EOL)",
        "has_gsp": False,
        "recommended_profile": "safe-fallback",
        "primary_driver": "simpledrm + Mesa llvmpipe (khuyen nghi) hoac nouveau nv40 co ban",
        "fallback_driver": "simpledrm / VESA + Mesa llvmpipe",
        "firmware": "Khong",
        "wayland_support": "Chi qua simpledrm + Mesa llvmpipe (GNOME 51 khong ho tro 3D OpenGL 2.1 nv40)",
        "xorg_policy": "Khong bat mac dinh",
        "acceleration": "Chi hien thi co ban (software rendering llvmpipe; luu y nhieu may thoi GeForce 6/7 la CPU 32-bit khong chay duoc x86_64)",
        "cuda_min_sm": None,
        "cuda_13_4_compatible": False,
        "default_test_status": "Chi hien thi co ban",
    },
    "Fahrenheit_Kelvin_Rankine": {
        "generation_label": "Pre-NV40 (RIVA TNT / GeForce 256 / GeForce 2-4 / GeForce FX NV04-NV30)",
        "has_gsp": False,
        "recommended_profile": "safe-fallback",
        "primary_driver": "Khong ho tro tang toc (AGP/PCI the he 1998-2004, da so CPU 32-bit IA-32)",
        "fallback_driver": "simpledrm / VESA neu mainboard x86_64 hi hiem co khe PCI",
        "firmware": "Khong",
        "wayland_support": "Khong thuc te (thieu 64-bit platform & UEFI GOP)",
        "xorg_policy": "Khong ho tro",
        "acceleration": "Khong ho tro",
        "cuda_min_sm": None,
        "cuda_13_4_compatible": False,
        "default_test_status": "Khong ho tro",
    },
}


def fetch_bytes(url: str) -> tuple[bytes, str]:
    data = urllib.request.urlopen(url, timeout=40).read()
    return data, hashlib.sha256(data).hexdigest()


def parse_open_readme(tar_bytes: bytes, ver: str) -> dict[str, dict]:
    tf = tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:gz")
    readme = tf.extractfile(f"open-gpu-kernel-modules-{ver}/README.md").read().decode("utf-8", errors="replace")
    rows = re.findall(
        r"^\|\s*([^|]+?)\s*\|\s*([0-9A-Fa-f]{4})(?:\s+([0-9A-Fa-f]{4})\s+([0-9A-Fa-f]{4}))?\s*\|",
        readme,
        re.M,
    )
    out: dict[str, dict] = {}
    for name, dev, subv, subd in rows:
        d = dev.lower()
        entry = out.setdefault(d, {"name": None, "subsystems": {}})
        if subv and subd:
            key = f"{subv.lower()}:{subd.lower()}"
            entry["subsystems"][key] = name.strip()
            if entry["name"] is None:
                entry["name"] = name.strip()
        else:
            entry["name"] = name.strip()
    return out


def parse_pciids(tar_bytes: bytes) -> dict[str, dict]:
    tf = tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:gz")
    raw = tf.extractfile("pciids-master/pci.ids").read().decode("utf-8", errors="replace")
    in_nv = False
    devs: dict[str, dict] = {}
    cur = None
    for line in raw.splitlines():
        if line.startswith("#") or not line.strip():
            continue
        if not line.startswith("\t"):
            in_nv = line.lower().startswith("10de ")
            continue
        if not in_nv:
            continue
        if line.startswith("\t\t"):
            if cur is not None:
                m = re.match(r"^\t\t([0-9a-fA-F]{4})\s+([0-9a-fA-F]{4})\s+(.+)$", line)
                if m:
                    cur["subs"][f"{m.group(1).lower()}:{m.group(2).lower()}"] = m.group(3).strip()
        else:
            m = re.match(r"^\t([0-9a-fA-F]{4})\s+(.+)$", line)
            if m:
                cur = {"desc": m.group(2).strip(), "subs": {}}
                devs[m.group(1).lower()] = cur
    return devs


def classify_chip_and_arch(dev_id: str, desc: str, in_open620: bool, in_open580: bool) -> tuple[str | None, str | None, str | None]:
    """
    Classify NVIDIA PCI device ID into (chip_code, architecture, compute_capability)
    strictly using upstream silicon die prefixes from pci.ids + open-gpu-kernel-modules
    membership + hex range boundaries from NVIDIA Appendix A.
    Returns (None, None, None) for non-GPU functions (HDA audio, USB, SATA, SMBus, etc.).
    """
    non_gpu = re.search(
        r"\b(Audio|High Definition Audio|USB|UCSI|SMBus|SATA|PATA|IDE|Ethernet|MAC|Memory Controller|"
        r"PCI Bridge|Host Bridge|LPC Bridge|ISA Bridge|Root Port|SwitchPort|NVSwitch|NVLink|DMA|Crypto|"
        r"Serial|I2C|SPI|PWM|Thermal|Tegra|Grace)\b",
        desc,
        re.I,
    )
    if non_gpu and not in_open620 and not re.search(r"\[(GeForce|Quadro|Tesla|RTX|GTX|TITAN|NVS|GRID)\b", desc):
        return None, None, None

    chip_match = re.match(
        r"^((?:NV\d+[A-Z0-9]*|G\d{2}[A-Z0-9]*|GT\d{3}[A-Z0-9]*|MCP\d+[A-Z0-9]*|C\d{2}[A-Z0-9]*|"
        r"GF\d{3}[A-Z0-9]*|GK\d{3}[A-Z0-9]*|GM\d{3}[A-Z0-9]*|GP\d{3}[A-Z0-9]*|GV\d{3}[A-Z0-9]*|"
        r"TU\d{3}[A-Z0-9]*|GA\d{3}[A-Z0-9]*|AD\d{3}[A-Z0-9]*|GH\d{3}[A-Z0-9]*|GB\d{2,3}[A-Z0-9]*|"
        r"GR\d{3}[A-Z0-9]*))\b",
        desc,
    )
    chip = chip_match.group(1) if chip_match else None
    did = int(dev_id, 16)

    if chip:
        if chip.startswith("GR1"):
            return chip, "Vera_Rubin", "13.0"
        if chip.startswith("GB100") or chip.startswith("GB102") or chip in ("GB100", "GB110", "GB112"):
            return chip, "Blackwell", "10.0"
        if chip.startswith("GB"):
            return chip, "Blackwell", "12.0"
        if chip.startswith("GH"):
            return chip, "Hopper", "9.0"
        if chip.startswith("AD"):
            return chip, "Ada_Lovelace", "8.9"
        if chip.startswith("GA100"):
            return chip, "Ampere", "8.0"
        if chip.startswith("GA"):
            return chip, "Ampere", "8.6"
        if chip.startswith("TU"):
            return chip, "Turing", "7.5"
        if chip.startswith("GV"):
            return chip, "Volta", "7.0"
        if chip.startswith("GP100"):
            return chip, "Pascal", "6.0"
        if chip.startswith("GP"):
            return chip, "Pascal", "6.1"
        if chip.startswith("GM1"):
            return chip, "Maxwell", "5.0"
        if chip.startswith("GM2"):
            return chip, "Maxwell", "5.2"
        if chip.startswith("GK210"):
            return chip, "Kepler", "3.7"
        if chip.startswith(("GK110", "GK208")):
            return chip, "Kepler", "3.5"
        if chip.startswith("GK"):
            return chip, "Kepler", "3.0"
        if chip.startswith(("GF100", "GF110")):
            return chip, "Fermi", "2.0"
        if chip.startswith("GF"):
            return chip, "Fermi", "2.1"
        if chip.startswith(("G80", "G84", "G86", "G92", "G94", "G96", "G98", "GT200", "GT215", "GT216", "GT218", "C77", "C79", "MCP77", "MCP78", "MCP79", "MCP7A", "MCP89")):
            sm = "1.3" if chip.startswith("GT200") else "1.1"
            return chip, "Tesla_NV50", sm
        if chip.startswith(("NV4", "G70", "G71", "G72", "G73", "C51", "C61", "C67", "C68", "C73", "MCP61", "MCP67", "MCP68", "MCP73")):
            return chip, "Curie_NV40", None
        if chip.startswith(("NV0", "NV1", "NV2", "NV3")):
            return chip, "Fahrenheit_Kelvin_Rankine", None

    # Fallback for brand-new IDs in open-gpu-kernel-modules not yet tagged with die prefix in pci.ids
    if in_open620 or in_open580:
        if 0x3000 <= did <= 0x30FF:
            return "GR100", "Vera_Rubin", "13.0"
        if (0x2900 <= did <= 0x2FFF) or (0x3100 <= did <= 0x32FF):
            sm = "10.0" if (0x2900 <= did <= 0x29FF or 0x3180 <= did <= 0x31FF) else "12.0"
            return "GBxxx", "Blackwell", sm
        if 0x2300 <= did <= 0x237F:
            return "GH100", "Hopper", "9.0"
        if 0x2680 <= did <= 0x28FF:
            return "AD10x", "Ada_Lovelace", "8.9"
        if 0x2080 <= did <= 0x20FF:
            return "GA100", "Ampere", "8.0"
        if (0x2200 <= did <= 0x22FF) or (0x2400 <= did <= 0x25FF):
            return "GA10x", "Ampere", "8.6"
        if 0x1E00 <= did <= 0x1FFF or 0x2180 <= did <= 0x21FF:
            return "TU1xx", "Turing", "7.5"

    return None, None, None


def is_headless_likely(name: str, arch: str) -> bool:
    if arch in ("Hopper", "Vera_Rubin"):
        return True
    return bool(
        re.search(
            r"\b(Tesla\s+[PVKMAHT]\d+|A100|A800|A30|A16|A2\b|H100|H200|H800|B100|B200|B300|GB200|GB300|"
            r"CMP\s+\d+HX|P106-|P104-|P102-|SXM\d?|HGX|DGX|PG50[03])\b",
            name,
            re.I,
        )
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--output",
        default="archiso/airootfs/usr/share/anitails/gpu/nvidia-pci-db.json",
        help="Destination JSON path",
    )
    args = ap.parse_args()

    sources_meta = {}
    open_tables = {}
    for ver, url in OPEN_TAGS.items():
        b, sha = fetch_bytes(url)
        sources_meta[f"open-gpu-kernel-modules-{ver}"] = {"url": url, "sha256": sha}
        open_tables[ver] = parse_open_readme(b, ver)

    pci_bytes, pci_sha = fetch_bytes(PCIIDS_URL)
    sources_meta["pciutils-pciids-master"] = {"url": PCIIDS_URL, "sha256": pci_sha}
    pci_devs = parse_pciids(pci_bytes)

    all_ids = sorted(set(pci_devs.keys()) | set(open_tables["615.78.08"].keys()) | set(open_tables["620.70.06"].keys()))

    devices_out = {}
    arch_counts: dict[str, int] = {}

    for dev_id in all_ids:
        in_615 = dev_id in open_tables["615.78.08"]
        in_620 = dev_id in open_tables["620.70.06"]
        in_580_open = dev_id in open_tables["580.196.07"]
        pinfo = pci_devs.get(dev_id, {"desc": "", "subs": {}})
        desc = pinfo["desc"]

        chip, arch, sm = classify_chip_and_arch(dev_id, desc, in_620, in_580_open)
        if arch is None:
            continue

        # Canonical name preference: open_620 -> open_615 -> pci.ids bracketed marketing name -> pci.ids desc
        name = None
        if in_620 and open_tables["620.70.06"][dev_id]["name"]:
            name = open_tables["620.70.06"][dev_id]["name"]
        elif in_615 and open_tables["615.78.08"][dev_id]["name"]:
            name = open_tables["615.78.08"][dev_id]["name"]
        elif desc:
            m_br = re.search(r"\[([^\]]+)\]", desc)
            name = m_br.group(1).strip() if m_br else desc
        else:
            name = f"NVIDIA GPU {dev_id}"

        # Collect meaningful subsystem overrides (SKU disambiguation, Max-Q, OEM rebrands like 1140/1e30/2bb3)
        subs_merged: dict[str, str] = {}
        for ver in ("615.78.08", "620.70.06"):
            if dev_id in open_tables[ver]:
                for sk, sv in open_tables[ver][dev_id]["subsystems"].items():
                    if sv != name:
                        subs_merged[sk] = sv
        # Also include pci.ids subsystem rebrands when they change the commercial model name
        for sk, sv in pinfo["subs"].items():
            if sk not in subs_merged:
                m_sub = re.search(r"\[([^\]]+)\]", sv)
                if m_sub:
                    sub_model = m_sub.group(1).strip()
                    if sub_model.lower() != name.lower():
                        subs_merged[sk] = sub_model
                elif dev_id in ("1e30", "137a", "0f02", "1287", "1380", "139b", "1140"):
                    subs_merged[sk] = sv

        legacy_580 = arch in ("Maxwell", "Pascal", "Volta", "Turing", "Ampere", "Ada_Lovelace", "Hopper") or in_580_open
        has_gsp = arch in ("Turing", "Ampere", "Ada_Lovelace", "Hopper", "Blackwell", "Vera_Rubin")

        if arch in ("Turing", "Ampere", "Ada_Lovelace"):
            nvk = "production"
            nouveau = "supported"
        elif arch in ("Maxwell", "Pascal", "Volta"):
            nvk = "supported_open"
            nouveau = "supported"
        elif arch == "Kepler":
            nvk = "experimental"
            nouveau = "supported"
        elif arch in ("Fermi", "Tesla_NV50", "Curie_NV40"):
            nvk = "unsupported"
            nouveau = "display_3d_limited"
        else:
            nvk = "unsupported"
            nouveau = "unsupported_needs_nvidia_open"

        rec_Entry = {
            "chip": chip or "UNKNOWN",
            "name": name,
            "arch": arch,
            "sm": sm,
            "gsp": has_gsp,
            "open_615": in_615,
            "open_620": in_620,
            "legacy_580": legacy_580,
            "nouveau": nouveau,
            "nvk": nvk,
            "headless_hint": is_headless_likely(name, arch),
        }
        if subs_merged:
            rec_Entry["subsystems"] = dict(sorted(subs_merged.items()))

        devices_out[dev_id] = rec_Entry
        arch_counts[arch] = arch_counts.get(arch, 0) + 1

    db = {
        "schema_version": 1,
        "generated_date_utc": "2026-11-08",
        "vendor_id": "10de",
        "upstream_sources": sources_meta,
        "architecture_counts": dict(sorted(arch_counts.items())),
        "architecture_policies": ARCHITECTURE_POLICIES,
        "devices": devices_out,
    }

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(db, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(devices_out)} NVIDIA GPU PCI IDs across {len(arch_counts)} architectures -> {out_path} ({out_path.stat().st_size} bytes)")
    for k, v in sorted(arch_counts.items()):
        print(f"  {k:28s}: {v}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
