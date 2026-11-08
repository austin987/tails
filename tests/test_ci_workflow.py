#!/usr/bin/env python3
"""
Automated Verification Suite for AniTails GitHub Actions ISO Build Pipeline
(`tests/test_ci_workflow.py`)
============================================================================
Zero external pip dependency required (uses PyYAML when installed, or Ruby's
stdlib Psych YAML parser / strict indentation validator on minimal hosts).
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def _load_yaml_strict(path: Path) -> dict | None:
    txt = path.read_text(encoding="utf-8")
    # Basic YAML sanity: zero hard tabs allowed in YAML indentation
    for idx, line in enumerate(txt.splitlines(), start=1):
        if line.startswith("\t") or re.match(r"^ +\t", line):
            raise ValueError(f"Invalid tab indentation in {path}:{idx}")

    try:
        import yaml  # type: ignore

        return yaml.safe_load(txt)
    except ModuleNotFoundError:
        pass

    if shutil.which("ruby"):
        proc = subprocess.run(
            [
                "ruby",
                "-ryaml",
                "-rjson",
                "-e",
                "puts JSON.generate(YAML.safe_load(File.read(ARGV[0]), permitted_classes: [Date, Time]))",
                str(path),
            ],
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            raise ValueError(f"YAML syntax error in {path}: {proc.stderr}")
        return json.loads(proc.stdout)

    return None


class TestGitHubActionsIsoWorkflow(unittest.TestCase):
    def test_workflow_yaml_structure_and_security_permissions(self) -> None:
        wf_path = REPO_ROOT / ".github/workflows/build-iso.yml"
        self.assertTrue(wf_path.is_file(), "Missing .github/workflows/build-iso.yml")
        raw_txt = wf_path.read_text(encoding="utf-8")
        wf = _load_yaml_strict(wf_path)

        if wf is not None:
            triggers = wf.get("on") or wf.get(True) or wf.get("true")
            self.assertIsInstance(triggers, dict)
            self.assertIn("workflow_dispatch", triggers)
            self.assertIn("push", triggers)
            self.assertIn("pull_request", triggers)

            prof_opts = triggers["workflow_dispatch"]["inputs"]["profile"]["options"]
            for expected_prof in ("base", "nvidia-modern", "nvidia-legacy-580xx", "nvidia-cuda-optional", "all"):
                self.assertIn(expected_prof, prof_opts)

            self.assertEqual(wf.get("permissions"), {"contents": "read"})
            jobs = wf.get("jobs", {})
            self.assertIn("validate-and-security-tests", jobs)
            self.assertIn("build-iso", jobs)
            self.assertIn("draft-github-release", jobs)

        # Structural & security assertions on raw workflow content (always executed)
        self.assertRegex(raw_txt, r"(?m)^permissions:\n  contents: read$")
        for expected_prof in ("base", "nvidia-modern", "nvidia-legacy-580xx", "nvidia-cuda-optional", "all"):
            self.assertRegex(raw_txt, rf"(?m)^\s+-\s+{re.escape(expected_prof)}$")
        self.assertIn("validate-and-security-tests:", raw_txt)
        self.assertIn("build-iso:", raw_txt)
        self.assertIn("draft-github-release:", raw_txt)
        self.assertIn("--draft", raw_txt)
        self.assertIn("archlinux:base-devel", raw_txt)
        self.assertNotIn("SigLevel = Never", raw_txt)

    def test_ci_scripts_syntax_and_profile_validation(self) -> None:
        for rel in ("scripts/ci-build-local-repo.sh", "scripts/ci-verify-iso.sh", "scripts/build-iso.sh"):
            script = REPO_ROOT / rel
            self.assertTrue(script.is_file(), f"Missing {rel}")
            syn = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
            self.assertEqual(syn.returncode, 0, f"bash -n failed on {rel}: {syn.stderr}")

        ci_repo_txt = (REPO_ROOT / "scripts/ci-build-local-repo.sh").read_text(encoding="utf-8")
        self.assertIn("shred -u", ci_repo_txt)
        self.assertIn("repo-add --verify --sign", ci_repo_txt)
        self.assertNotIn("SigLevel = Never", ci_repo_txt)

        for prof in ("base", "nvidia-modern", "nvidia-legacy-580xx", "nvidia-cuda-optional"):
            res = subprocess.run(
                ["bash", str(REPO_ROOT / "scripts/ci-build-local-repo.sh"), "--profile", prof, "--validate-only"],
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 0, f"--validate-only failed for {prof}: {res.stderr}\n{res.stdout}")
            self.assertIn(f"profile='{prof}'", res.stdout)

    def test_linux_pkgbuild_tar_xz_stream_verify_and_extract(self) -> None:
        pb_txt = (REPO_ROOT / "pkgbuilds/linux-anitails/PKGBUILD").read_text(encoding="utf-8")
        self.assertIn('xz -cd "${srcdir}/linux-${pkgver}.tar.xz" | gpg --verify', pb_txt)
        self.assertIn('tar -xJf "${srcdir}/linux-${pkgver}.tar.xz"', pb_txt)
        self.assertNotIn('tar -xf "${srcdir}/linux-${pkgver}.tar"\n', pb_txt)


if __name__ == "__main__":
    unittest.main()
