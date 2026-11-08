"""Preserve copied resource paths and exact bytes in either macOS bundle layout."""

import plistlib
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import package_macos


class PackagedResourceTests(unittest.TestCase):
    def test_bundle_uses_one_current_product_identity_and_preserves_payload_bytes(self):
        binaries = self.root / "binaries"
        self.write(binaries / "L337", b"fixture executable")
        self.write(binaries / "L337_L337Core.bundle/resource", b"fixture resource")
        self.write(self.root / "Resources/L337.icns", b"fixture icon")
        self.write(self.root / "LICENSE", b"unchanged license")
        self.write(self.root / "NOTICE.md", b"unchanged notice")
        app = package_macos.create_bundle(self.root / "delivery", binaries, "2.0.0", "a" * 40)
        self.assertEqual(app.name, "L337.app")
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        self.assertEqual(info["CFBundleIdentifier"], "io.xyzzy.l337")
        self.assertEqual(info["CFBundleExecutable"], "L337")
        self.assertEqual(info["CFBundleDisplayName"], "L337")
        self.assertEqual(info["L337SourceRevision"], "a" * 40)
        self.assertNotIn("EliteSourceRevision", info)
        self.assertEqual((app / "Contents/MacOS/L337").read_bytes(), b"fixture executable")
        self.assertEqual((app / "Contents/Resources/L337_L337Core.bundle/resource").read_bytes(),
                         b"fixture resource")
        self.assertEqual((app / "Contents/Resources/NOTICE.md").read_bytes(), b"unchanged notice")

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "Sources/L337Core/Resources"
        self.app = self.root / "L337.app"
        self.bundle = self.app / "Contents/Resources/L337_L337Core.bundle"
        self.resources = {
            "Ships/ship.toml": b"ship",
            "MissionPacks/campaign/manifest.toml": b"legacy campaign",
            "ScriptPacks/generated-couriers/manifest.toml": b"courier manifest",
            "ScriptPacks/generated-couriers/main.lua": b"courier script",
            "ScriptPacks/another-pack/manifest.toml": b"different manifest",
            "ScriptPacks/another-pack/main.lua": b"different script",
            "ShipTextures/RayDetails/texture.png": b"ray texture",
            "ShipTextures/Stingray/texture.png": b"stingray texture",
            "OriginalWorlds/catalogue.json": b"original worlds",
            "OriginalWorlds/PROVENANCE.json": b"world provenance",
            "OriginalShipTextures/texture.png": b"original ship texture",
            "OriginalFleetShowroomModels/SH084.json": b"original showroom model",
            "OriginalFleetPhysical/SH036.json": b"original physical source budget",
            "OriginalMarkets/catalogue.json": b"original market catalogue",
            "Legal/NOTICE.txt": b"legal notice",
            "ModelLicenses/model.txt": b"model licence",
            "ASSET-NOTICE.txt": b"asset notice",
        }
        for relative, contents in self.resources.items():
            self.write(self.source / relative, contents)
        copied = ("Ships", "MissionPacks", "ScriptPacks", "ShipTextures", "OriginalWorlds",
                  "OriginalShipTextures", "OriginalFleetShowroomModels", "OriginalFleetPhysical",
                  "OriginalMarkets")
        declarations = [f'.copy("Resources/{name}")' for name in copied]
        declarations += ['.process("Resources/Legal")', '.process("Resources/ModelLicenses")',
                         '.process("Resources/ASSET-NOTICE.txt")']
        self.write(self.root / "Package.swift", (
            '.target(name: "L337Core", resources: [' + ','.join(declarations) + '])'
        ).encode())
        self.root_patch = patch.object(package_macos, "ROOT", self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        # These fixtures isolate byte/path equality; real provenance has its own tests.
        provenance = patch("retired_hull_resources.verify_resource_tree", return_value={})
        provenance.start()
        self.addCleanup(provenance.stop)

    @staticmethod
    def write(path, contents):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(contents)

    def populate_bundle(self, nested):
        destination = self.bundle / "Contents/Resources" if nested else self.bundle
        for relative, contents in self.resources.items():
            path = Path(relative)
            # SwiftPM processes these directories into the bundle's resource root.
            if path.parts[0] in ("Legal", "ModelLicenses"):
                path = Path(path.name)
            self.write(destination / path, contents)
        return destination

    def test_copied_paths_and_processed_legal_files_survive_both_bundle_layouts(self):
        for nested in (False, True):
            with self.subTest(nested=nested):
                self.populate_bundle(nested)
                package_macos.verify_resources(self.app)

    def test_missing_copied_resource_is_rejected_in_both_layouts(self):
        for nested in (False, True):
            for relative in self.resources:
                with self.subTest(nested=nested, relative=relative):
                    destination = self.populate_bundle(nested)
                    target = destination / relative
                    if relative.startswith(("Legal/", "ModelLicenses/")):
                        target = destination / Path(relative).name
                    target.unlink()
                    with self.assertRaisesRegex(
                        RuntimeError, "Missing/changed packaged resource"
                    ):
                        package_macos.verify_resources(self.app)

    def test_changed_bytes_are_rejected_in_both_layouts(self):
        for nested in (False, True):
            for relative in self.resources:
                with self.subTest(nested=nested, relative=relative):
                    destination = self.populate_bundle(nested)
                    target = destination / relative
                    if relative.startswith(("Legal/", "ModelLicenses/")):
                        target = destination / Path(relative).name
                    target.write_bytes(b"changed")
                    with self.assertRaisesRegex(
                        RuntimeError, "Missing/changed packaged resource"
                    ):
                        package_macos.verify_resources(self.app)

    def test_flattened_copied_alias_cannot_replace_the_nested_resource(self):
        for nested in (False, True):
            for relative in (
                "ScriptPacks/generated-couriers/manifest.toml",
                "ScriptPacks/generated-couriers/main.lua",
                "ShipTextures/RayDetails/texture.png",
                "OriginalWorlds/catalogue.json",
                "OriginalShipTextures/texture.png",
                "OriginalFleetShowroomModels/SH084.json",
                "OriginalFleetPhysical/SH036.json",
                "OriginalMarkets/catalogue.json",
            ):
                with self.subTest(nested=nested, relative=relative):
                    destination = self.populate_bundle(nested)
                    target = destination / relative
                    target.unlink()
                    self.write(destination / target.name, self.resources[relative])
                    with self.assertRaisesRegex(
                        RuntimeError, "Missing/changed packaged resource"
                    ):
                        package_macos.verify_resources(self.app)


class PackagedResourceManifestTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "Sources/L337Core/Resources"

    def manifest(self, resources, other=""):
        (self.root / "Package.swift").write_text(
            other + '.target(name: "L337Core", resources: [' + resources + '])')

    def write(self, relative, content=b"source bytes"):
        target = self.source / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)

    def test_every_actual_copy_and_process_family_preserves_its_declared_layout(self):
        # The real manifest is the authority; no manually maintained family list is compared.
        manifest = Path(package_macos.__file__).resolve().parents[2] / "Package.swift"
        (self.root / "Package.swift").write_bytes(manifest.read_bytes())
        declarations = package_macos.resource_declarations(self.root)
        # Independent literal oracle for this maintained manifest, then real bundle fakes
        # below verify each family's layout and missing/changed/flattened-alias refusals.
        core = re.search(r'\.target\(\s*name:\s*"L337Core"[\s\S]*?resources:\s*'
                         r'\[([\s\S]*?)\]\s*\)', manifest.read_text())
        self.assertIsNotNone(core)
        expected_rules = tuple((rule, Path(path)) for rule, path in
                               re.findall(r'\.(copy|process)\("Resources/([^"\n]+)"\)',
                                          core.group(1)))
        self.assertEqual(declarations, expected_rules)
        self.assertIn(("copy", Path("HogPhysical")), declarations)
        self.assertIn(("copy", Path("BisonColdLoopCandidate")), declarations)
        self.assertTrue(expected_rules)
        expected = {}
        for index, (rule, path) in enumerate(declarations):
            relative = path / f"distinct-{index}.json" if path.suffix == "" else path
            self.write(relative, f"unique source {index}".encode())
            expected[relative] = relative if rule == "copy" else Path(relative.name)
        self.assertEqual(package_macos.resource_targets(self.root), expected)
        for nested in (False, True):
            with self.subTest(nested=nested):
                app = self.root / ("Nested.app" if nested else "Flat.app")
                bundle = app / "Contents/Resources/L337_L337Core.bundle"
                destination = bundle / "Contents/Resources" if nested else bundle
                for relative, target in expected.items():
                    path = destination / target
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes((self.source / relative).read_bytes())
                with patch("retired_hull_resources.verify_resource_tree", return_value={}):
                    package_macos.verify_resources(app, source_root=self.root)
                    # Every family must still reject missing and changed bytes, including Hog/Bison.
                    for relative, target in expected.items():
                        path = destination / target
                        original = path.read_bytes()
                        path.unlink()
                        with self.assertRaisesRegex(RuntimeError, "Missing/changed packaged resource"):
                            package_macos.verify_resources(app, source_root=self.root)
                        if target.parent != Path("."):
                            alias = destination / target.name
                            alias.write_bytes(original)
                            with self.assertRaisesRegex(RuntimeError, "Missing/changed packaged resource"):
                                package_macos.verify_resources(app, source_root=self.root)
                            alias.unlink()
                        path.write_bytes(b"changed")
                        with self.assertRaisesRegex(RuntimeError, "Missing/changed packaged resource"):
                            package_macos.verify_resources(app, source_root=self.root)
                        path.write_bytes(original)

    def test_new_copy_family_is_derived_without_a_verifier_code_change(self):
        self.manifest('.copy("Resources/FutureInstrument")')
        self.write("FutureInstrument/deep/source.json")
        self.assertEqual(package_macos.resource_targets(self.root), {
            Path("FutureInstrument/deep/source.json"): Path("FutureInstrument/deep/source.json")})

    def test_other_target_and_commented_rules_cannot_change_core_layout(self):
        self.manifest('.process("Resources/Legal")',
                      '// .copy("Resources/Fake")\n'
                      '.target(name: "Other", resources: [.copy("Resources/Legal")]),')
        self.write("Legal/deep/license.txt")
        self.assertEqual(package_macos.resource_targets(self.root), {
            Path("Legal/deep/license.txt"): Path("license.txt")})

    def test_nested_and_ordinary_comments_cannot_supply_a_decoy_core_target(self):
        self.manifest('.process("Resources/Legal")',
                      '/* outer\n /* inner */\n'
                      ' .target(name: "L337Core", resources: [.copy("Resources/Decoy")])\n'
                      ' */\n'
                      '/* ordinary .target(name: "L337Core", resources: []) */\n'
                      '// .target(name: "L337Core", resources: [])\n')
        self.write("Legal/license.txt")
        self.assertEqual(package_macos.resource_targets(self.root), {
            Path("Legal/license.txt"): Path("license.txt")})

    def test_comment_markers_inside_strings_do_not_hide_actual_rules(self):
        self.manifest('.process("Resources/Legal")',
                      'let markers = "/* outer /* inner */ still a string // */"\n'
                      'let escaped = "\\\" /* and // remain inside a string"\n')
        self.write("Legal/license.txt")
        self.assertEqual(package_macos.resource_targets(self.root), {
            Path("Legal/license.txt"): Path("license.txt")})

    def test_unterminated_comment_or_string_refuses_instead_of_partial_mapping(self):
        for prefix in ['/* outer /* closed inner */', 'let marker = "unterminated']:
            with self.subTest(prefix=prefix):
                self.manifest('.copy("Resources/One")', prefix)
                with self.assertRaisesRegex(RuntimeError, "Unterminated Package.swift"):
                    package_macos.resource_declarations(self.root)

    def test_nested_copy_directory_and_copied_file_follow_declared_basename(self):
        self.manifest('.copy("Resources/Archive/Instrument"),.copy("Resources/Note.txt")')
        self.write("Archive/Instrument/deep/source.json")
        self.write("Note.txt")
        self.assertEqual(package_macos.resource_targets(self.root), {
            Path("Archive/Instrument/deep/source.json"): Path("Instrument/deep/source.json"),
            Path("Note.txt"): Path("Note.txt")})

    def test_undeclared_overlapping_missing_and_colliding_resources_refuse(self):
        self.write("One/file.json")
        for rules, message in [
            ('.copy("Resources/Missing")', "Missing/invalid declared"),
            ('.process("Resources/One/file.json")', None),
            ('.copy("Resources/One"),.copy("Resources/One/file.json")', "exactly one"),
        ]:
            with self.subTest(rules=rules):
                self.manifest(rules)
                if message:
                    with self.assertRaisesRegex(RuntimeError, message):
                        package_macos.resource_targets(self.root)
                else:
                    self.write("Other/unlisted.json")
                    with self.assertRaisesRegex(RuntimeError, "exactly one"):
                        package_macos.resource_targets(self.root)
                    (self.source / "Other/unlisted.json").unlink()
        self.write("Two/file.json")
        self.manifest('.process("Resources/One"),.process("Resources/Two")')
        with self.assertRaisesRegex(RuntimeError, "destination collision"):
            package_macos.resource_targets(self.root)

    def test_unsupported_or_escaping_manifest_rules_fail_closed(self):
        for rule in ['.copy("Resources/../One")', '.copy("Resources//One")',
                     '.copy("Elsewhere/One")', '.copy(dynamicPath)',
                     '.process("Resources/One", localization: .default)']:
            with self.subTest(rule=rule):
                self.manifest(rule)
                with self.assertRaises(RuntimeError):
                    package_macos.resource_declarations(self.root)
        (self.root / "Package.swift").write_text(
            '.target(name: "L337Core", resources: variableRules)')
        with self.assertRaises(RuntimeError):
            package_macos.resource_declarations(self.root)


if __name__ == "__main__":
    unittest.main()
