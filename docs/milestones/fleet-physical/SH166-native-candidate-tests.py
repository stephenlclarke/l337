"""G1-only actual candidate checks; unexecuted development source, not native acceptance.

Run explicitly with unittest after the genuine pinned original creator is available.
Missing/changed inputs fail; there is no skip, alternate creator or primitive proxy.
"""

from collections import Counter
import hashlib
import importlib.util
import json
import math
import tomllib
from pathlib import Path
import unittest


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class CamelRescueNativeCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        plan = json.loads((HERE / "SH166-native-candidate-blueprint.json").read_text())
        cls.source_path = Path(plan["originalSource"]["path"])
        cls.creator_path = Path(plan["originalCreator"]["path"])
        cls.resource_path = ROOT / plan["currentResource"]["path"]
        cls.inputs = {
            "source_bytes": cls.source_path.read_bytes(),
            "creator_bytes": cls.creator_path.read_bytes(),
            "resource_bytes": cls.resource_path.read_bytes(),
            "primitive_bytes": Path(plan["originalPrimitive"]["path"]).read_bytes(),
        }
        # Authenticate bytes BEFORE executing the original module's import code.
        for key, field in [("source_bytes", "originalSource"),
                           ("creator_bytes", "originalCreator"),
                           ("resource_bytes", "currentResource"),
                           ("primitive_bytes", "originalPrimitive")]:
            if hashlib.sha256(cls.inputs[key]).hexdigest() != plan[field]["sha256"]:
                raise ValueError("Changed original candidate input: " + field)
        owner_bytes = (ROOT / plan["componentOwnership"]["path"]).read_bytes()
        if hashlib.sha256(owner_bytes).hexdigest() != plan["componentOwnership"]["sha256"]:
            raise ValueError("Changed original29part ownership input")
        cls.owners = json.loads(owner_bytes)["models"]["nativeDesign"]["parts"]
        cls.recipe = load_module("camel_rescue_native_candidate", HERE / "SH166-native-candidate-recipe.py")
        cls.creator = load_module("camel_rescue_original_creator", cls.creator_path)
        cls.original = tomllib.loads(cls.inputs["source_bytes"].decode("utf-8"))["nativeDesign"]
        cls.result = cls.recipe.build_candidate_native(cls.creator, **cls.inputs)

    def test_all29_parts_preserve_every_fixed_source_vertex_face_material_and_uv(self):
        model, parts = self.result["nativeCandidate"], self.result["parts"]
        self.assertEqual(len(parts), 29)
        self.assertEqual([p["name"] for p in parts], [p["name"] for p in self.owners])
        self.assertLessEqual(len(model["faces"]), 512)
        self.assertEqual(set(model["faceMaterials"]), set(self.original["faceMaterials"]))
        # Only these EIGHT original curved loft parts change angular sampling.
        # The remaining21 parts must retain every actual original source value.
        curved = {0, 5, 16, 21, 24, 25, 27, 28}
        vertex_end = face_end = 0
        for index, (part, original) in enumerate(zip(parts, self.owners)):
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
                self.assertEqual(vertices, self.original["vertices"][v0:v1])
                local = [[v - part["vertexStart"] for v in face] for face in faces]
                expected = [[v - v0 for v in face] for face in self.original["faces"][f0:f1]]
                self.assertEqual(local, expected)
                self.assertEqual(materials, self.original["faceMaterials"][f0:f1])
                self.assertEqual(model["faceTextures"][part["faceStart"]:face_end],
                                 self.original["faceTextures"][f0:f1])
        self.assertEqual(vertex_end, len(model["vertices"]))
        self.assertEqual(face_end, len(model["faces"]))
        self.assertEqual(len(model["faceTextures"]), len(model["faces"]))
        for face, material, texture in zip(model["faces"], model["faceMaterials"], model["faceTextures"]):
            self.assertEqual(texture["texture"], 0 if material == 0 else 2)
            self.assertEqual(len(texture["uv"]), len(face))
            self.assertTrue(all(len(uv) == 2 and all(math.isfinite(c) for c in uv)
                                for uv in texture["uv"]))
        resource = tomllib.loads(self.inputs["resource_bytes"].decode("utf-8"))
        self.assertIn("game", resource)
        self.assertEqual(resource["catalogue"]["objectKind"], "ship")
        self.assertEqual(self.source_path.read_bytes(), self.inputs["source_bytes"])
        self.assertEqual(self.resource_path.read_bytes(), self.inputs["resource_bytes"])
        self.assertEqual(self.result["status"],
                         "GENERATED_CANDIDATE_ONLY_NOT_INSTALLED_OR_NATIVE_QUALIFIED")

    def test_all_pods_keep_own_five_station_radii_and_original_offsets(self):
        model = self.result["nativeCandidate"]
        length, beam = 3.1, 2.10
        profiles = [(0, 3, (-beam * .40, -.10, 0), length * .82, .18, .18 * .72),
                    (5, 3, (beam * .40, -.10, 0), length * .82, .18, .18 * .72),
                    (16, 4, (0, 0, -length * .14), length * .66, .38, .26)]
        for index, angular, (x, y, z), pod_length, width, height in profiles:
            part = self.result["parts"][index]
            self.assertEqual(part["vertexCount"], angular * 5)
            vertices = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
            stations = [(z - pod_length * .50, width * .52, height * .52),
                        (z - pod_length * .34, width, height),
                        (z + pod_length * .22, width * .93, height * .94),
                        (z + pod_length * .45, width * .55, height * .57),
                        (z + pod_length * .50, width * .20, height * .25)]
            for station, (expected_z, rx, ry) in enumerate(stations):
                ring = vertices[station * angular:station * angular + angular]
                self.assertAlmostEqual(sum(p[0] for p in ring) / angular, x, places=5)
                self.assertAlmostEqual(sum(p[1] for p in ring) / angular, y, places=5)
                for p in ring:
                    self.assertAlmostEqual(p[2], expected_z, places=5)
                    # Genuine serializer rounds each coordinate to six decimals.
                    # Bound the scaled-ellipse norm error from that rounding only.
                    self.assertAlmostEqual(math.hypot((p[0] - x) * ry, (p[1] - y) * rx),
                                           rx * ry, delta=.0000005 * math.hypot(rx, ry) + 1e-12)
        self.assertEqual(self.result["parts"][21]["vertexCount"], 20)
        # Triangular sidepod surfaces may fail continuous source/void fidelity.

    def test_all_drive_parts_keep_original_two_rings_and_source_radii(self):
        model = self.result["nativeCandidate"]
        for side, casing, recess in [(-1, 24, 25), (1, 27, 28)]:
            x, z, radius = side * 2.10 * .38, -3.1 * .43, .23
            profiles = [(casing, [(z - .10, radius), (z + .18, radius * 1.13)]),
                        (recess, [(z - .118, radius * .70), (z - .105, radius * .70)])]
            for index, rings in profiles:
                part = self.result["parts"][index]
                self.assertEqual(part["vertexCount"], 6)
                vertices = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
                for ring, (expected_z, expected_radius) in enumerate(rings):
                    for p in vertices[ring * 3:ring * 3 + 3]:
                        self.assertAlmostEqual(p[2], expected_z, places=5)
                        self.assertAlmostEqual(math.hypot(p[0] - x, p[1]), expected_radius, places=5)
        # Exact21fixed checks include ALL12wells and ALL SIX complete dock pieces.
        # None of these checks proves operating rescue/dock/propulsion authority.

    def test_changed_real_inputs_refuse_before_geometry(self):
        class NoGeometry:
            def __getattr__(self, name):
                raise AssertionError("Changed input reached geometry: " + name)
        for key in self.inputs:
            with self.subTest(key=key):
                changed = dict(self.inputs)
                changed[key] += b"\n"
                with self.assertRaises(ValueError):
                    self.recipe.build_candidate_native(NoGeometry(), **changed)


if __name__ == "__main__":
    unittest.main()
