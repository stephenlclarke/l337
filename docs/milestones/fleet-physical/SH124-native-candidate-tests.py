"""G1-only actual candidate checks; unexecuted development source, not native acceptance.

Run explicitly with unittest after the genuine pinned original creator is available.
Missing/changed inputs fail; there is no skip, alternate creator or primitive proxy.
"""

from collections import Counter
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import unittest


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class WarshipNativeCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        plan = json.loads((HERE / "SH124-native-candidate-blueprint.json").read_text())
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
        cls.recipe = load_module("warship_native_candidate", HERE / "SH124-native-candidate-recipe.py")
        cls.creator = load_module("warship_original_creator", cls.creator_path)
        cls.result = cls.recipe.build_candidate_native(cls.creator, **cls.inputs)

    def test_eight_parts_keep_both_lobes_four_growths_and_complete_appearance(self):
        model = self.result["nativeCandidate"]
        parts = self.result["parts"]
        self.assertEqual([p["name"] for p in parts], [
            "closed alien lobe", "existing alien end growth",
            "exact reflected copy of alien end growth", "closed alien lobe",
            "existing alien end growth", "exact reflected copy of alien end growth",
            "central alien structural growth", "alien luminous aft organ",
        ])
        self.assertEqual([p["originalMaterialIndex"] for p in parts], [0, 0, 0, 0, 0, 0, 2, 6])
        self.assertLessEqual(len(model["faces"]), 512)
        vertex_end = face_end = 0
        for part in parts:
            self.assertEqual(part["vertexStart"], vertex_end)
            self.assertEqual(part["faceStart"], face_end)
            vertex_end += part["vertexCount"]
            face_end += part["faceCount"]
            faces = model["faces"][part["faceStart"]:face_end]
            materials = model["faceMaterials"][part["faceStart"]:face_end]
            used = {v for face in faces for v in face}
            self.assertEqual(used, set(range(part["vertexStart"], vertex_end)))
            self.assertEqual(set(materials), {part["originalMaterialIndex"]})
            directed = Counter((a, b) for face in faces
                               for a, b in zip(face, face[1:] + face[:1]))
            self.assertTrue(all(n == 1 and directed[(b, a)] == 1
                                for (a, b), n in directed.items()))
            adjacency = {v: set() for v in used}
            for a, b in directed:
                adjacency[a].add(b)
                adjacency[b].add(a)
            visited, pending = set(), [next(iter(used))]
            while pending:
                vertex = pending.pop()
                if vertex not in visited:
                    visited.add(vertex)
                    pending.extend(adjacency[vertex] - visited)
            self.assertEqual(visited, used)
        self.assertEqual(vertex_end, len(model["vertices"]))
        self.assertEqual(face_end, len(model["faces"]))
        for original_index, reflected_index in [(1, 2), (4, 5)]:
            a, b = parts[original_index], parts[reflected_index]
            self.assertEqual(a["vertexCount"], b["vertexCount"])
            self.assertEqual(a["faceCount"], b["faceCount"])
            for i in range(a["vertexCount"]):
                source = model["vertices"][a["vertexStart"] + i]
                reflected = model["vertices"][b["vertexStart"] + i]
                self.assertEqual(reflected[:2], source[:2])
                self.assertAlmostEqual(reflected[2], -.20 - source[2], delta=2e-6)
            for i in range(a["faceCount"]):
                face = model["faces"][a["faceStart"] + i]
                expected = [v - a["vertexStart"] + b["vertexStart"] for v in reversed(face)]
                self.assertEqual(model["faces"][b["faceStart"] + i], expected)
        for index, centre_x in [(0, -.40), (3, .40)]:
            part = parts[index]
            vertices = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
            # The complete original centre opening remains unfilled. This vertex
            # condition alone does not prove continuous source-void fidelity.
            self.assertTrue(all(abs(p[0] - centre_x) > 0 or abs(p[2] + .10) > 0 for p in vertices))
            self.assertAlmostEqual(max(p[1] for p in vertices), .22, delta=1e-6)
            self.assertAlmostEqual(min(p[1] for p in vertices), -.22, delta=1e-6)
        self.assertEqual(len(model["faceTextures"]), len(model["faces"]))
        for face, material, texture in zip(model["faces"], model["faceMaterials"], model["faceTextures"]):
            self.assertEqual(texture["texture"], 0 if material == 0 else 2)
            self.assertEqual(len(texture["uv"]), len(face))
            self.assertTrue(all(len(uv) == 2 and all(math.isfinite(c) for c in uv)
                                for uv in texture["uv"]))
        self.assertEqual(self.source_path.read_bytes(), self.inputs["source_bytes"])
        self.assertEqual(self.resource_path.read_bytes(), self.inputs["resource_bytes"])
        self.assertEqual(self.result["status"],
                         "GENERATED_CANDIDATE_ONLY_NOT_INSTALLED_OR_NATIVE_QUALIFIED")

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
