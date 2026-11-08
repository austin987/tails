#!/usr/bin/env python3
"""
Test Suite 7: Archiso Profile Structure, PKGBUILD Integrity, SBOM/Checksum Tamper
Detection, Verified Full-Image Upgrade Signature Checks, and External Key Policy.
"""

from __future__ import annotations

import re
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


class TestSupplyChainAndArchiso(unittest.TestCase):
    def test_archiso_profile_and_baseline_hardening_invariants(self) -> None:
        # 1. pacman.conf + frozen snapshot check via build-iso.sh --validate-config-only
        res = subprocess.run(
            [str(REPO_ROOT / "scripts/build-iso.sh"), "--validate-config-only"],
            capture_output=True, text=True,
        )
        self.assertEqual(res.returncode, 0, res.stderr)

        # 2. BIOS + UEFI bootmodes and AppArmor + init_on_free=1 + copytoram=n on kernel cmdline
        profiledef = (REPO_ROOT / "archiso/profiledef.sh").read_text(encoding="utf-8")
        self.assertIn("'bios.syslinux'", profiledef)
        self.assertIn("'uefi.systemd-boot'", profiledef)

        for boot_cfg in [
            REPO_ROOT / "archiso/syslinux/syslinux.cfg",
            REPO_ROOT / "archiso/efiboot/loader/entries/01-anitails-x86_64-linux.conf",
        ]:
            txt = boot_cfg.read_text(encoding="utf-8")
            self.assertIn("lsm=landlock,lockdown,yama,integrity,apparmor,bpf", txt)
            self.assertIn("init_on_free=1", txt)
            self.assertIn("page_poison=1", txt)
            self.assertIn("copytoram=n", txt)

        # 3. Default security invariants: swap masked, sshd masked, no NOPASSWD sudo, no Unsafe Browser
        for masked in ["swap.target", "sshd.service", "sshd.socket", "systemd-timesyncd.service"]:
            p = REPO_ROOT / "archiso/airootfs/etc/systemd/system" / masked
            self.assertTrue(p.is_symlink() and str(p.readlink()) == "/dev/null", f"{masked} must be masked to /dev/null")

        sudoers = (REPO_ROOT / "archiso/airootfs/etc/sudoers.d/00-anitails-hardening").read_text(encoding="utf-8")
        active_sudoers = "\n".join(ln for ln in sudoers.splitlines() if not ln.lstrip().startswith("#"))
        self.assertNotIn("NOPASSWD", active_sudoers)
        gdm = (REPO_ROOT / "archiso/airootfs/etc/gdm/custom.conf").read_text(encoding="utf-8")
        self.assertIn("AutomaticLogin=amnesia", gdm)
        self.assertNotIn("AutomaticLogin=root", gdm)
        pkgs = (REPO_ROOT / "archiso/packages.x86_64").read_text(encoding="utf-8")
        self.assertNotIn("unsafe-browser", pkgs)
        self.assertNotIn("synaptic", pkgs)
        self.assertNotIn("pidgin", pkgs)

    def test_all_pkgbuilds_pin_exact_sha256_and_validpgpkeys(self) -> None:
        pkgbuilds = sorted((REPO_ROOT / "pkgbuilds").glob("*/PKGBUILD"))
        self.assertEqual(len(pkgbuilds), 5)
        for pb in pkgbuilds:
            txt = pb.read_text(encoding="utf-8")
            # Extract source=() and sha256sums=() entries
            src_m = re.search(r"source=\((.*?)\)", txt, re.DOTALL)
            sha_m = re.search(r"sha256sums=\((.*?)\)", txt, re.DOTALL)
            self.assertIsNotNone(src_m, f"Missing source=() in {pb}")
            self.assertIsNotNone(sha_m, f"Missing sha256sums=() in {pb}")
            sources = re.findall(r"""['"]([^'"]+)['"]""", src_m.group(1))
            sums = re.findall(r"""['"]([^'"]+)['"]""", sha_m.group(1))
            self.assertEqual(len(sources), len(sums), f"Mismatched source/sha256sums count in {pb}")
            for s_url, digest in zip(sources, sums):
                if s_url.endswith((".asc", ".sign")):
                    self.assertEqual(digest, "SKIP")
                else:
                    self.assertRegex(digest, r"^[0-9a-f]{64}$", f"Non-pinned hash {digest!r} for {s_url} in {pb}")
                    self.assertNotEqual(digest, "0" * 64, f"Zero placeholder hash in {pb}")
            if any(s.startswith("https://") for s in sources):
                self.assertIn("validpgpkeys=(", txt, f"External source without validpgpkeys in {pb}")

    def test_sbom_checksums_signature_tamper_rejection_and_external_key_policy(self) -> None:
        sbom_script = REPO_ROOT / "scripts/generate-sbom-and-checksums.py"
        upgrade_script = REPO_ROOT / "scripts/verify-and-upgrade-usb.py"
        sign_script = REPO_ROOT / "scripts/sign-release.sh"

        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            art_dir = tmp / "artifacts"
            out_dir = tmp / "manifests"
            art_dir.mkdir()
            img = art_dir / "anitails-0.1.0-x86_64.iso"
            img.write_bytes(b"ANITAILS_TEST_ISO_PAYLOAD_" * 1024)

            # 1. Generate SBOM + SHA256SUMS + B2SUMS and verify PASS
            r_gen = subprocess.run(
                ["python3", str(sbom_script), "generate", "--target", str(art_dir), "--out-dir", str(out_dir)],
                capture_output=True, text=True,
            )
            self.assertEqual(r_gen.returncode, 0, r_gen.stderr)

            r_ver = subprocess.run(
                ["python3", str(sbom_script), "verify", "--manifest-dir", str(out_dir)],
                capture_output=True, text=True,
            )
            self.assertEqual(r_ver.returncode, 0, r_ver.stderr)

            # 2. Sign SHA256SUMS with a test RSA-4096 keypair and test `verify-and-upgrade-usb.py`
            priv = tmp / "rel.key"
            pub = tmp / "rel.pub"
            wrong_priv = tmp / "wrong.key"
            wrong_pub = tmp / "wrong.pub"
            for k, p in [(priv, pub), (wrong_priv, wrong_pub)]:
                subprocess.run(["openssl", "genrsa", "-out", str(k), "2048"], check=True, capture_output=True)
                subprocess.run(["openssl", "rsa", "-in", str(k), "-pubout", "-out", str(p)], check=True, capture_output=True)

            sig = out_dir / "SHA256SUMS.sig"
            subprocess.run(
                ["openssl", "dgst", "-sha256", "-sign", str(priv), "-out", str(sig), str(out_dir / "SHA256SUMS")],
                check=True, capture_output=True,
            )

            # Valid signature + untampered image -> PASS
            r_up_ok = subprocess.run(
                [
                    "python3", str(upgrade_script),
                    "--image", str(img),
                    "--sha256sums", str(out_dir / "SHA256SUMS"),
                    "--b2sums", str(out_dir / "B2SUMS"),
                    "--sig", str(sig),
                    "--pubkey", str(pub),
                ],
                capture_output=True, text=True,
            )
            self.assertEqual(r_up_ok.returncode, 0, r_up_ok.stderr)

            # Wrong public key (forged signature negative control) -> MUST FAIL
            r_up_badkey = subprocess.run(
                [
                    "python3", str(upgrade_script),
                    "--image", str(img),
                    "--sha256sums", str(out_dir / "SHA256SUMS"),
                    "--b2sums", str(out_dir / "B2SUMS"),
                    "--sig", str(sig),
                    "--pubkey", str(wrong_pub),
                ],
                capture_output=True, text=True,
            )
            self.assertNotEqual(r_up_badkey.returncode, 0, "Forged/wrong signature MUST be rejected!")

            # Tamper 1 byte in ISO image -> BOTH SBOM verifier and upgrade verifier MUST FAIL!
            data = bytearray(img.read_bytes())
            data[42] ^= 0xFF
            img.write_bytes(bytes(data))

            r_ver_tamper = subprocess.run(
                ["python3", str(sbom_script), "verify", "--manifest-dir", str(out_dir)],
                capture_output=True, text=True,
            )
            self.assertNotEqual(r_ver_tamper.returncode, 0, "Tampered artifact MUST fail checksum verification!")

            r_up_tamper = subprocess.run(
                [
                    "python3", str(upgrade_script),
                    "--image", str(img),
                    "--sha256sums", str(out_dir / "SHA256SUMS"),
                    "--b2sums", str(out_dir / "B2SUMS"),
                    "--sig", str(sig),
                    "--pubkey", str(pub),
                ],
                capture_output=True, text=True,
            )
            self.assertNotEqual(r_up_tamper.returncode, 0, "Tampered image MUST fail upgrade verification!")

            # 3. Official release signing without external key MUST return BLOCKED (exit 77), never fake-sign!
            r_sign_blocked = subprocess.run([str(sign_script), str(out_dir)], capture_output=True, text=True)
            self.assertEqual(r_sign_blocked.returncode, 77)
            self.assertIn("BLOCKED", r_sign_blocked.stderr)


if __name__ == "__main__":
    unittest.main()
