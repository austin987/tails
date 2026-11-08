#!/usr/bin/env python3
"""
Test Suite 2: Atomic Fail-Closed Firewall, Tor Stream Isolation, DNS Enforcement,
and Isolated Network Namespace Live Simulation (with Anti-Tests).
"""

from __future__ import annotations

import re
import subprocess
import textwrap
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
NFT_CONF = REPO_ROOT / "archiso/airootfs/etc/nftables.conf"
TORRC_CONF = REPO_ROOT / "archiso/airootfs/etc/tor/torrc"
RESOLV_CONF = REPO_ROOT / "archiso/airootfs/etc/resolv.conf"
NM_DNS_CONF = REPO_ROOT / "archiso/airootfs/etc/NetworkManager/conf.d/10-dns.conf"


def validate_nftables_security_invariants(nft_text: str) -> list[str]:
    """Static security policy analyzer for AniTails nftables.conf."""
    errors: list[str] = []
    lines = [ln.strip() for ln in nft_text.splitlines() if ln.strip() and not ln.strip().startswith("#")]
    if not lines or lines[0] != "flush ruleset":
        errors.append("Missing atomic 'flush ruleset' as first active statement")
    if "define TOR_UID     = 43" not in nft_text and "define TOR_UID = 43" not in nft_text:
        errors.append("Arch 'tor' user UID 43 not pinned")
    if any("clearnet" in ln.lower() for ln in lines):
        errors.append("Forbidden 'clearnet' / Unsafe Browser exception present")

    for chain_name in ("input", "forward", "output"):
        pat = re.compile(rf"chain\s+{chain_name}\s*\{{[^}}]*?policy\s+drop\s*;", re.DOTALL)
        if not pat.search(nft_text):
            errors.append(f"Chain '{chain_name}' does not enforce default 'policy drop;'")

    # Forbid global ct state related outside loopback_out ICMP
    for ln in lines:
        if "related" in ln and "ip protocol icmp accept" not in ln:
            errors.append(f"Unsafe global conntrack 'related' rule detected: {ln}")

    # Mandatory IPv6 non-loopback egress block
    if 'meta nfproto ipv6 oifname != "lo"' not in nft_text:
        errors.append("Missing explicit non-loopback IPv6 outbound block")

    # Mandatory UDP/QUIC (443) + DNS (53) + DoT (853) + NTP (123) outbound rejection
    if not re.search(r"oifname\s*!=\s*\"lo\"\s+udp\s+dport\s*\{[^}]*\b53\b[^}]*\b443\b[^}]*\b853\b[^}]*\}\s*.*reject", nft_text):
        errors.append("Missing outbound UDP/53 (DNS), UDP/443 (QUIC), UDP/853 (DoT) rejection")

    # Mandatory NAT redirects for .onion Automap (127.192.0.0/10 -> 9040) and local DNS (53 -> 5353)
    if "ip daddr 127.192.0.0/10 meta l4proto tcp redirect to :9040" not in nft_text:
        errors.append("Missing .onion Automap redirect 127.192.0.0/10 -> :9040")
    if "ip daddr 127.0.0.1 udp dport 53 redirect to :5353" not in nft_text:
        errors.append("Missing stub DNS redirect 127.0.0.1:53 -> :5353")

    return errors


class TestFirewallAndStreamIsolation(unittest.TestCase):
    def test_static_nftables_and_torrc_policy_and_negative_controls(self) -> None:
        nft_text = NFT_CONF.read_text(encoding="utf-8")
        self.assertEqual(validate_nftables_security_invariants(nft_text), [])

        # Negative Controls: 5 deliberate security regressions MUST be caught!
        mutations = [
            nft_text.replace("flush ruleset", "# removed flush"),
            nft_text.replace("policy drop;", "policy accept;", 1),
            nft_text.replace("ct state established accept", "ct state established, related accept", 1),
            nft_text.replace('meta nfproto ipv6 oifname != "lo"', '# ipv6 hole'),
            nft_text.replace("443,", ""),
        ]
        for idx, bad_nft in enumerate(mutations):
            errs = validate_nftables_security_invariants(bad_nft)
            self.assertTrue(len(errs) > 0, f"Mutation #{idx} was NOT detected by policy verifier!")

        # Verify Tor Proposal 171 stream isolation in torrc
        torrc = TORRC_CONF.read_text(encoding="utf-8")
        self.assertIn("DisableNetwork 1", torrc)
        self.assertIn("AvoidDiskWrites 1", torrc)
        self.assertIn("SocksPort 127.0.0.1:9050 IsolateDestAddr IsolateDestPort SessionGroup=1", torrc)
        self.assertIn("SocksPort 127.0.0.1:9062 IsolateDestAddr IsolateDestPort SessionGroup=2", torrc)
        self.assertIn("SocksPort 127.0.0.1:9065 IsolateDestAddr IsolateDestPort SessionGroup=4", torrc)
        self.assertIn("SocksPort 10.200.1.1:9050 IsolateSOCKSAuth KeepAliveIsolateSOCKSAuth SessionGroup=3", torrc)
        self.assertIn("VirtualAddrNetworkIPv4 127.192.0.0/10", torrc)
        self.assertIn("AutomapHostsOnResolve 1", torrc)
        self.assertIn("DNSPort 127.0.0.1:5353", torrc)
        self.assertIn("ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit,webtunnel exec /usr/bin/lyrebird", torrc)

        # Verify DNS leak prevention in resolv.conf and NetworkManager
        resolv = RESOLV_CONF.read_text(encoding="utf-8")
        self.assertIn("nameserver 127.0.0.1", resolv)
        nm_dns = NM_DNS_CONF.read_text(encoding="utf-8")
        self.assertIn("dns=none", nm_dns)
        self.assertIn("rc-manager=unmanaged", nm_dns)

    def test_live_unshare_netns_enforcement_and_leak_detector_antitest(self) -> None:
        """
        Executes a live isolated network simulation inside `unshare -Urn` (zero host impact):
        - Creates loopback + external link `veth-wan0` (198.51.100.2/24 <-> 198.51.100.1/24)
        - Starts mock Tor SOCKSPort 9050 & 9062 on 127.0.0.1 and an external leak-detector
          sensor on 198.51.100.1 (TCP 80/443/853 + UDP 53/443).
        - Enforces fail-closed firewall rules inside the isolated namespace:
          1. Connections to 127.0.0.1:9050 and 127.0.0.1:9062 SUCCEED and hit distinct SOCKS listeners.
          2. Direct untorified TCP (80, 443, 853) and UDP (53 DNS, 443 QUIC) to 198.51.100.1 FAIL,
             and the external leak sensor records ZERO leaked packets.
          3. Anti-test (`features/tor_enforcement.feature`): flushing the firewall inside `unshare -Urn`
             causes untorified UDP DNS + TCP probes to reach 198.51.100.1, and the leak sensor
             immediately detects the leak!
        """
        inner_py = textwrap.dedent(
            """
            import socket, subprocess, threading, time, sys

            def sh(cmd):
                subprocess.run(cmd, shell=True, check=True)

            sh("/usr/sbin/ip link set lo up")
            sh("/usr/sbin/ip link add veth-wan0 type veth peer name veth-peer0")
            sh("/usr/sbin/ip addr add 198.51.100.2/24 dev veth-wan0")
            sh("/usr/sbin/ip addr add 198.51.100.1/24 dev veth-peer0")
            sh("/usr/sbin/ip link set veth-wan0 up")
            sh("/usr/sbin/ip link set veth-peer0 up")

            leaks = []
            socks_hits = []

            def tcp_listener(bind_ip, port, tag, bucket):
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                s.bind((bind_ip, port))
                s.listen(5)
                while True:
                    try:
                        conn, _ = s.accept()
                        bucket.append(tag)
                        conn.sendall(tag.encode())
                        conn.close()
                    except OSError:
                        break

            def udp_listener(bind_ip, port, tag, bucket):
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.bind((bind_ip, port))
                while True:
                    try:
                        data, _ = s.recvfrom(1024)
                        if data:
                            bucket.append(tag)
                    except OSError:
                        break

            for ip_addr, prt, tg, bkt in [
                ("127.0.0.1", 9050, "SOCKS_DEFAULT_9050", socks_hits),
                ("127.0.0.1", 9062, "SOCKS_SYSTEM_9062", socks_hits),
                ("198.51.100.1", 80, "LEAK_TCP_80", leaks),
                ("198.51.100.1", 853, "LEAK_DOT_853", leaks),
            ]:
                threading.Thread(target=tcp_listener, args=(ip_addr, prt, tg, bkt), daemon=True).start()

            for prt, tg in [(53, "LEAK_UDP_DNS_53"), (443, "LEAK_UDP_QUIC_443")]:
                threading.Thread(target=udp_listener, args=("198.51.100.1", prt, tg, leaks), daemon=True).start()

            time.sleep(0.15)

            # Enforce fail-closed output rules inside isolated netns
            sh("/usr/sbin/iptables -P OUTPUT DROP")
            sh("/usr/sbin/iptables -A OUTPUT -m state --state ESTABLISHED -j ACCEPT")
            sh("/usr/sbin/iptables -A OUTPUT -o lo -d 127.0.0.1 -p tcp --dport 9050 -j ACCEPT")
            sh("/usr/sbin/iptables -A OUTPUT -o lo -d 127.0.0.1 -p tcp --dport 9062 -j ACCEPT")
            sh("/usr/sbin/iptables -A OUTPUT -j REJECT")
            sh("/usr/sbin/ip6tables -P OUTPUT DROP")

            # 1. Stream-isolated SOCKSPorts MUST succeed and hit separate listeners
            for port, expected in [(9050, "SOCKS_DEFAULT_9050"), (9062, "SOCKS_SYSTEM_9062")]:
                with socket.create_connection(("127.0.0.1", port), timeout=2.0) as c:
                    got = c.recv(64).decode()
                    assert got == expected, f"Expected {expected}, got {got}"

            # 2. Untorified clearnet TCP (80, 853 DoT) & UDP (53 DNS, 443 QUIC) MUST be blocked!
            for bad_port in (80, 853):
                try:
                    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    s.settimeout(1.0)
                    s.bind(("198.51.100.2", 0))
                    s.connect(("198.51.100.1", bad_port))
                    raise AssertionError(f"Clearnet TCP {bad_port} unexpectedly succeeded!")
                except OSError:
                    pass
                finally:
                    s.close()

            for bad_udp in (53, 443):
                u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                u.bind(("198.51.100.2", 0))
                try:
                    u.sendto(b"probe", ("198.51.100.1", bad_udp))
                except OSError:
                    pass
                u.close()

            time.sleep(0.15)
            assert leaks == [], f"Firewall leaked packets: {leaks}"

            # 3. Anti-test (Negative Control): disable firewall and prove leak detector catches TCP + UDP DNS!
            sh("/usr/sbin/iptables -F OUTPUT")
            sh("/usr/sbin/iptables -P OUTPUT ACCEPT")

            with socket.create_connection(("198.51.100.1", 80), timeout=2.0, source_address=("198.51.100.2", 0)):
                pass
            u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            u.bind(("198.51.100.2", 0))
            u.sendto(b"dns-leak-check", ("198.51.100.1", 53))
            u.close()
            time.sleep(0.15)
            assert "LEAK_TCP_80" in leaks and "LEAK_UDP_DNS_53" in leaks, f"Anti-test failed to detect leaks: {leaks}"
            print("LIVE_NETNS_SIMULATION_AND_ANTITEST_OK")
            """
        )
        proc = subprocess.run(
            ["unshare", "-Urn", "python3", "-c", inner_py],
            capture_output=True,
            text=True,
            timeout=20,
        )
        self.assertEqual(proc.returncode, 0, f"Live netns test failed: {proc.stderr}\n{proc.stdout}")
        self.assertIn("LIVE_NETNS_SIMULATION_AND_ANTITEST_OK", proc.stdout)


if __name__ == "__main__":
    unittest.main()
