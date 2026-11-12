#!/usr/bin/env python3
"""
Test Suite 5: Opt-in LUKS2 + Argon2id Persistent Storage (`anitails-persistence`)
Verifies untrusted partition rejection (`features/untrusted_partitions.feature`),
cryptsetup LUKS2 Argon2id parameters, and anti-symlink-traversal mount validation.
"""

from __future__ import annotations

import importlib.machinery
import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PERSIST_PATH = REPO_ROOT / "archiso/airootfs/usr/local/bin/anitails-persistence"


def load_persistence_module():
    loader = importlib.machinery.SourceFileLoader("anitails_persistence", str(PERSIST_PATH))
    spec = importlib.util.spec_from_loader("anitails_persistence", loader)
    assert spec is not None
    mod = importlib.util.module_from_spec(spec)
    sys.modules["anitails_persistence"] = mod
    loader.exec_module(mod)
    return mod


class TestPersistenceLuks2(unittest.TestCase):
    def setUp(self) -> None:
        self.mod = load_persistence_module()

    def test_untrusted_internal_and_foreign_usb_partitions_rejected(self) -> None:
        # 1. Reject internal SATA/NVMe drive (`removable=False`) even if labeled AniTailsData
        internal_spoof = self.mod.BlockCandidate(
            part_dev="/dev/nvme0n1p3",
            parent_disk="nvme0n1",
            label="AniTailsData",
            removable=False,
        )
        with self.assertRaises(PermissionError):
            self.mod.validate_candidate_partition(internal_spoof, boot_parent_disk="sdb")

        # 2. Reject rogue secondary removable USB (`sdc2` != boot disk `sdb`)
        rogue_usb = self.mod.BlockCandidate(
            part_dev="/dev/sdc2",
            parent_disk="sdc",
            label="AniTailsData",
            removable=True,
        )
        with self.assertRaises(PermissionError):
            self.mod.validate_candidate_partition(rogue_usb, boot_parent_disk="sdb")

        # 3. Accept legitimate partition #2 on the removable live boot USB `sdb`
        legit = self.mod.BlockCandidate(
            part_dev="/dev/sdb2",
            parent_disk="sdb",
            label="AniTailsData",
            removable=True,
        )
        self.mod.validate_candidate_partition(legit, boot_parent_disk="sdb")

    def test_luks2_argon2id_cipher_parameters(self) -> None:
        cmd = self.mod.build_luks2_format_cmd("/dev/sdb2")
        joined = " ".join(cmd)
        self.assertIn("--type luks2", joined)
        self.assertIn("--pbkdf argon2id", joined)
        self.assertIn("--cipher aes-xts-plain64", joined)
        self.assertIn("--key-size 512", joined)
        self.assertIn("--hash sha512", joined)

    def test_persistence_conf_allowlist_and_symlink_traversal_rejection(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            mnt = tmp / "mnt"
            dest_root = tmp / "rootfs"
            (mnt / "Persistent").mkdir(parents=True)
            (mnt / "gnupg").mkdir(parents=True)
            (dest_root / "home/amnesia/Persistent").mkdir(parents=True)
            (dest_root / "home/amnesia/.gnupg").mkdir(parents=True)

            # Valid allowlisted bindings succeed
            bindings = self.mod.parse_persistence_conf(
                [
                    "# Valid AniTails persistence config",
                    "/home/amnesia/Persistent source=Persistent",
                    "/home/amnesia/.gnupg source=gnupg",
                ],
                mount_root=mnt,
                dest_root=dest_root,
            )
            self.assertEqual(len(bindings), 2)

            # Reject arbitrary root target (/etc/sudoers.d)
            with self.assertRaises(PermissionError):
                self.mod.parse_persistence_conf(
                    ["/etc/sudoers.d source=Persistent"],
                    mount_root=mnt,
                    dest_root=dest_root,
                )

            # Reject '..' path traversal
            with self.assertRaises(PermissionError):
                self.mod.parse_persistence_conf(
                    ["/home/amnesia/../root source=Persistent"],
                    mount_root=mnt,
                    dest_root=dest_root,
                )

            # Reject symlink inside persistent volume attempting host escape!
            (mnt / "electrum").symlink_to("/etc")
            (dest_root / "home/amnesia/.electrum").mkdir(parents=True)
            with self.assertRaises(PermissionError):
                self.mod.parse_persistence_conf(
                    ["/home/amnesia/.electrum source=electrum"],
                    mount_root=mnt,
                    dest_root=dest_root,
                )


if __name__ == "__main__":
    unittest.main()
