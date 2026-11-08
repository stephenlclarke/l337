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


class YakNativeCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        plan = json.loads((HERE / "SH050-native-candidate-blueprint.json").read_text())
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
        cls.recipe = load_module("yak_native_candidate", HERE / "SH050-native-candidate-recipe.py")
        cls.creator = load_module("yak_original_creator", cls.creator_path)
        owner_bytes = (ROOT / plan["componentOwnership"]["path"]).read_bytes()
        if hashlib.sha256(owner_bytes).hexdigest() != plan["componentOwnership"]["sha256"]:
            raise ValueError("Changed original24part ownership input")
        cls.owners = json.loads(owner_bytes)["models"]["nativeDesign"]["parts"]
        cls.original = tomllib.loads(cls.inputs["source_bytes"].decode("utf-8"))["nativeDesign"]
        cls.result = cls.recipe.build_candidate_native(cls.creator, **cls.inputs)

    def test_all24_parts_preserve_every_fixed_source_vertex_face_material_and_uv(self):
        model, parts = self.result["nativeCandidate"], self.result["parts"]
        self.assertEqual(len(parts), 24)
        self.assertEqual([p["name"] for p in parts], [p["name"] for p in self.owners])
        self.assertLessEqual(len(model["faces"]), 512)
        self.assertEqual(set(model["faceMaterials"]), set(self.original["faceMaterials"]))
        # Only these EIGHT curved lofts change angular sampling. ALL16 fixed
        # components, including ALL12 original wells, remain exact source.
        curved = {0, 5, 10, 16, 19, 20, 22, 23}
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

    def test_all_three_stacked_pods_keep_original_five_stations_and_heights(self):
        model = self.result["nativeCandidate"]
        expected_z = [-4.1 * .50, -4.1 * .34, 4.1 * .22, 4.1 * .45, 4.1 * .50]
        for index, y in [(0, -.50), (5, 0), (10, .50)]:
            part = self.result["parts"][index]
            self.assertEqual(part["vertexCount"], 20)
            vertices = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
            self.assertEqual(len({p[2] for p in vertices}), 5)
            for station, z in enumerate(expected_z):
                ring = vertices[station * 4:station * 4 + 4]
                self.assertTrue(all(abs(p[2] - z) < 2e-6 for p in ring))
                self.assertAlmostEqual(sum(p[1] for p in ring) / 4, y, places=5)
        part = self.result["parts"][16]
        self.assertEqual(part["vertexCount"], 20)
        for index in [19, 20, 22, 23]:
            part = self.result["parts"][index]
            self.assertEqual(part["vertexCount"], 8)
            vertices = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
            self.assertEqual(len({p[2] for p in vertices}), 2)
        # Stations/stack heights alone never establish full curved-source fidelity.

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
