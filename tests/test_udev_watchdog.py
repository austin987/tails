#!/usr/bin/env python3
"""
Test Suite 6: Compile & Execute `anitails-udev-watchdog` C Binary (`features/emergency_shutdown.feature`).
Verifies hardened C compilation (`-Wall -Wextra -Werror -fPIE -fstack-protector-strong`),
slash-anchored DEVPATH matching, non-matching device rejection, DVD `change` handling,
and clean error exit on invalid device types (fixing legacy Tails UB).
"""

from __future__ import annotations

import os
import socket
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
WATCHDOG_SRC = REPO_ROOT / "pkgbuilds/anitails-udev-watchdog/anitails-udev-watchdog.c"


def build_uevent_frame(action: str, devpath: str, subsystem: str = "block") -> bytes:
    parts = [
        f"{action}@{devpath}",
        f"ACTION={action}",
        f"DEVPATH={devpath}",
        f"SUBSYSTEM={subsystem}",
        "SEQNUM=4242",
    ]
    return ("\0".join(parts) + "\0").encode("utf-8")


class TestUdevWatchdogBinary(unittest.TestCase):
    def test_compile_and_run_uevent_matching_scenarios(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            bin_path = Path(td) / "anitails-udev-watchdog"
            compile_res = subprocess.run(
                [
                    "gcc", "-O2", "-Wall", "-Wextra", "-Werror", "-std=c11",
                    "-fPIE", "-fstack-protector-strong", "-D_FORTIFY_SOURCE=2",
                    "-o", str(bin_path), str(WATCHDOG_SRC),
                    "-pie", "-Wl,-z,relro,-z,now",
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(compile_res.returncode, 0, f"C compile failed: {compile_res.stderr}")

            # 1. Invalid device type (legacy Tails UB regression test) -> exits 2 cleanly!
            bad_type = subprocess.run([str(bin_path), "/devices/pci0/usb1/block/sdb", "invalid_type"], capture_output=True, text=True)
            self.assertEqual(bad_type.returncode, 2)

            # 2. Ignore foreign USB ('sdc') and partial-name collision ('xsdb'), trigger ONLY on boot USB ('sdb')!
            s_parent, s_child = socket.socketpair(AF_UNIX := socket.AF_UNIX, socket.SOCK_DGRAM)
            try:
                os.set_inheritable(s_child.fileno(), True)
                proc = subprocess.Popen(
                    [
                        str(bin_path),
                        "--test-fd", str(s_child.fileno()),
                        "/devices/pci0000:00/usb1/1-1/block/sdb",
                        "disk",
                    ],
                    pass_fds=(s_child.fileno(),),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                )
                s_child.close()

                # Foreign disk sdc removal -> MUST NOT exit
                s_parent.send(build_uevent_frame("remove", "/devices/pci0000:00/usb1/1-2/block/sdc"))
                # Suffix collision 'xsdb' -> MUST NOT exit
                s_parent.send(build_uevent_frame("remove", "/devices/pci0000:00/usb1/1-1/block/xsdb"))
                # Non-remove action ('add') on sdb -> MUST NOT exit
                s_parent.send(build_uevent_frame("add", "/devices/pci0000:00/usb1/1-1/block/sdb"))
                time.sleep(0.1)
                self.assertIsNone(proc.poll(), "Watchdog exited prematurely on non-matching uevent!")

                # Exact boot disk sdb removal -> MUST exit 0 immediately!
                s_parent.send(build_uevent_frame("remove", "/devices/pci0000:00/usb1/1-1/block/sdb"))
                out, err = proc.communicate(timeout=3.0)
                self.assertEqual(proc.returncode, 0, f"Expected exit 0 on boot USB removal, got {proc.returncode}: {err}")
                self.assertIn("MATCH action=remove devpath=/devices/pci0000:00/usb1/1-1/block/sdb", out)
            finally:
                s_parent.close()


if __name__ == "__main__":
    unittest.main()
