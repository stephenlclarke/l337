"""Exercise CI and package verification entry points using pure file regressions."""
import ast
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import package_macos
import retired_hull_resources as gate


class RetiredHullWiringTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="retired-hull-wiring-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "Sources/L337Core/Resources"
        self.app = self.root / "L337.app"
        self.bundle = self.app / "Contents/Resources/L337_L337Core.bundle"
        rows = json.loads(Path(__file__).with_name("fixtures")
                          .joinpath("retired_hull_meshes.json").read_bytes())
        row = next(row for row in rows if row["id"] == "SH023")
        self.old = ('id = "SH023"\n[design]\nvertices = '
                    + json.dumps(row["mesh"]["vertices"]) + '\nfaces = '
                    + json.dumps(row["mesh"]["faces"]) + '\n').encode()
        self.write(self.source / "Ships/SH023.toml", self.old)
        self.write(self.bundle / "Ships/SH023.toml", self.old)

    @staticmethod
    def write(path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def test_make_ci_invokes_source_gate_and_propagates_actual_retired_mesh_failure(self):
        repository = Path(__file__).resolve().parents[2]
        makefile = (repository / "Makefile").read_text()
        prerequisites = next(line.partition(":")[2].split() for line in makefile.splitlines()
                             if line.startswith("ci: "))
        self.assertEqual(prerequisites[0], "retired-hulls-check")
        self.write(self.root / "Makefile", makefile.encode())
        for name in ["retired_hull_resources.py", "retired_hull_policy.json"]:
            self.write(self.root / "Tools/distribution" / name,
                       Path(__file__).with_name(name).read_bytes())
        binary = self.root / "bin"
        binary.mkdir()
        (binary / "python3").symlink_to(sys.executable)
        environment = {**os.environ, "PATH": str(binary), "PYTHONDONTWRITEBYTECODE": "1"}
        # The only eligible recipe is the gate. This fixture has no native tool path.
        skip = [option for target in prerequisites[1:] for option in ("-o", target)]
        result = subprocess.run([shutil.which("make"), "--no-print-directory", "ci",
                                 "ELITE_SANITIZERS=0", *skip], cwd=self.root,
                                env=environment, capture_output=True, text=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Tools/distribution/retired_hull_resources.py", result.stdout)
        self.assertIn("Retired mesh", result.stderr)
        self.assertNotIn("swift ", result.stdout)

    def test_package_verification_rejects_real_retired_source_before_copy_equality(self):
        with self.assertRaisesRegex(ValueError, "Retired mesh"):
            package_macos.verify_resources(self.app, source_root=self.root)

    def test_package_bundle_boundary_invokes_real_retired_mesh_check(self):
        original = gate.verify_resource_tree
        calls = []

        def source_then_bundle(resources):
            calls.append(resources)
            # Isolate the bundle boundary after a successful source check.
            return {} if resources == self.source else original(resources)

        with patch.object(gate, "verify_resource_tree", side_effect=source_then_bundle):
            with self.assertRaisesRegex(ValueError, "Retired mesh"):
                package_macos.verify_resources(self.app, source_root=self.root)
        self.assertEqual(calls, [self.source, self.bundle])

    def test_cli_app_entry_delegates_once_and_release_checks_both_packaged_copies(self):
        with patch.object(gate, "verify_resource_tree", return_value={}) as check:
            self.assertEqual(gate.verify(self.root, self.app), {"source": {}, "bundle": {}})
        self.assertEqual([call.args[0] for call in check.call_args_list],
                         [self.source, self.bundle])
        module = ast.parse(Path(package_macos.__file__).read_text())
        package = next(node for node in module.body
                       if isinstance(node, ast.FunctionDef) and node.name == "package")
        checked = [node.args[0].id for node in ast.walk(package)
                   if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                   and node.func.id == "verify_resources"]
        self.assertEqual(checked, ["app", "delivered"])
