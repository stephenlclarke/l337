"""Temporary-file and fake-gate fixtures only; never invoke Swift or native CI."""

from contextlib import redirect_stderr, redirect_stdout
import io
import os
import re
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest

import tutorial_readme_parity as parity

ROOT = Path(__file__).resolve().parents[2]
# The existing CI gates are required independently of the new preflight wiring.
CI_GATES = (
    "change-scope-check", "retired-hulls-check", "sanitizers-check", "native-runner-check",
    "instance-equality-check", "ci-capture-check", "flight-controls-check",
    "homebrew-cask-check", "ships-check", "showroom-check", "mission-packs-check",
    "coverage-check", "leaks",
)
SHARED_CHECKPOINT_GATE = "sanitizer-checkpoints-check"


def write_copy(root, relative, data):
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


class TutorialReadmeParityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tutorial parity ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.body = b"# Navigation and trade\n\n[Issue notes](https://example.invalid/source)\n"
        for relative in (parity.DOCS_README, parity.BUNDLED_README):
            write_copy(self.root, relative, self.body)

    def test_equal_bytes_pass_and_cli_reports_success(self):
        output = io.StringIO()
        with redirect_stdout(output):
            result = parity.main(["--repo-root", str(self.root)])
        self.assertEqual(result, 0)
        self.assertIn("byte-identical", output.getvalue())

    def test_different_depth_relative_links_are_rejected(self):
        write_copy(self.root, parity.DOCS_README, b"[Notes](../../issue.md)\n")
        write_copy(self.root, parity.BUNDLED_README, b"[Notes](../../../../../issue.md)\n")
        with self.assertRaisesRegex(parity.ReadmeParityError, "copies differ"):
            parity.check_readme_parity(self.root)

    def test_whitespace_only_difference_is_not_normalized(self):
        write_copy(self.root, parity.BUNDLED_README, self.body + b"\n")
        with self.assertRaisesRegex(parity.ReadmeParityError, "copies differ"):
            parity.check_readme_parity(self.root)

    def test_each_missing_file_refuses(self):
        for relative in (parity.DOCS_README, parity.BUNDLED_README):
            with self.subTest(relative=relative):
                (self.root / relative).unlink()
                with self.assertRaisesRegex(parity.ReadmeParityError, "Cannot read"):
                    parity.check_readme_parity(self.root)
                write_copy(self.root, relative, self.body)

    def test_cli_failure_names_paths_and_does_not_repair_the_inputs(self):
        write_copy(self.root, parity.BUNDLED_README, b"mismatch\n")
        output = io.StringIO()
        with redirect_stderr(output):
            result = parity.main(["--repo-root", str(self.root)])
        self.assertEqual(result, 1)
        self.assertIn(str(parity.DOCS_README), output.getvalue())
        self.assertIn(str(parity.BUNDLED_README), output.getvalue())
        self.assertEqual((self.root / parity.DOCS_README).read_bytes(), self.body)
        self.assertEqual((self.root / parity.BUNDLED_README).read_bytes(), b"mismatch\n")

    def test_cli_missing_file_is_a_failure(self):
        (self.root / parity.BUNDLED_README).unlink()
        output = io.StringIO()
        with redirect_stderr(output):
            result = parity.main(["--repo-root", str(self.root)])
        self.assertEqual(result, 1)
        self.assertIn(str(parity.BUNDLED_README), output.getvalue())


class CIOrderingTests(unittest.TestCase):
    def make_ci_fixture(self, equal):
        with tempfile.TemporaryDirectory(prefix="tutorial CI fixture ") as directory:
            root = Path(directory)
            write_copy(root, parity.DOCS_README, b"same\n")
            write_copy(root, parity.BUNDLED_README, b"same\n" if equal else b"different\n")
            # Only fake marker recipes run. Preserve the actual prerequisite graph,
            # but avoid recursively invoking this suite from the preflight fixture.
            makefile = root / "Makefile"
            source = (ROOT / "Makefile").read_text()
            ci_rule = next(line for line in source.splitlines()
                           if line.startswith("ci: change-scope-check "))
            self.assertEqual(tuple(ci_rule.split(":", 1)[1].split()), CI_GATES)
            # Remove every real recipe, not just today's named CI gates, so a
            # future transitive prerequisite cannot accidentally launch a build.
            makefile.write_text("\n".join(line for line in source.splitlines()
                                          if not line.startswith("\t")) + "\n")
            targets = set()
            for match in re.finditer(r"^([A-Za-z][A-Za-z0-9_ -]*):(?!=)", source, re.M):
                targets.update(match.group(1).split())
            targets.difference_update({"ci", "tutorial-readme-check"})
            overrides = root / "fixture.mk"
            log = root / "gates.log"
            checker = ROOT / "Tools/CI/tutorial_readme_parity.py"
            command = shlex.join([sys.executable, str(checker), "--repo-root", str(root)])
            lines = ["tutorial-readme-check:", "\t@" + command,
                     "\t@printf '%s\\n' preflight >> " + shlex.quote(str(log))]
            for target in sorted(targets):
                lines.extend([target + ":", "\t@printf '%s\\n' " + target
                              + " >> " + shlex.quote(str(log))])
            overrides.write_text("\n".join(lines) + "\n")
            environment = os.environ.copy()
            for key in ("MAKEFLAGS", "MFLAGS", "GNUMAKEFLAGS", "MAKELEVEL"):
                environment.pop(key, None)
            result = subprocess.run(
                ["make", "-j8", "-f", str(makefile), "-f", str(overrides),
                 "ci", "ELITE_SANITIZERS=0"], cwd=root, env=environment,
                capture_output=True, text=True, timeout=10)
            return result, log.read_text().splitlines() if log.exists() else []

    def test_mismatch_stops_before_every_existing_gate_even_in_parallel_make(self):
        result, calls = self.make_ci_fixture(equal=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])
        self.assertIn("copies differ", result.stderr)

    def test_positive_preflight_precedes_all_original_gates(self):
        result, calls = self.make_ci_fixture(equal=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls[0], "preflight")
        self.assertCountEqual(calls[1:], [*CI_GATES, SHARED_CHECKPOINT_GATE])


if __name__ == "__main__":
    unittest.main()
