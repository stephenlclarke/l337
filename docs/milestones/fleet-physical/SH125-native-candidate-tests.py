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


class DroneNativeCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        plan = json.loads((HERE / "SH125-native-candidate-blueprint.json").read_text())
        cls.source_path = Path(plan["originalSource"]["path"])
        cls.creator_path = Path(plan["originalCreator"]["path"])
        cls.resource_path = ROOT / plan["currentResource"]["path"]
        cls.inputs = {
            "source_bytes": cls.source_path.read_bytes(),
            "creator_bytes": cls.creator_path.read_bytes(),
            "resource_bytes": cls.resource_path.read_bytes(),
        }
        # Authenticate bytes BEFORE executing the original module's import code.
        for key, field in [("source_bytes", "originalSource"),
                           ("creator_bytes", "originalCreator"),
                           ("resource_bytes", "currentResource")]:
            if hashlib.sha256(cls.inputs[key]).hexdigest() != plan[field]["sha256"]:
                raise ValueError("Changed original candidate input: " + field)
        cls.recipe = load_module("drone_native_candidate", HERE / "SH125-native-candidate-recipe.py")
        cls.creator = load_module("drone_original_creator", cls.creator_path)
        cls.result = cls.recipe.build_candidate_native(cls.creator, **cls.inputs)

    def test_all_five_complete_parts_keep_three_slots_and_one_core(self):
        candidate = self.result["nativeCandidate"]
        parts = self.result["parts"]
        self.assertEqual([p["name"] for p in parts], [
            "closed jade shell source interval 0", "closed jade shell source interval 1",
            "closed jade shell source interval 2", "closed jade shell source interval 3",
            "single complete gold core sphere",
        ])
        intervals = [(-.65, -.2925 - .05525), (-.2925 + .05525, -.05525),
                     (.05525, .2925 - .05525), (.2925 + .05525, .65)]
        self.assertLessEqual(len(candidate["faces"]), 512)
        self.assertEqual(set(candidate["faceMaterials"]), {0, 1, 2, 3, 4})
        vertex_end = face_end = 0
        for index, part in enumerate(parts):
            self.assertEqual(part["vertexStart"], vertex_end)
            self.assertEqual(part["faceStart"], face_end)
            vertex_end += part["vertexCount"]
            face_end += part["faceCount"]
            vertices = candidate["vertices"][part["vertexStart"]:vertex_end]
            faces = candidate["faces"][part["faceStart"]:face_end]
            materials = candidate["faceMaterials"][part["faceStart"]:face_end]
            self.assertTrue(vertices and faces)
            used = {v for face in faces for v in face}
            self.assertEqual(used, set(range(part["vertexStart"], vertex_end)))
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
            self.assertEqual(visited, used, "Original part must remain connected")
            if index < 4:
                lo, hi = intervals[index]
                self.assertEqual(part["shellInterval"], [lo, hi])
                self.assertTrue(all(lo - 1e-6 <= p[1] <= hi + 1e-6 for p in vertices))
                self.assertIn(1, materials, "Actual inner/rim shadow surfaces must remain")
                self.assertTrue(set(materials).issubset({0, 1, 3, 4}))
            else:
                self.assertEqual(set(materials), {2})
                # design_dict rounds every coordinate to six decimals.
                self.assertTrue(all(abs(math.sqrt(sum(c * c for c in p)) - .59) < 2e-6
                                    for p in vertices))
        self.assertEqual(vertex_end, len(candidate["vertices"]))
        self.assertEqual(face_end, len(candidate["faces"]))
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
