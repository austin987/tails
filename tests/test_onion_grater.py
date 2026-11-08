#!/usr/bin/env python3
"""
Test Suite 4: `anitails-onion-grater` Tor ControlPort Filter Proxy.
Tests live TCP proxy session enforcement, cookie authentication hiding, command
allowlisting, and cross-application STREAM event isolation.
"""

from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import socket
import socketserver
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GRATER_PATH = REPO_ROOT / "archiso/airootfs/usr/local/lib/anitails-onion-grater"


def load_grater_module():
    loader = importlib.machinery.SourceFileLoader("anitails_onion_grater", str(GRATER_PATH))
    spec = importlib.util.spec_from_loader("anitails_onion_grater", loader)
    assert spec is not None
    mod = importlib.util.module_from_spec(spec)
    sys.modules["anitails_onion_grater"] = mod
    loader.exec_module(mod)
    return mod


class MockTorControlServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True


class TestOnionGraterLive(unittest.TestCase):
    def test_tor_browser_profile_blocks_dangerous_commands_and_other_app_streams(self) -> None:
        grater = load_grater_module()
        cookie_bytes = bytes.fromhex("aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899")

        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            cookie_file = tmp / "control.authcookie"
            cookie_file.write_bytes(cookie_bytes)

            prof_dir = tmp / "profiles"
            prof_dir.mkdir()
            # Bind Tor Browser profile rules to 127.0.0.1 for local test socket
            tbb_prof = json.loads((REPO_ROOT / "archiso/airootfs/etc/onion-grater.d/tor-browser.json").read_text(encoding="utf-8"))
            tbb_prof[0]["hosts"] = ["127.0.0.1"]
            (prof_dir / "tor-browser.json").write_text(json.dumps(tbb_prof), encoding="utf-8")

            class MockTorHandler(socketserver.StreamRequestHandler):
                def handle(self) -> None:
                    auth_line = self.rfile.readline().decode("utf-8").strip()
                    if auth_line != f"AUTHENTICATE {cookie_bytes.hex()}":
                        self.wfile.write(b"515 Bad Authentication\r\n")
                        return
                    self.wfile.write(b"250 OK\r\n")
                    while True:
                        raw = self.rfile.readline()
                        if not raw:
                            break
                        cmd = raw.decode("utf-8").strip()
                        if cmd == "SIGNAL NEWNYM":
                            self.wfile.write(b"250 OK\r\n")
                        elif cmd.startswith("GETINFO "):
                            self.wfile.write(b"250-circuit-status=1 BUILT\r\n250 OK\r\n")
                        elif cmd.startswith("GETCONF "):
                            self.wfile.write(b"250 bridge=\r\n")
                        elif cmd.startswith("SETEVENTS"):
                            self.wfile.write(b"250 OK\r\n")
                            # Emit one stream event from another IP (127.0.0.99) and one from client (127.0.0.1)
                            self.wfile.write(b"650 STREAM 10 NEW 0 example.com:443 SOURCE_ADDR=127.0.0.99:40000\r\n")
                            self.wfile.write(b"650 STREAM 11 NEW 0 torproject.org:443 SOURCE_ADDR=127.0.0.1:40001\r\n")
                        elif cmd == "QUIT":
                            self.wfile.write(b"250 closing\r\n")
                            break
                        else:
                            self.wfile.write(b"250 UNEXPECTED_UPSTREAM_REACHED\r\n")

            mock_tor = MockTorControlServer(("127.0.0.1", 0), MockTorHandler)
            tor_port = mock_tor.server_address[1]
            threading.Thread(target=mock_tor.serve_forever, daemon=True).start()

            profiles = grater.load_profiles(prof_dir)
            handler_cls = grater.make_handler(profiles, "127.0.0.1", tor_port, cookie_file)
            proxy_srv = grater.ThreadedTCPServer(("127.0.0.1", 0), handler_cls)
            proxy_port = proxy_srv.server_address[1]
            threading.Thread(target=proxy_srv.serve_forever, daemon=True).start()

            try:
                with socket.create_connection(("127.0.0.1", proxy_port), timeout=5.0) as cli:
                    reader = cli.makefile("r", encoding="utf-8", newline="\n")

                    def send_recv(c: str) -> str:
                        cli.sendall((c + "\r\n").encode("utf-8"))
                        lines = []
                        while True:
                            ln = reader.readline()
                            lines.append(ln.strip())
                            if len(ln) >= 4 and ln[3] == " ":
                                break
                        return "\n".join(lines)

                    # Authenticate without knowing real cookie (proxy injects upstream cookie)
                    self.assertTrue(send_recv("AUTHENTICATE").startswith("250"))
                    # Allowed Tor Browser commands
                    self.assertTrue(send_recv("SIGNAL NEWNYM").startswith("250"))
                    self.assertIn("250-circuit-status=1 BUILT", send_recv("GETINFO circuit-status"))
                    self.assertTrue(send_recv("GETCONF bridge").startswith("250"))

                    # Forbidden commands MUST be rejected with 510 and NEVER reach upstream!
                    for forbidden in [
                        "GETINFO address",
                        "GETCONF CookieAuthFile",
                        "SETCONF DisableNetwork=0",
                        "ADD_ONION NEW:ED25519-V3 Port=80,8080",
                        "TAKEOWNERSHIP",
                        "SETEVENTS CIRC",
                    ]:
                        resp = send_recv(forbidden)
                        self.assertTrue(resp.startswith("510"), f"Forbidden cmd {forbidden!r} was not blocked: {resp}")

                    # Stream event isolation: only 127.0.0.1's stream event may pass, NOT 127.0.0.99's!
                    self.assertTrue(send_recv("SETEVENTS STREAM").startswith("250"))
                    ev_line = reader.readline().strip()
                    self.assertIn("SOURCE_ADDR=127.0.0.1:40001", ev_line)
                    self.assertNotIn("127.0.0.99", ev_line)
            finally:
                proxy_srv.shutdown()
                mock_tor.shutdown()
                proxy_srv.server_close()
                mock_tor.server_close()


if __name__ == "__main__":
    unittest.main()
