"""G1-only three-Peregrine-peer candidate checks; source authoring, UNEXECUTED.

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


class PeregrinePeerNativeCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        plan = json.loads((HERE / "peregrine-peer-native-candidate-blueprint.json").read_text())
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
                raise ValueError("Changed own27part ownership: " + identity)
            cls.cases[identity] = dict(
                inputs=inputs, owners=json.loads(owner_bytes)["models"]["nativeDesign"]["parts"],
                original=tomllib.loads(inputs["source_bytes"].decode("utf-8"))["nativeDesign"],
                source_path=source_path, resource_path=resource_path)
        if set(cls.cases) != {"SH022", "SH023", "SH024"}:
            raise ValueError("All three actual members must be checked")
        # Authenticate ALL shared and per-member bytes BEFORE original creator import.
        cls.recipe = load_module("peregrine_peer_native_candidate", HERE / "peregrine-peer-native-candidate-recipe.py")
        cls.creator = load_module("peregrine_peer_original_creator", Path(plan["originalCreator"]["path"]))
        for identity, case in cls.cases.items():
            case["result"] = cls.recipe.build_candidate_native(identity, cls.creator, **case["inputs"])

    def test_all_three_members_keep_their_own27parts_and_exact19fixed_sources(self):
        for identity, case in self.cases.items():
            with self.subTest(identity=identity):
                self.assertEqual(case["result"]["id"], identity)
                self.check_actual_member(case)

    def check_actual_member(self, case):
        model, parts = case["result"]["nativeCandidate"], case["result"]["parts"]
        self.assertEqual(len(parts), 27)
        self.assertEqual([p["name"] for p in parts], [p["name"] for p in case["owners"]])
        self.assertLessEqual(len(model["faces"]), 512)
        self.assertEqual(set(model["faceMaterials"]), set(case["original"]["faceMaterials"]))
        # Only these EIGHT original curved loft parts change angular sampling.
        # The remaining19 parts must retain every actual original source value.
        curved = {0, 5, 13, 19, 22, 23, 25, 26}
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

    def test_own_mark_preserves_all_three_pod_profiles_and_original_drive_rings_radii(self):
        for mark, identity in enumerate(["SH022", "SH023", "SH024"]):
            with self.subTest(identity=identity):
                case = self.cases[identity]
                model, parts = case["result"]["nativeCandidate"], case["result"]["parts"]
                length = 3.2 * (1 + .035 * mark)
                beam = 2.15 * (1 + .025 * mark)
                profiles = [(0, (-beam * .34, -.10, 0), length * .91, beam * .20, beam * .20 * .72),
                            (5, (beam * .34, -.10, 0), length * .91, beam * .20, beam * .20 * .72),
                            (13, (0, .28, -length * .11), length * .55, .28, .23)]
                for index, (x, y, z), pod_length, width, height in profiles:
                    part = parts[index]
                    self.assertEqual(part["vertexCount"], 20)
                    vertices = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
                    stations = [(z - pod_length * .50, width * .52, height * .52),
                                (z - pod_length * .34, width, height),
                                (z + pod_length * .22, width * .93, height * .94),
                                (z + pod_length * .45, width * .55, height * .57),
                                (z + pod_length * .50, width * .20, height * .25)]
                    for station, (expected_z, rx, ry) in enumerate(stations):
                        ring = vertices[station * 4:station * 4 + 4]
                        self.assertTrue(all(abs(p[2] - expected_z) < 2e-6 for p in ring))
                        self.assertAlmostEqual(min(p[0] for p in ring), x - rx, places=5)
                        self.assertAlmostEqual(max(p[0] for p in ring), x + rx, places=5)
                        self.assertAlmostEqual(min(p[1] for p in ring), y - ry, places=5)
                        self.assertAlmostEqual(max(p[1] for p in ring), y + ry, places=5)
                self.assertEqual(parts[19]["vertexCount"], 20)
                for side, casing, recess in [(-1, 22, 23), (1, 25, 26)]:
                    x, z, radius = side * beam * .38, -length * .43, .23
                    drives = [(casing, [(z - .10, radius), (z + .18, radius * 1.13)]),
                              (recess, [(z - .118, radius * .70), (z - .105, radius * .70)])]
                    for index, rings in drives:
                        part = parts[index]
                        self.assertEqual(part["vertexCount"], 6)
                        vertices = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
                        for ring, (expected_z, expected_radius) in enumerate(rings):
                            for p in vertices[ring * 3:ring * 3 + 3]:
                                self.assertAlmostEqual(p[2], expected_z, places=5)
                                self.assertAlmostEqual(math.hypot(p[0] - x, p[1]), expected_radius, places=5)
                # Exact19fixed includes BOTH shoulders, ALL12wells and full lowerprow.
                # Triangular drive sampling may fail full fidelity; no native PASS.

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
        actual = self.cases["SH022"]["inputs"]
        for identity in ["", "Peregrine", "peregrine", "Peregrine Mk I", "SH021", "SH022-extra", "SH025"]:
            with self.subTest(alias=identity):
                with self.assertRaises(ValueError):
                    self.recipe.build_candidate_native(identity, NoGeometry(), **actual)


if __name__ == "__main__":
    unittest.main()
