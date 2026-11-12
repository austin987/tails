#!/usr/bin/env python3
"""
Test Suite 3: Fail-Closed MAC Address Spoofing & Arch `.ko.zst` NIC Driver Blocking
(`features/mac_spoofing.feature`).
Runs the real `anitails-spoof-mac` and `anitails-unblock-network` scripts inside `unshare -Urn`.
"""

from __future__ import annotations

import os
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SPOOF_SCRIPT = REPO_ROOT / "archiso/airootfs/usr/local/lib/anitails-spoof-mac"
UNBLOCK_SCRIPT = REPO_ROOT / "archiso/airootfs/usr/local/lib/anitails-unblock-network"


class TestMacSpoofingFailClosed(unittest.TestCase):
    def test_spoof_success_and_silent_or_explicit_failure_panic_in_unshare(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            panic_dir = tmp / "panic"
            modprobe_dir = tmp / "modprobe.d"
            cmdline = tmp / "cmdline"
            cmdline.write_text("quiet lsm=landlock,lockdown,yama,integrity,apparmor,bpf\n", encoding="utf-8")

            mock_systemctl = tmp / "mock_systemctl"
            systemctl_log = tmp / "systemctl.log"
            mock_systemctl.write_text(
                f"#!/bin/sh\necho \"$@\" >> {systemctl_log}\nexit 0\n",
                encoding="utf-8",
            )
            mock_systemctl.chmod(0o755)

            # 1. Normal MAC spoofing (builtin fallback preserving 3-byte OUI + randomizing NIC bytes)
            sh_ok = textwrap.dedent(
                f"""
                set -e
                /usr/sbin/ip link add eth0 type veth peer name eth0peer
                /usr/sbin/ip link set dev eth0 address 00:11:22:33:44:55
                ANITAILS_PANIC_DIR="{panic_dir}" \\
                ANITAILS_MODPROBE_DIR="{modprobe_dir}" \\
                ANITAILS_CMDLINE_FILE="{cmdline}" \\
                ANITAILS_MACCHANGER_BIN="/nonexistent/macchanger" \\
                ANITAILS_SYSTEMCTL_BIN="{mock_systemctl}" \\
                "{SPOOF_SCRIPT}" eth0
                NEW_MAC=$(/usr/sbin/ip -o link show dev eth0 | awk '{{for(i=1;i<=NF;i++) if($i=="link/ether") print $(i+1)}}')
                echo "SPOOFED_MAC=$NEW_MAC"
                test "$NEW_MAC" != "00:11:22:33:44:55"
                case "$NEW_MAC" in
                    00:11:22:*) ;;
                    *) echo "Unexpected OUI: $NEW_MAC"; exit 1 ;;
                esac
                """
            )
            res_ok = subprocess.run(["unshare", "-Urn", "bash", "-c", sh_ok], capture_output=True, text=True)
            self.assertEqual(res_ok.returncode, 0, f"Normal MAC spoof failed: {res_ok.stderr}")
            self.assertIn("SPOOFED_MAC=00:11:22:", res_ok.stdout)

            # 2. Silent Broken `macchanger` (returns exit 0 WITHOUT changing MAC -> MUST trigger fail-closed panic!)
            silent_broken_mc = tmp / "silent_broken_macchanger"
            silent_broken_mc.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            silent_broken_mc.chmod(0o755)

            sh_silent_fail = textwrap.dedent(
                f"""
                set -e
                /usr/sbin/ip link add eth0 type veth peer name eth0peer
                /usr/sbin/ip link set dev eth0 address 00:11:22:33:44:55
                /usr/sbin/ip link set dev eth0 up
                set +e
                ANITAILS_PANIC_DIR="{panic_dir}" \\
                ANITAILS_MODPROBE_DIR="{modprobe_dir}" \\
                ANITAILS_CMDLINE_FILE="{cmdline}" \\
                ANITAILS_MACCHANGER_BIN="{silent_broken_mc}" \\
                ANITAILS_SYSTEMCTL_BIN="{mock_systemctl}" \\
                "{SPOOF_SCRIPT}" eth0
                RC=$?
                set -e
                test "$RC" -ne 0
                # Verify eth0 was forced DOWN (no UP flag inside <...>)!
                LINK_INFO=$(/usr/sbin/ip -o link show dev eth0)
                case "$LINK_INFO" in
                    *"<"*",UP"*|*"<UP"*) echo "NIC still UP: $LINK_INFO"; exit 1 ;;
                esac
                """
            )
            res_silent = subprocess.run(["unshare", "-Urn", "bash", "-c", sh_silent_fail], capture_output=True, text=True)
            self.assertEqual(res_silent.returncode, 0, f"Silent macchanger failure did not fail-closed: {res_silent.stderr}")
            self.assertTrue((panic_dir / "lockdown.state").exists(), "Expected total NetworkManager lockdown when NIC persists")
            self.assertIn("mask NetworkManager.service", systemctl_log.read_text(encoding="utf-8"))

            # 3. Explicit Failing `macchanger` (returns exit 1 -> MUST also fail-closed!)
            explicit_fail_mc = tmp / "explicit_fail_macchanger"
            explicit_fail_mc.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
            explicit_fail_mc.chmod(0o755)
            panic_dir2 = tmp / "panic2"

            sh_explicit_fail = textwrap.dedent(
                f"""
                /usr/sbin/ip link add eth0 type veth peer name eth0peer
                /usr/sbin/ip link set dev eth0 address 00:11:22:33:44:55
                ANITAILS_PANIC_DIR="{panic_dir2}" \\
                ANITAILS_MODPROBE_DIR="{modprobe_dir}" \\
                ANITAILS_CMDLINE_FILE="{cmdline}" \\
                ANITAILS_MACCHANGER_BIN="{explicit_fail_mc}" \\
                ANITAILS_SYSTEMCTL_BIN="{mock_systemctl}" \\
                "{SPOOF_SCRIPT}" eth0
                """
            )
            res_explicit = subprocess.run(["unshare", "-Urn", "bash", "-c", sh_explicit_fail], capture_output=True, text=True)
            self.assertNotEqual(res_explicit.returncode, 0)
            self.assertTrue((panic_dir2 / "lockdown.state").exists())

    def test_arch_ko_zst_nic_blacklist_generation(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            net_dir = tmp / "7.3.3-anitails1/kernel/drivers/net"
            bt_dir = tmp / "7.3.3-anitails1/kernel/drivers/bluetooth"
            net_dir.mkdir(parents=True)
            bt_dir.mkdir(parents=True)
            for mod_file in ["e1000e.ko.zst", "iwlwifi.ko.zst", "r8169.ko", "veth.ko.zst"]:
                (net_dir / mod_file).write_bytes(b"mock")
            (bt_dir / "btusb.ko.zst").write_bytes(b"mock")

            out_conf = tmp / "90-all-net-blacklist.conf"
            env = os.environ.copy()
            env["ANITAILS_MODULES_ROOT"] = str(tmp)
            env["ANITAILS_NET_BLACKLIST"] = str(out_conf)

            res = subprocess.run([str(UNBLOCK_SCRIPT), "generate-blacklist"], env=env, capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, res.stderr)
            content = out_conf.read_text(encoding="utf-8")
            self.assertIn("install e1000e /bin/false", content)
            self.assertIn("install iwlwifi /bin/false", content)
            self.assertIn("install r8169 /bin/false", content)
            self.assertIn("install btusb /bin/false", content)
            self.assertNotIn("veth", content, "veth MUST remain allowed for local netns isolation!")


if __name__ == "__main__":
    unittest.main()
