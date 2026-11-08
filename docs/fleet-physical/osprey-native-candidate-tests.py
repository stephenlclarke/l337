"""G1-only four-Osprey candidate checks; source authoring, UNEXECUTED.

Changed/missing actual inputs fail. No skips, family substitution or proxy geometry.
"""

from collections import Counter
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import tomllib
import unittest


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class OspreyNativeCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        plan = json.loads((HERE / "osprey-native-candidate-blueprint.json").read_text())
        shared = {}
        for key, field in [("creator_bytes", "originalCreator"),
                           ("primitive_bytes", "originalPrimitive"),
                           ("family_bytes", "originalFamily")]:
            data = Path(plan[field]["path"]).read_bytes()
            if hashlib.sha256(data).hexdigest() != plan[field]["sha256"]:
                raise ValueError("Changed shared original input: " + field)
            shared[key] = data
        cls.cases = {}
        for entry in plan["entries"]:
            identity = entry["id"]
            inputs = dict(shared)
            source_path = Path(entry["originalSource"]["path"])
            resource_path = ROOT / entry["currentResource"]["path"]
            for key, field, path in [("source_bytes", "originalSource", source_path),
                                     ("resource_bytes", "currentResource", resource_path)]:
                data = path.read_bytes()
                if hashlib.sha256(data).hexdigest() != entry[field]["sha256"]:
                    raise ValueError("Changed per-ID source: " + identity + "/" + field)
                inputs[key] = data
            owner_bytes = (ROOT / entry["componentOwnership"]["path"]).read_bytes()
            if hashlib.sha256(owner_bytes).hexdigest() != entry["componentOwnership"]["sha256"]:
                raise ValueError("Changed own30part ownership: " + identity)
            cls.cases[identity] = dict(
                inputs=inputs, owners=json.loads(owner_bytes)["models"]["nativeDesign"]["parts"],
                original=tomllib.loads(inputs["source_bytes"].decode("utf-8"))["nativeDesign"],
                source_path=source_path, resource_path=resource_path)
        if set(cls.cases) != {"SH152", "SH153", "SH154", "SH155"}:
            raise ValueError("All four actual members must be checked")
        # Authenticate ALL shared and per-member bytes BEFORE original creator import.
        cls.recipe = load_module("osprey_native_candidate", HERE / "osprey-native-candidate-recipe.py")
        cls.creator = load_module("osprey_original_creator", Path(plan["originalCreator"]["path"]))
        for identity, case in cls.cases.items():
            case["result"] = cls.recipe.build_candidate_native(identity, cls.creator, **case["inputs"])

    def test_all_four_members_keep_their_own30parts_and_exact20fixed_sources(self):
        for identity, case in self.cases.items():
            with self.subTest(identity=identity):
                self.assertEqual(case["result"]["id"], identity)
                self.check_actual_member(case)

    def check_actual_member(self, case):
        model, parts = case["result"]["nativeCandidate"], case["result"]["parts"]
        self.assertEqual(len(parts), 30)
        self.assertEqual([p["name"] for p in parts], [p["name"] for p in case["owners"]])
        self.assertLessEqual(len(model["faces"]), 512)
        self.assertEqual(set(model["faceMaterials"]), set(case["original"]["faceMaterials"]))
        # Only these TEN original curved loft parts change angular sampling.
        # The remaining20 parts must retain every actual original source value.
        curved = {0, 1, 2, 7, 13, 18, 21, 22, 24, 25}
        vertex_end = face_end = 0
        for index, (part, original) in enumerate(zip(parts, case["owners"])):
            self.assertEqual(part["vertexStart"], vertex_end)
            self.assertEqual(part["faceStart"], face_end)
            vertex_end += part["vertexCount"]
            face_end += part["faceCount"]
            vertices = model["vertices"][part["vertexStart"]:vertex_end]
            faces = model["faces"][part["faceStart"]:face_end]
            materials = model["faceMaterials"][part["faceStart"]:face_end]
            self.assertTrue(vertices and faces)
            self.assertEqual(set(materials), {p["material"] for p in original["exactMaterialRuns"]})
            used = {v for face in faces for v in face}
            self.assertEqual(used, set(range(part["vertexStart"], vertex_end)))
            directed = Counter((a, b) for face in faces
                               for a, b in zip(face, face[1:] + face[:1]))
            self.assertTrue(all(n == 1 and directed[(b, a)] == 1
                                for (a, b), n in directed.items()))
            if index not in curved:
                v0, f0 = original["vertexStart"], original["faceStart"]
                v1, f1 = v0 + original["vertexCount"], f0 + original["faceCount"]
                self.assertEqual(vertices, case["original"]["vertices"][v0:v1])
                local = [[v - part["vertexStart"] for v in face] for face in faces]
                expected = [[v - v0 for v in face] for face in case["original"]["faces"][f0:f1]]
                self.assertEqual(local, expected)
                self.assertEqual(materials, case["original"]["faceMaterials"][f0:f1])
                self.assertEqual(model["faceTextures"][part["faceStart"]:face_end],
                                 case["original"]["faceTextures"][f0:f1])
        self.assertEqual(vertex_end, len(model["vertices"]))
        self.assertEqual(face_end, len(model["faces"]))
        self.assertEqual(len(model["faceTextures"]), len(model["faces"]))
        for face, material, texture in zip(model["faces"], model["faceMaterials"], model["faceTextures"]):
            self.assertEqual(texture["texture"], 0 if material == 0 else 2)
            self.assertEqual(len(texture["uv"]), len(face))
            self.assertTrue(all(len(uv) == 2 and all(math.isfinite(c) for c in uv)
                                for uv in texture["uv"]))
        resource = tomllib.loads(case["inputs"]["resource_bytes"].decode("utf-8"))
        self.assertIn("game", resource)
        self.assertEqual(resource["catalogue"]["objectKind"], "ship")
        self.assertEqual(case["source_path"].read_bytes(), case["inputs"]["source_bytes"])
        self.assertEqual(case["resource_path"].read_bytes(), case["inputs"]["resource_bytes"])
        self.assertEqual(case["result"]["status"],
                         "GENERATED_CANDIDATE_ONLY_NOT_INSTALLED_OR_NATIVE_QUALIFIED")

    def test_all_four_original_marks_keep_all_four_pod_profiles_and_full_drive_rings(self):
        for identity, mark in [("SH152", 0), ("SH153", 1), ("SH154", 2), ("SH155", 3)]:
            with self.subTest(identity=identity):
                case = self.cases[identity]
                model, parts = case["result"]["nativeCandidate"], case["result"]["parts"]
                length, beam = 3.9 * (1 + .035 * mark), 2.40 * (1 + .025 * mark)
                profiles = [(2, (-beam * .36, -.10, -length * .02), length * .90, .22, .22 * .72),
                            (7, (beam * .36, -.10, -length * .02), length * .90, .22, .22 * .72),
                            (13, (0, .17, -length * .10), length * .53, .27, .23),
                            (18, (0, .55, length * .06), .51, .23, .23 * .55)]
                for index, (x, y, z), pod_length, width, height in profiles:
                    part = parts[index]
                    self.assertEqual(part["vertexCount"], 15)
                    vertices = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
                    stations = [(z - pod_length * .50, width * .52, height * .52),
                                (z - pod_length * .34, width, height),
                                (z + pod_length * .22, width * .93, height * .94),
                                (z + pod_length * .45, width * .55, height * .57),
                                (z + pod_length * .50, width * .20, height * .25)]
                    for station, (expected_z, rx, ry) in enumerate(stations):
                        ring = vertices[station * 3:station * 3 + 3]
                        self.assertAlmostEqual(sum(p[0] for p in ring) / 3, x, places=5)
                        self.assertAlmostEqual(sum(p[1] for p in ring) / 3, y, places=5)
                        for p in ring:
                            self.assertAlmostEqual(p[2], expected_z, places=5)
                            # Error bound derives only from original six-decimal serialization.
                            self.assertAlmostEqual(math.hypot((p[0] - x) * ry, (p[1] - y) * rx),
                                                   rx * ry, delta=.0000005 * math.hypot(rx, ry) + 1e-12)
                for side, casing, recess in [(-1, 21, 22), (1, 24, 25)]:
                    x, z, radius = side * beam * .38, -length * .43, .23
                    profiles = [(casing, [(z - .10, radius), (z + .18, radius * 1.13)]),
                                (recess, [(z - .118, radius * .70), (z - .105, radius * .70)])]
                    for index, rings in profiles:
                        part = parts[index]
                        self.assertEqual(part["vertexCount"], 6)
                        vertices = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
                        for ring, (expected_z, expected_radius) in enumerate(rings):
                            for p in vertices[ring * 3:ring * 3 + 3]:
                                self.assertAlmostEqual(p[2], expected_z, places=5)
                                self.assertAlmostEqual(math.hypot(p[0] - x, p[1]), expected_radius, places=5)
                # Exact20fixed checks include ALL12wells/bridge/ALL4mounts/supports.
                # All-triangular curved components may fail full source/void fidelity.

    def test_both_original_half_booms_keep_caps_gap_rotation_offsets_and_extrema(self):
        for identity, mark in [("SH152", 0), ("SH153", 1), ("SH154", 2), ("SH155", 3)]:
            with self.subTest(identity=identity):
                result = self.cases[identity]["result"]
                model = result["nativeCandidate"]
                length, beam = 3.9 * (1 + .035 * mark), 2.40 * (1 + .025 * mark)
                for index, side in [(0, -1), (1, 1)]:
                    part = result["parts"][index]
                    self.assertEqual(part["name"], "arched connected boom")
                    self.assertEqual(part["vertexCount"], 12)
                    vertices = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
                    faces = model["faces"][part["faceStart"]:part["faceStart"] + part["faceCount"]]
                    first = set(range(part["vertexStart"], part["vertexStart"] + 4))
                    last = set(range(part["vertexStart"] + 8, part["vertexStart"] + 12))
                    self.assertEqual(sum(set(face).issubset(first) for face in faces), 2)
                    self.assertEqual(sum(set(face).issubset(last) for face in faces), 2)
                    self.assertFalse(any(set(face) & first and set(face) & last for face in faces))
                    self.assertTrue(all(p[2] < 0 for p in vertices[:4]))
                    self.assertTrue(all(p[2] > 0 for p in vertices[-4:]))
                    self.assertTrue(all(abs(p[1] - .10) < 2e-6 for p in vertices[:4] + vertices[-4:]))
                    self.assertAlmostEqual(min(p[0] for p in vertices), side * beam * .36 - .14, places=5)
                    self.assertAlmostEqual(max(p[0] for p in vertices), side * beam * .36 + .14, places=5)
                    self.assertAlmostEqual(max(p[1] for p in vertices), .10 + .65 + .14, places=5)
                    self.assertAlmostEqual(min(p[2] for p in vertices), -(length * .44 + .14), places=5)
                    self.assertAlmostEqual(max(p[2] for p in vertices), length * .44 + .14, places=5)
                # The two-span boom polygon may fail continuous curved-source fidelity.

    def test_changed_inputs_and_other_member_sources_refuse_before_geometry(self):
        class NoGeometry:
            def __getattr__(self, name):
                raise AssertionError("Untrusted source reached geometry: " + name)
        for identity, case in self.cases.items():
            for key in case["inputs"]:
                with self.subTest(identity=identity, key=key):
                    changed = dict(case["inputs"])
                    changed[key] += b"\n"
                    with self.assertRaises(ValueError):
                        self.recipe.build_candidate_native(identity, NoGeometry(), **changed)
            other = next(c for key, c in self.cases.items() if key != identity)
            for key in ["source_bytes", "resource_bytes"]:
                changed = dict(case["inputs"])
                changed[key] = other["inputs"][key]
                with self.subTest(identity=identity, wrongMember=key):
                    with self.assertRaises(ValueError):
                        self.recipe.build_candidate_native(identity, NoGeometry(), **changed)
        actual = self.cases["SH152"]["inputs"]
        for identity in ["", "Osprey", "osprey", "Osprey Carrier", "SH151", "SH156", "SH152-extra"]:
            with self.subTest(alias=identity):
                with self.assertRaises(ValueError):
                    self.recipe.build_candidate_native(identity, NoGeometry(), **actual)


if __name__ == "__main__":
    unittest.main()
