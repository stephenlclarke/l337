"""Pure-file regressions for current and injected retired resource resolution."""
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import tomllib
import unittest

import package_macos
import retired_hull_resources as gate


class RetiredHullResourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="retired-hull-source-")
        cls.root = Path(cls.temporary.name)
        cls.resources = cls.root / "Sources/L337Core/Resources"
        source = Path(__file__).resolve().parents[2] / "Sources/L337Core/Resources"
        shutil.copytree(source, cls.resources)
        shutil.copyfile(source.parents[2] / "Package.swift", cls.root / "Package.swift")
        cls.old = json.loads(Path(__file__).with_name("fixtures")
                             .joinpath("retired_hull_meshes.json").read_bytes())

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    @contextmanager
    def changed(self, path, data):
        original = path.read_bytes()
        path.write_bytes(data)
        try:
            yield
        finally:
            path.write_bytes(original)

    def legacy_resource(self, row):
        # Exact audited arrays and mapping fields exercise the resource resolver.
        return (f'id = "{row["id"]}"\nname = "Historical role"\n'
                f'nativeHull = "{row["nativeHull"]}"\n'
                '[design]\nvertices = ' + json.dumps(row["mesh"]["vertices"])
                + '\nfaces = ' + json.dumps(row["mesh"]["faces"]) + '\n').encode()

    def test_current_catalogue_aegis_scoped_models_and_native_allowlist_pass(self):
        result = gate.verify(self.root)["source"]
        self.assertEqual(result["catalogue"], 171)
        self.assertEqual(result["nativeMappings"], ["SH028", "SH031"])
        self.assertGreater(result["declaredAssets"], 0)
        self.assertGreater(result["profileReferences"], 0)

    def test_every_audited_old_array_and_numeric_equivalent_matches_its_pin(self):
        policy = json.loads(gate.POLICY.read_bytes())
        expected = {(row["id"], row["field"]): row for row in policy["retiredMeshes"]}
        self.assertEqual({row["id"] for row in self.old},
                         {"SH023", "SH026", "SH107", "SH124", "SH125", "SH136"})
        for row in self.old:
            with self.subTest(identity=row["id"], field=row["field"]):
                self.assertEqual(gate.mesh_fingerprint(row["mesh"]),
                                 expected[row["id"], row["field"]]["meshSHA256"])
                equivalent = {key: [[float(value) for value in values] for values in array]
                              for key, array in row["mesh"].items()}
                self.assertEqual(gate.mesh_fingerprint(equivalent), row["meshSHA256"])

    def test_all_six_old_slot_bindings_are_rejected(self):
        rows = {row["id"]: row for row in self.old}
        for identity, row in rows.items():
            with self.subTest(identity=identity):
                path = self.resources / "Ships" / (identity + ".toml")
                with self.changed(path, self.legacy_resource(row)):
                    with self.assertRaisesRegex(ValueError, "Retired mesh"):
                        gate.verify_resource_tree(self.resources)

    def test_original_name_does_not_hide_a_retired_mesh_substitution(self):
        row = next(row for row in self.old if row["id"] == "SH023")
        current = tomllib.loads((self.resources / "Ships/SH023.toml").read_text())
        data = (f'id = "SH023"\nname = "{current["name"]}"\n'
                f'[catalogue]\nfamily = "{current["catalogue"]["family"]}"\n'
                '[design]\nvertices = ' + json.dumps(row["mesh"]["vertices"])
                + '\nfaces = ' + json.dumps(row["mesh"]["faces"]) + '\n').encode()
        with self.changed(self.resources / "Ships/SH023.toml", data):
            with self.assertRaisesRegex(ValueError, "Retired mesh"):
                gate.verify_resource_tree(self.resources)

    def test_undeclared_native_alias_is_rejected_with_original_geometry(self):
        path = self.resources / "Ships/SH025.toml"
        with self.changed(path, b'nativeHull = "cobra"\n' + path.read_bytes()):
            with self.assertRaisesRegex(ValueError, "Unexpected native catalogue mapping"):
                gate.verify_resource_tree(self.resources)

    def test_known_mesh_in_rehashed_declared_asset_is_rejected(self):
        pack = self.resources / "ScriptPacks/l337-induction-crew-log"
        manifest = pack / "manifest.toml"
        declaration = tomllib.loads(manifest.read_text())["models"][0]
        asset = pack / declaration["path"]
        data = json.dumps(self.old[0]["mesh"]).encode()
        updated = manifest.read_bytes().replace(declaration["sha256"].encode(),
                                                hashlib.sha256(data).hexdigest().encode())
        with self.changed(asset, data), self.changed(manifest, updated):
            with self.assertRaisesRegex(ValueError, "Retired mesh"):
                gate.verify_resource_tree(self.resources)

    def test_missing_declared_asset_and_unresolved_catalogue_reference_fail(self):
        pack = self.resources / "ScriptPacks/l337-induction-crew-log"
        manifest = pack / "manifest.toml"
        text = manifest.read_bytes()
        for old, new in [(b'models/burro.json', b'models/missing.json'),
                         (b'catalogue:SH058', b'catalogue:SH999')]:
            with self.subTest(change=new), self.changed(manifest, text.replace(old, new)):
                with self.assertRaises((ValueError, FileNotFoundError)):
                    gate.verify_resource_tree(self.resources)

    def test_historical_document_files_are_outside_runtime_resolution(self):
        path = self.root / "docs/historical-retired-model.json"
        path.parent.mkdir(exist_ok=True)
        path.write_text(json.dumps(self.old))
        try:
            self.assertEqual(gate.verify(self.root)["source"]["catalogue"], 171)
        finally:
            path.unlink()

    def test_flat_and_nested_packaged_resources_resolve_and_reject_bundle_substitution(self):
        for nested in (False, True):
            with self.subTest(nested=nested), tempfile.TemporaryDirectory() as temporary:
                app = Path(temporary) / "L337.app"
                bundle = app / "Contents/Resources/L337_L337Core.bundle"
                destination = bundle / "Contents/Resources" if nested else bundle
                targets = package_macos.resource_targets(self.root)
                for source in self.resources.rglob("*"):
                    if not source.is_file():
                        continue
                    relative = source.relative_to(self.resources)
                    target = destination / targets[relative]
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, target)
                result = gate.verify(self.root, app)
                self.assertEqual(result["source"], result["bundle"])
                path = destination / "Ships/SH023.toml"
                path.write_bytes(self.legacy_resource(self.old[0]))
                with self.assertRaisesRegex(RuntimeError, "Missing/changed packaged resource"):
                    gate.verify(self.root, app)
                source = self.resources / "Ships/SH023.toml"
                with self.changed(source, path.read_bytes()):
                    with self.assertRaisesRegex(ValueError, "Retired mesh"):
                        gate.verify(self.root, app)
