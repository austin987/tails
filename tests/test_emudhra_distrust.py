#!/usr/bin/env python3
"""
Test Suite 1: eMudhra & Sectigo `AAA Certificate Services` Cross-Signed CA Distrust
(Tails 7.15.1 / CVE-2026-113470 / DSA-6572-1 / Mozilla Bugs 2083709, 2084101, 2089115).

Executes real OpenSSL X.509 path verification against:
  - All 4 real-world public test leaf chains from `we-have-a-problem.com`:
    1. `dv-g3b-emudhra.we-have-a-problem.com.pem` (direct `emSign Root TLS CA - G3` chain)
    2. `dv-g3b-aaa-emudhra.we-have-a-problem.com.pem` (Sectigo `AAA Certificate Services` cross-signed chain)
    3. `ev-g3c-aaa-emudhra.we-have-a-problem.com.pem` (EV Sectigo `AAA Certificate Services` cross-signed chain)
    4. `dv-g3b-noct-rollover-emudhra.we-have-a-problem.com.pem` (`emSign ECC Root CA - G3 -> emSign Root TLS CA - G3` rollover cross-signed chain)
  - Positive control: legitimate non-eMudhra TLS server chain MUST verify `OK`.
  - Anti-test (negative control): unpatched legacy root store ACCEPTS all 4 compromised chains,
    and a half-patched store that only blocks eMudhra roots while forgetting `AAA Certificate Services`
    is BYPASSED by the Sectigo cross-signed chains!
  - `anitails-verify-truststore` audit tool positive & negative controls.
"""

from __future__ import annotations

import datetime as dt
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
P11KIT_PATH = REPO_ROOT / "archiso/airootfs/etc/ca-certificates/trust-source/blacklist/anitails-emudhra-distrust.p11-kit"
INDICATORS_PATH = REPO_ROOT / "archiso/airootfs/usr/share/anitails/ca-distrust/emudhra-indicators.json"
AUDITOR_BIN = REPO_ROOT / "archiso/airootfs/usr/local/bin/anitails-verify-truststore"
FIXTURES_DIR = REPO_ROOT / "tests/fixtures/emudhra_chains"

# Evaluation timestamp: today's UTC date (2026-11-08T00:00:00Z, right inside the active validity window!)
TODAY_ATTIME = str(int(dt.datetime(2026, 11, 8, 0, 0, 0, tzinfo=dt.timezone.utc).timestamp()))
CHAIN_ATTIME = TODAY_ATTIME


def extract_labeled_pems(p11kit_file: Path) -> dict[str, str]:
    text = p11kit_file.read_text(encoding="utf-8")
    pattern = re.compile(
        r'label:\s*"([^"]+)".*?(-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----)',
        re.DOTALL,
    )
    return {m.group(1): m.group(2) for m in pattern.finditer(text)}


def split_chain_file(chain_file: Path) -> tuple[str, list[str]]:
    pems = re.findall(
        r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----",
        chain_file.read_text(encoding="utf-8"),
        re.DOTALL,
    )
    assert len(pems) >= 2, f"Expected leaf + intermediate(s) in {chain_file}"
    return pems[0], pems[1:]


def to_openssl_rejected_cert(pem: str) -> str:
    proc = subprocess.run(
        [
            "openssl", "x509",
            "-addreject", "serverAuth",
            "-addreject", "clientAuth",
            "-addreject", "codeSigning",
            "-addreject", "emailProtection",
            "-trustout",
        ],
        input=pem,
        capture_output=True,
        text=True,
        check=True,
    )
    return proc.stdout


def to_openssl_trusted_root(pem: str) -> str:
    proc = subprocess.run(
        ["openssl", "x509", "-addtrust", "serverAuth", "-trustout"],
        input=pem,
        capture_output=True,
        text=True,
        check=True,
    )
    return proc.stdout


def generate_test_ca_or_leaf(
    tmpdir: Path,
    name: str,
    subj: str,
    is_ca: bool,
    issuer_cert: Path | None = None,
    issuer_key: Path | None = None,
) -> tuple[Path, Path]:
    key_path = tmpdir / f"{name}.key"
    subprocess.run(
        ["openssl", "ecparam", "-name", "secp384r1", "-genkey", "-noout", "-out", str(key_path)],
        check=True,
        capture_output=True,
    )
    csr_path = tmpdir / f"{name}.csr"
    cert_path = tmpdir / f"{name}.crt"
    ext_path = tmpdir / f"{name}.ext"

    if is_ca:
        ext_path.write_text(
            "basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\n",
            encoding="utf-8",
        )
    else:
        ext_path.write_text(
            "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:good.example.org\n",
            encoding="utf-8",
        )

    subprocess.run(
        ["openssl", "req", "-new", "-key", str(key_path), "-subj", subj, "-out", str(csr_path)],
        check=True,
        capture_output=True,
    )

    if issuer_cert is None:
        subprocess.run(
            [
                "openssl", "x509", "-req",
                "-in", str(csr_path),
                "-signkey", str(key_path),
                "-days", "3650",
                "-extfile", str(ext_path),
                "-out", str(cert_path),
            ],
            check=True,
            capture_output=True,
        )
    else:
        subprocess.run(
            [
                "openssl", "x509", "-req",
                "-in", str(csr_path),
                "-CA", str(issuer_cert),
                "-CAkey", str(issuer_key),
                "-CAcreateserial",
                "-days", "730",
                "-extfile", str(ext_path),
                "-out", str(cert_path),
            ],
            check=True,
            capture_output=True,
        )
    return key_path, cert_path


class TestEmudhraAndCrossSignDistrust(unittest.TestCase):
    def test_real_emudhra_and_sectigo_cross_sign_chains_and_controls(self) -> None:
        pems = extract_labeled_pems(P11KIT_PATH)
        # 7 roots + 16 intermediates = 23 X.509 blacklist objects
        self.assertEqual(len(pems), 23)

        chain_files = [
            "dv-g3b-emudhra.we-have-a-problem.com.pem",
            "dv-g3b-aaa-emudhra.we-have-a-problem.com.pem",
            "ev-g3c-aaa-emudhra.we-have-a-problem.com.pem",
            "dv-g3b-noct-rollover-emudhra.we-have-a-problem.com.pem",
        ]

        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)

            # Build legitimate positive-control PKI
            good_root_key, good_root_crt = generate_test_ca_or_leaf(tmp, "good_root", "/CN=AniTails Good Test Root CA", is_ca=True)
            good_int_key, good_int_crt = generate_test_ca_or_leaf(
                tmp, "good_int", "/CN=AniTails Good Intermediate CA", is_ca=True,
                issuer_cert=good_root_crt, issuer_key=good_root_key,
            )
            _, good_leaf_crt = generate_test_ca_or_leaf(
                tmp, "good_leaf", "/CN=good.example.org", is_ca=False,
                issuer_cert=good_int_crt, issuer_key=good_int_key,
            )

            # 1. Anti-test (Negative Control): Unpatched legacy root bundle trusts all 4 real compromised chains!
            unpatched_bundle = tmp / "unpatched_legacy_bundle.pem"
            unpatched_bundle.write_text(
                good_root_crt.read_text(encoding="utf-8")
                + pems["DISTRUST ROOT: emSign ECC Root CA - G3"] + "\n"
                + pems["DISTRUST ROOT: emSign Root TLS CA - G3"] + "\n"
                + pems["DISTRUST ROOT: AAA Certificate Services"] + "\n",
                encoding="utf-8",
            )

            for cname in chain_files:
                leaf_pem, untrusted_list = split_chain_file(FIXTURES_DIR / cname)
                leaf_f = tmp / f"leaf_{cname}"
                untr_f = tmp / f"untr_{cname}"
                leaf_f.write_text(leaf_pem + "\n", encoding="utf-8")
                untr_f.write_text("\n".join(untrusted_list) + "\n", encoding="utf-8")

                r_unpatched = subprocess.run(
                    [
                        "openssl", "verify", "-purpose", "sslserver", "-attime", CHAIN_ATTIME,
                        "-CAfile", str(unpatched_bundle), "-untrusted", str(untr_f), str(leaf_f),
                    ],
                    capture_output=True, text=True,
                )
                self.assertEqual(r_unpatched.returncode, 0, f"Anti-test expected unpatched store to accept {cname}: {r_unpatched.stderr}")

            # 2. Half-patched store anti-test (blocks eMudhra roots ONLY, forgets Sectigo `AAA Certificate Services`!)
            # Proves real Sectigo cross-signed chains BYPASS naive eMudhra-only root removal!
            half_patched_bundle = tmp / "half_patched_bundle.pem"
            half_patched_bundle.write_text(
                to_openssl_trusted_root(pems["DISTRUST ROOT: AAA Certificate Services"])
                + to_openssl_rejected_cert(pems["DISTRUST ROOT: emSign ECC Root CA - G3"])
                + to_openssl_rejected_cert(pems["DISTRUST ROOT: emSign Root TLS CA - G3"]),
                encoding="utf-8",
            )
            r_half_bypass = subprocess.run(
                [
                    "openssl", "verify", "-purpose", "sslserver", "-attime", CHAIN_ATTIME,
                    "-CAfile", str(half_patched_bundle),
                    "-untrusted", str(tmp / "untr_dv-g3b-aaa-emudhra.we-have-a-problem.com.pem"),
                    str(tmp / "leaf_dv-g3b-aaa-emudhra.we-have-a-problem.com.pem"),
                ],
                capture_output=True, text=True,
            )
            self.assertEqual(r_half_bypass.returncode, 0, "Half-patched bundle MUST demonstrate Sectigo cross-sign bypass!")

            # 3. AniTails Hardened Bundle (Good Root trusted + all 23 p11-kit blacklist objects marked REJECT)
            hardened_bundle = tmp / "hardened_bundle.pem"
            hardened_text = to_openssl_trusted_root(good_root_crt.read_text(encoding="utf-8"))
            for pem in pems.values():
                hardened_text += to_openssl_rejected_cert(pem)
            hardened_bundle.write_text(hardened_text, encoding="utf-8")

            # Positive Control MUST PASS
            res_good = subprocess.run(
                [
                    "openssl", "verify", "-purpose", "sslserver",
                    "-CAfile", str(hardened_bundle),
                    "-untrusted", str(good_int_crt),
                    str(good_leaf_crt),
                ],
                capture_output=True, text=True,
            )
            self.assertEqual(res_good.returncode, 0, f"Positive control leaf failed: {res_good.stderr}")

            # ALL 4 real compromised chains (direct, AAA DV cross-sign, AAA EV cross-sign, ECC G3 rollover) MUST BE REJECTED!
            for cname in chain_files:
                r_hard = subprocess.run(
                    [
                        "openssl", "verify", "-purpose", "sslserver", "-attime", CHAIN_ATTIME,
                        "-CAfile", str(hardened_bundle),
                        "-untrusted", str(tmp / f"untr_{cname}"),
                        str(tmp / f"leaf_{cname}"),
                    ],
                    capture_output=True, text=True,
                )
                self.assertNotEqual(r_hard.returncode, 0, f"Hardened bundle FAILED to block compromised chain {cname}!")

            # Also verify intermediate rejection at today's timestamp (2026-11-08)
            em_dv_cross = tmp / "em_dv_cross_20261108.pem"
            em_dv_cross.write_text(
                pems["DISTRUST INTERMEDIATE: EM DV TLS CA - G3B (Issued by AAA Certificate Services)"] + "\n",
                encoding="utf-8",
            )
            r_today = subprocess.run(
                [
                    "openssl", "verify", "-purpose", "sslserver", "-attime", TODAY_ATTIME,
                    "-CAfile", str(hardened_bundle), str(em_dv_cross),
                ],
                capture_output=True, text=True,
            )
            self.assertNotEqual(r_today.returncode, 0)

            # 4. Run `anitails-verify-truststore` auditor on hardened vs unpatched bundles
            audit_ok = subprocess.run(
                ["python3", str(AUDITOR_BIN), "--bundle", str(hardened_bundle), "--indicators", str(INDICATORS_PATH)],
                capture_output=True, text=True,
            )
            self.assertEqual(audit_ok.returncode, 0, f"Auditor failed on hardened bundle: {audit_ok.stderr}")

            audit_bad = subprocess.run(
                ["python3", str(AUDITOR_BIN), "--bundle", str(unpatched_bundle), "--indicators", str(INDICATORS_PATH)],
                capture_output=True, text=True,
            )
            self.assertNotEqual(audit_bad.returncode, 0, "Auditor MUST fail on unpatched bundle!")
            self.assertIn("AAA Certificate Services", audit_bad.stderr)
            self.assertIn("emSign Root TLS CA - G3", audit_bad.stderr)


if __name__ == "__main__":
    unittest.main()
