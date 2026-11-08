"""G1 only: genuine actual50084 cache inputs; no generator/owned113-test rerun."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("candidate_input_bridge", ROOT / "Tools/prepare-original-fleet-candidate-qualification.py")
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class OriginalFleetCandidateQualificationInputTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan_path = ROOT / "docs/fleet-physical/actual55-candidate-qualification-inputs.json"
        cls.plan = bridge.load_plan(cls.plan_path)
        cls.terminal = Path(cls.plan["terminalRoot"])
        cls.row = next(row for row in cls.plan["rows"] if row["id"] == "SH125")
        cls.cached = bridge.decode_json(bridge.checked_bytes(cls.terminal / cls.row["cache"]["path"], cls.row["cache"]))
        cls.original = tomllib.loads(bridge.checked_bytes(bridge.source_path(ROOT, cls.row["originalSource"]), cls.row["originalSource"]).decode())
        cls.resource = tomllib.loads(bridge.checked_bytes(bridge.source_path(ROOT, cls.row["currentResource"]), cls.row["currentResource"]).decode())

    def test_all_actual55_bridge_to_unchanged_paired_native_fields_without_adoption(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "inspection"
            result = bridge.prepare(self.plan_path, ROOT, output)
            self.assertEqual(result["jobs"], 55)
            self.assertFalse(result["runtimeActivation"])
            self.assertEqual(result["acceptedHulls"], 0)
            manifest = bridge.decode_json((output / "manifest.json").read_bytes())
            self.assertEqual(manifest["kind"], bridge.KIND)
            self.assertEqual(len(manifest["jobs"]), 55)
            by_id = {row["id"]:row for row in self.plan["rows"]}
            self.assertEqual(set(by_id), {job["id"] for job in manifest["jobs"]})
            for job in manifest["jobs"]:
                row = by_id[job["id"]]
                original_cache = bridge.decode_json(bridge.checked_bytes(self.terminal / row["cache"]["path"], row["cache"]))
                exported = bridge.decode_json((output / job["candidate"]["file"]).read_bytes())
                self.assertEqual(exported["nativeDesign"], original_cache["nativeCandidate"])
                self.assertEqual(exported["sourceSHA256"], row["cache"]["sha256"])
                self.assertEqual(exported["sourcePath"], row["cache"]["path"])
                self.assertNotEqual(exported["sourceSHA256"], row["originalSource"]["sha256"])
                self.assertEqual(bridge.fan_triangles(exported["nativeDesign"]["faces"]),
                                 sum(len(face)-2 for face in exported["nativeDesign"]["faces"]))
            with self.assertRaises(ValueError):
                bridge.prepare(self.plan_path, ROOT, output)

    def test_bad_identity_source_r3_status_refuse_before_native_validation(self):
        def no_validation(*args):
            raise AssertionError("Invalid envelope reached native geometry")
        for key, wrong in [("id","SH124"),("originalSourceSHA256","0"*64),
                           ("r3SHA256","0"*64),("status","QUALIFIED")]:
            with self.subTest(key=key):
                changed = dict(self.cached)
                changed[key] = wrong
                with self.assertRaises(ValueError):
                    bridge.validate_cached(changed, self.row, self.original, self.resource, no_validation)

    def test_fan_triangle_cap_is_not_source_polygon_count(self):
        face = self.cached["nativeCandidate"]["faces"][0]
        self.assertEqual(bridge.fan_triangles([face + [face[0]]]), 2)
        changed = copy.deepcopy(self.cached)
        changed["nativeCandidate"]["faces"] = [list(face) for _ in range(513)]
        with self.assertRaisesRegex(ValueError, "512 fan triangles"):
            bridge.validate_cached(changed, self.row, self.original, self.resource,
                                   lambda *args: self.fail("Over-cap reached validator"))

    def test_changed_appearance_missing_part_and_duplicate_json_refuse(self):
        changed = copy.deepcopy(self.cached)
        changed["nativeCandidate"]["license"] += " changed"
        with self.assertRaises(ValueError):
            bridge.validate_cached(changed, self.row, self.original, self.resource,
                                   lambda *args:self.fail("Changed metadata reached validator"))
        changed = copy.deepcopy(self.cached)
        changed["parts"].pop()
        with self.assertRaises(ValueError):
            bridge.validate_cached(changed, self.row, self.original, self.resource,
                                   lambda *args:self.fail("Missing part reached validator"))
        with self.assertRaises(ValueError):
            bridge.decode_json(b'{"id":"SH125","id":"SH124"}')
        with self.assertRaises(ValueError):
            bridge.decode_json(b'{"value":NaN}')


if __name__ == "__main__":
    unittest.main()
