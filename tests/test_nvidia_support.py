#!/usr/bin/env python3
"""
Test Suite 8: Comprehensive NVIDIA GPU Identification, Multi-Generation Profile Dispatch,
ABI/Signature Lockstep, Fallback Safety, CUDA SM Validation, and GPU Privacy/Amnesia.

NOTE ON HARDWARE TRUTHFULNESS:
These tests validate deterministic sysfs/rootfs simulation, PCI+subsystem classification
across 1,558 real upstream NVIDIA PCI IDs, conflict-free driver selection, negative-control
ABI/signature rejection, and privacy redaction. Because this container sandbox has zero
physical PCI/GPU devices (`/sys/bus/pci/devices` empty), physical GPU KMS/rendering/GSP
execution on real NVIDIA silicon is honestly reported as `SKIPPED` / `BLOCKED` in
`tests/run_all_tests.py` — NEVER fabricated from virtual or simulated tests.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DETECT_BIN = REPO_ROOT / "archiso/airootfs/usr/local/bin/anitails-gpu-detect"
SELECT_BIN = REPO_ROOT / "archiso/airootfs/usr/local/bin/anitails-gpu-select"
CUDA_BIN = REPO_ROOT / "archiso/airootfs/usr/local/bin/anitails-cuda-check"
DB_PATH = REPO_ROOT / "archiso/airootfs/usr/share/anitails/gpu/nvidia-pci-db.json"
MODSIG_MAGIC = b"~Module signature appended~\n"


def _add_pci_dev(
    root: Path,
    bdf: str,
    vendor: str,
    device: str,
    sub_vendor: str = "10de",
    sub_device: str = "0000",
    pci_class: str = "0x030000",
    boot_vga: str = "1",
    bound_driver: str | None = None,
    connectors: dict[str, str] | None = None,
    egpu_tb: bool = False,
    iommu: bool = True,
) -> Path:
    dev = root / "sys/bus/pci/devices" / bdf
    dev.mkdir(parents=True, exist_ok=True)
    (dev / "vendor").write_text(f"0x{vendor}\n", encoding="utf-8")
    (dev / "device").write_text(f"0x{device}\n", encoding="utf-8")
    (dev / "subsystem_vendor").write_text(f"0x{sub_vendor}\n", encoding="utf-8")
    (dev / "subsystem_device").write_text(f"0x{sub_device}\n", encoding="utf-8")
    (dev / "class").write_text(f"{pci_class}\n", encoding="utf-8")
    (dev / "boot_vga").write_text(f"{boot_vga}\n", encoding="utf-8")
    if bound_driver:
        drv_target = root / "sys/bus/pci/drivers" / bound_driver
        drv_target.mkdir(parents=True, exist_ok=True)
        os.symlink(drv_target, dev / "driver")
    if connectors:
        drm = dev / "drm/card0"
        drm.mkdir(parents=True, exist_ok=True)
        for cname, status in connectors.items():
            cdir = dev / "drm" / f"card0-{cname}"
            cdir.mkdir(parents=True, exist_ok=True)
            (cdir / "status").write_text(f"{status}\n", encoding="utf-8")
    if egpu_tb:
        (dev / "anitails_thunderbolt_egpu").write_text("1\n", encoding="utf-8")
    if iommu:
        (root / "sys/class/iommu/dmar0").mkdir(parents=True, exist_ok=True)
        os.symlink(root / "sys/class/iommu/dmar0", dev / "iommu_group")
    return dev


def _install_mock_nvidia_stack(
    root: Path,
    kernver: str = "7.3.3-anitails1",
    mod_ver: str = "615.78.08",
    userspace_ver: str = "615.78.08",
    gsp_ver: str | None = "615.78.08",
    license_str: str = "Dual MIT/GPL",
    vermagic_kern: str | None = None,
    signed: bool = True,
) -> None:
    vm_k = vermagic_kern or kernver
    extradir = root / f"usr/lib/modules/{kernver}/extramodules"
    extradir.mkdir(parents=True, exist_ok=True)
    payload = (
        f"\x00version={mod_ver}\x00license={license_str}\x00vermagic={vm_k} SMP preempt mod_unload \x00".encode("ascii")
    )
    if signed:
        payload += b"\x00SIGNER_KEY_DATA" + MODSIG_MAGIC
    (extradir / "nvidia.ko").write_bytes(payload)

    usr_lib = root / "usr/lib"
    usr_lib.mkdir(parents=True, exist_ok=True)
    (usr_lib / f"libGLX_nvidia.so.{userspace_ver}").write_bytes(b"\x7fELF_MOCK")
    (usr_lib / f"libcuda.so.{userspace_ver}").write_bytes(b"\x7fELF_MOCK")

    if gsp_ver:
        fw_dir = root / f"usr/lib/firmware/nvidia/{gsp_ver}"
        fw_dir.mkdir(parents=True, exist_ok=True)
        (fw_dir / "gsp_tu10x.bin").write_bytes(b"GSP_TU10X")
        (fw_dir / "gsp_ga10x.bin").write_bytes(b"GSP_GA10X")


class TestNvidiaSupport(unittest.TestCase):
    def test_pci_and_subsystem_disambiguation_across_all_generations(self) -> None:
        db = json.loads(DB_PATH.read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(db["devices"]), 1500)

        cases = [
            # Marketing-name traps where ONLY PCI vendor:device + subsys tells the truth!
            ("0f02", "10de", "0000", "Fermi", "GeForce GT 730", False, False, False),
            ("1287", "10de", "0000", "Kepler", "GeForce GT 730", False, False, False),
            ("1140", "17aa", "3812", "Fermi", "GeForce 820M", False, False, False),
            ("0fed", "10de", "0000", "Kepler", "GeForce 820M", False, False, False),
            ("137a", "17aa", "2225", "Maxwell", "Quadro K620M", False, False, True),
            ("12b9", "10de", "0000", "Kepler", "Quadro K610M", False, False, False),
            ("1380", "10de", "0000", "Maxwell", "GeForce GTX 750 Ti", False, False, True),
            ("1c94", "10de", "0000", "Pascal", "GeForce MX350", False, False, True),
            ("1f97", "10de", "0000", "Turing", "NVIDIA GeForce MX450", True, True, True),
            # Identical PCI device ID 10de:1e30 disambiguated strictly via PCI subsystem ID!
            ("1e30", "10de", "12ba", "Turing", "Quadro RTX 6000", True, True, True),
            ("1e30", "10de", "129e", "Turing", "Quadro RTX 8000", True, True, True),
            # Pre-Fermi Tesla, Volta, Ampere, Ada, Hopper, Blackwell, Vera Rubin
            ("0a6c", "10de", "0000", "Tesla_NV50", "NVS 3100M", False, False, False),
            ("1b80", "10de", "0000", "Pascal", "GeForce GTX 1080", False, False, True),
            ("1db6", "10de", "0000", "Volta", "Tesla V100 PCIe 32GB", False, False, True),
            ("2204", "10de", "0000", "Ampere", "NVIDIA GeForce RTX 3090", True, True, True),
            ("2684", "10de", "0000", "Ada_Lovelace", "NVIDIA GeForce RTX 4090", True, True, True),
            ("2330", "10de", "0000", "Hopper", "NVIDIA H100 80GB HBM3", True, True, True),
            ("2b85", "10de", "0000", "Blackwell", "NVIDIA GeForce RTX 5090", True, True, True),
            ("3041", "10de", "2304", "Vera_Rubin", "NVIDIA VR NVL72", True, False, False),
        ]

        with tempfile.TemporaryDirectory() as td:
            for idx, (dev_id, sv, sd, exp_arch, exp_model_substr, exp_gsp, exp_615, exp_580) in enumerate(cases):
                sub_root = Path(td) / f"case_{idx}"
                _add_pci_dev(sub_root, "0000:01:00.0", "10de", dev_id, sv, sd, bound_driver="nouveau")
                proc = subprocess.run(
                    ["python3", str(DETECT_BIN), "--sysfs-root", str(sub_root), "--db", str(DB_PATH)],
                    capture_output=True, text=True, check=True,
                )
                rep = json.loads(proc.stdout)
                nv = rep["gpus"][0]["nvidia"]
                self.assertEqual(nv["architecture"], exp_arch, f"Failed arch for 10de:{dev_id} [{sv}:{sd}]")
                self.assertIn(exp_model_substr, nv["resolved_model"], f"Failed model for 10de:{dev_id} [{sv}:{sd}]")
                self.assertEqual(nv["has_gsp"], exp_gsp)
                self.assertEqual(nv["nvidia_open_615_supported"], exp_615)
                self.assertEqual(nv["nvidia_legacy_580_supported"], exp_580)

    def test_conflict_free_dispatch_and_no_global_nouveau_blacklist(self) -> None:
        cmdline = "lockdown=integrity module.sig_enforce=1 init_on_free=1 quiet"

        # 1. RTX 5090 (Blackwell 10de:2b85) on `nvidia-modern` rootfs -> selects signed nvidia_open
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:01:00.0", "10de", "2b85")
            _install_mock_nvidia_stack(r, mod_ver="615.78.08", userspace_ver="615.78.08", gsp_ver="615.78.08")
            proc = subprocess.run(
                ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", cmdline, "--uname-r", "7.3.3-anitails1"],
                capture_output=True, text=True, check=True,
            )
            dec = json.loads(proc.stdout)
            self.assertEqual(dec["selected_driver"], "nvidia_open")
            self.assertFalse(dec["dkms_runtime_invoked"])
            modconf = (r / "run/modprobe.d/10-anitails-gpu.conf").read_text(encoding="utf-8")
            self.assertIn("options nvidia_drm modeset=1 fbdev=1", modconf)
            self.assertIn("NVreg_PreserveVideoMemoryAllocations=0", modconf)
            self.assertIn("NVreg_TemporaryFilePath=/run/anitails-nvidia-ram", modconf)

        # 2. Pascal GTX 1080 (10de:1b80) booted on THAT SAME `nvidia-modern` rootfs ->
        #    MUST NOT blacklist nouveau! Must block nvidia* and route GLVND/Vulkan to Mesa/NVK!
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:01:00.0", "10de", "1b80")
            _install_mock_nvidia_stack(r, mod_ver="615.78.08", userspace_ver="615.78.08", gsp_ver="615.78.08")
            proc = subprocess.run(
                ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", cmdline, "--uname-r", "7.3.3-anitails1"],
                capture_output=True, text=True, check=True,
            )
            dec = json.loads(proc.stdout)
            self.assertEqual(dec["selected_driver"], "nouveau_mesa")
            self.assertTrue(dec["block_nvidia_modules"])
            self.assertFalse(dec["block_nouveau_module"])
            modconf = (r / "run/modprobe.d/10-anitails-gpu.conf").read_text(encoding="utf-8")
            self.assertNotIn("blacklist nouveau", modconf)
            self.assertIn("blacklist nvidia", modconf)
            env_txt = (r / "run/anitails/gpu.env").read_text(encoding="utf-8")
            self.assertIn("__GLX_VENDOR_LIBRARY_NAME=mesa", env_txt)
            self.assertIn("nouveau_icd.x86_64.json", env_txt)

        # 3. Blackwell RTX 5090 on Base Open-Source ISO (no nvidia.ko) -> clean simpledrm + llvmpipe fallback
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:01:00.0", "10de", "2b85")
            proc = subprocess.run(
                ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", cmdline, "--uname-r", "7.3.3-anitails1"],
                capture_output=True, text=True, check=True,
            )
            dec = json.loads(proc.stdout)
            self.assertEqual(dec["selected_driver"], "simpledrm_llvmpipe")
            self.assertTrue(dec["force_software_gl"])

        # 4. Vera Rubin GR100 (10de:3041): 615.78.08 -> simpledrm fallback; 620.70.06 -> nvidia_open!
        for drv_ver, expected in [("615.78.08", "simpledrm_llvmpipe"), ("620.70.06", "nvidia_open")]:
            with tempfile.TemporaryDirectory() as td:
                r = Path(td)
                _add_pci_dev(r, "0000:01:00.0", "10de", "3041", "10de", "221a", pci_class="0x030000")
                _install_mock_nvidia_stack(r, mod_ver=drv_ver, userspace_ver=drv_ver, gsp_ver=drv_ver)
                proc = subprocess.run(
                    ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", cmdline, "--uname-r", "7.3.3-anitails1"],
                    capture_output=True, text=True, check=True,
                )
                dec = json.loads(proc.stdout)
                self.assertEqual(dec["selected_driver"], expected)

    def test_negative_controls_unsigned_module_vermagic_abi_and_missing_gsp_rejected(self) -> None:
        cmdline = "lockdown=integrity module.sig_enforce=1 init_on_free=1"

        # Negative Control A: Unsigned nvidia.ko under module.sig_enforce=1 MUST BE REJECTED!
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:01:00.0", "10de", "2684")  # RTX 4090
            _install_mock_nvidia_stack(r, signed=False)
            proc = subprocess.run(
                ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", cmdline, "--uname-r", "7.3.3-anitails1"],
                capture_output=True, text=True, check=True,
            )
            dec = json.loads(proc.stdout)
            self.assertEqual(dec["selected_driver"], "nouveau_mesa")
            self.assertTrue(dec["block_nvidia_modules"])

        # Negative Control B: Kernel vermagic mismatch (7.2.14.arch1-1 module on 7.3.3-anitails1) MUST BE REJECTED!
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:01:00.0", "10de", "2684")
            _install_mock_nvidia_stack(r, vermagic_kern="7.2.14-arch1-1", signed=True)
            proc = subprocess.run(
                ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", cmdline, "--uname-r", "7.3.3-anitails1"],
                capture_output=True, text=True, check=True,
            )
            dec = json.loads(proc.stdout)
            self.assertEqual(dec["selected_driver"], "nouveau_mesa")
            self.assertFalse(dec["nvidia_stack_check"]["lockstep_valid"])

        # Negative Control C: Userspace ABI skew (615.78.08 kmod vs 620.70.06 libGLX_nvidia) MUST BE REJECTED!
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:01:00.0", "10de", "2684")
            _install_mock_nvidia_stack(r, mod_ver="615.78.08", userspace_ver="620.70.06", signed=True)
            proc = subprocess.run(
                ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", cmdline, "--uname-r", "7.3.3-anitails1"],
                capture_output=True, text=True, check=True,
            )
            dec = json.loads(proc.stdout)
            self.assertEqual(dec["selected_driver"], "nouveau_mesa")

        # Negative Control D: Missing GSP firmware MUST BE REJECTED!
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:01:00.0", "10de", "2684")
            _install_mock_nvidia_stack(r, gsp_ver=None, signed=True)
            proc = subprocess.run(
                ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", cmdline, "--uname-r", "7.3.3-anitails1"],
                capture_output=True, text=True, check=True,
            )
            dec = json.loads(proc.stdout)
            self.assertEqual(dec["selected_driver"], "nouveau_mesa")

    def test_optimus_external_hdmi_headless_3d_virtual_gpu_and_egpu_iommu_gate(self) -> None:
        # 1. Hybrid Intel + NVIDIA Optimus laptop with external HDMI wired to NVIDIA dGPU
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:00:02.0", "8086", "a7a0", boot_vga="1", bound_driver="i915", connectors={"eDP-1": "connected"})
            _add_pci_dev(r, "0000:01:00.0", "10de", "2860", boot_vga="0", pci_class="0x030200", connectors={"HDMI-A-1": "connected"})
            _install_mock_nvidia_stack(r)
            # Auto mode -> PRIME offload enabled + external HDMI warning present
            p_auto = subprocess.run(
                ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", "module.sig_enforce=1", "--uname-r", "7.3.3-anitails1"],
                capture_output=True, text=True, check=True,
            )
            d_auto = json.loads(p_auto.stdout)
            self.assertEqual(d_auto["topology"], "hybrid_optimus_prime")
            self.assertTrue(d_auto["enable_prime_offload"])
            self.assertTrue(any("HDMI/DP" in w for w in d_auto["warnings"]))

            # `anitails.gpu=igpu` -> blocks dGPU completely!
            p_igpu = subprocess.run(
                ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", "anitails.gpu=igpu module.sig_enforce=1", "--uname-r", "7.3.3-anitails1"],
                capture_output=True, text=True, check=True,
            )
            d_igpu = json.loads(p_igpu.stdout)
            self.assertEqual(d_igpu["selected_driver"], "igpu_only_dgpu_blocked")
            self.assertTrue(d_igpu["block_nvidia_modules"])
            self.assertTrue(d_igpu["block_nouveau_module"])

        # 2. Thunderbolt eGPU WITHOUT IOMMU -> MUST REFUSE thunderbolt even with `anitails.egpu=1`!
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:00:02.0", "8086", "a7a0", iommu=False)
            _add_pci_dev(r, "0000:40:00.0", "10de", "2684", egpu_tb=True, iommu=False)
            p_no_iommu = subprocess.run(
                ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", "anitails.egpu=1 module.sig_enforce=1", "--uname-r", "7.3.3-anitails1"],
                capture_output=True, text=True, check=True,
            )
            d_no_iommu = json.loads(p_no_iommu.stdout)
            self.assertFalse(d_no_iommu["allow_egpu_thunderbolt"])

        # 3. Thunderbolt eGPU WITH active IOMMU + `anitails.egpu=1` -> allowed
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:00:02.0", "8086", "a7a0", iommu=True)
            _add_pci_dev(r, "0000:40:00.0", "10de", "2684", egpu_tb=True, iommu=True)
            p_iommu = subprocess.run(
                ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", "anitails.egpu=1 module.sig_enforce=1", "--uname-r", "7.3.3-anitails1"],
                capture_output=True, text=True, check=True,
            )
            d_iommu = json.loads(p_iommu.stdout)
            self.assertTrue(d_iommu["allow_egpu_thunderbolt"])

        # 4. QEMU Virtual GPU (1af4:1050 Virtio-GPU) -> flagged virtual, NEVER treated as NVIDIA test!
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:00:02.0", "1af4", "1050", sub_vendor="1af4", sub_device="1100")
            p_virt = subprocess.run(
                ["python3", str(DETECT_BIN), "--sysfs-root", str(r), "--db", str(DB_PATH)],
                capture_output=True, text=True, check=True,
            )
            rep_virt = json.loads(p_virt.stdout)
            self.assertEqual(rep_virt["topology"], "virtual_gpu_only")
            self.assertTrue(rep_virt["gpus"][0]["is_virtual_gpu"])
            self.assertEqual(rep_virt["nvidia_gpu_count"], 0)

    def test_optional_cuda_compute_capability_validation_and_offline_mode(self) -> None:
        # RTX 4090 (SM 8.9) + CUDA 13.4.3 + driver 615.78.08 -> PASS (exit 0)
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:01:00.0", "10de", "2684")
            ok = subprocess.run(
                ["python3", str(CUDA_BIN), "--root", str(r), "--db", str(DB_PATH), "--cuda-version", "13.4.3", "--driver-version", "615.78.08"],
                capture_output=True, text=True,
            )
            self.assertEqual(ok.returncode, 0, ok.stdout)
            self.assertTrue(json.loads(ok.stdout)["compatible"])

        # Pascal GTX 1080 (SM 6.1), Maxwell GTX 970 (SM 5.2), Volta V100 (SM 7.0) + CUDA 13.4.3 -> MUST FAIL (exit 2)!
        for dev_id in ("1b80", "13c2", "1db6", "1287"):
            with tempfile.TemporaryDirectory() as td:
                r = Path(td)
                _add_pci_dev(r, "0000:01:00.0", "10de", dev_id)
                bad = subprocess.run(
                    ["python3", str(CUDA_BIN), "--root", str(r), "--db", str(DB_PATH), "--cuda-version", "13.4.3", "--driver-version", "580.196.07"],
                    capture_output=True, text=True,
                )
                self.assertEqual(bad.returncode, 2, f"CUDA 13.4 must reject pre-Turing 10de:{dev_id}!")
                self.assertFalse(json.loads(bad.stdout)["compatible"])

        # Offline mode (`anitails.offline=1`) works identically with zero network or DKMS
        with tempfile.TemporaryDirectory() as td:
            r = Path(td)
            _add_pci_dev(r, "0000:01:00.0", "10de", "2204")
            _install_mock_nvidia_stack(r)
            p_off = subprocess.run(
                ["python3", str(SELECT_BIN), "--root", str(r), "--db", str(DB_PATH), "--cmdline", "anitails.offline=1 module.sig_enforce=1", "--uname-r", "7.3.3-anitails1"],
                capture_output=True, text=True, check=True,
            )
            dec_off = json.loads(p_off.stdout)
            self.assertTrue(dec_off["boot_options"]["offline"])
            self.assertFalse(dec_off["dkms_runtime_invoked"])
            self.assertFalse(dec_off["network_invoked"])
            self.assertEqual(dec_off["selected_driver"], "nvidia_open")

    def test_privacy_redaction_tor_browser_isolation_and_vram_amnesia_invariants(self) -> None:
        # 1. Verify UUID, MIG UUID, Serial Number, and MAC redaction
        import importlib.machinery, importlib.util
        loader = importlib.machinery.SourceFileLoader("det", str(DETECT_BIN))
        spec = importlib.util.spec_from_loader("det", loader)
        assert spec and spec.loader
        det = importlib.util.module_from_spec(spec)
        loader.exec_module(det)

        sample = (
            "GPU UUID: GPU-12345678-9abc-def0-1234-56789abcdef0, "
            "MIG-abcdef01-2345-6789-abcd-ef0123456789, "
            "Serial Number: 1324523009988, MAC 52:54:00:ab:cd:ef"
        )
        scrubbed = det.redact_sensitive(sample)
        self.assertNotIn("12345678-9abc", scrubbed)
        self.assertNotIn("1324523009988", scrubbed)
        self.assertNotIn("52:54:00:ab:cd:ef", scrubbed)
        self.assertIn("GPU-[REDACTED-UUID]", scrubbed)
        self.assertIn("[REDACTED-SERIAL]", scrubbed)
        self.assertIn("[REDACTED-MAC]", scrubbed)

        # 2. Verify Tor Browser prefs & bwrap launcher do NOT leak host GPU / /dev/nvidia*
        prefs = (REPO_ROOT / "archiso/airootfs/usr/share/anitails/tor-browser-prefs.js").read_text(encoding="utf-8")
        self.assertNotIn("webgl.force-enabled", prefs)
        self.assertNotIn("webgl.disabled\", false", prefs)
        tbb_sh = (REPO_ROOT / "archiso/airootfs/usr/local/bin/anitails-tor-browser").read_text(encoding="utf-8")
        self.assertIn("--dev /dev", tbb_sh)
        self.assertNotIn("--dev-bind /dev/nvidia", tbb_sh)
        self.assertNotIn("--dev-bind /dev/dri", tbb_sh)

        # 3. Verify NVIDIA daemon/VRAM-dump units are masked & shutdown wipe cleans NVIDIA RAM scratch
        for unit in [
            "nvidia-persistenced.service",
            "nvidia-suspend.service",
            "nvidia-hibernate.service",
            "nvidia-resume.service",
        ]:
            p = REPO_ROOT / "archiso/airootfs/etc/systemd/system" / unit
            self.assertTrue(p.is_symlink() and str(p.readlink()) == "/dev/null", f"{unit} must be masked!")

        wipe_sh = (REPO_ROOT / "archiso/airootfs/usr/local/lib/anitails-shutdown-ram-wipe").read_text(encoding="utf-8")
        self.assertIn("/run/anitails-nvidia-ram", wipe_sh)
        self.assertIn("/sys/bus/pci/drivers/nvidia/unbind", wipe_sh)


if __name__ == "__main__":
    unittest.main()
