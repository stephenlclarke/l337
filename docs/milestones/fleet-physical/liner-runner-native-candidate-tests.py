"""G1-only two-actual-open-arc candidate checks; source authoring, UNEXECUTED.

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


class ArcLinerRunnerNativeCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        plan = json.loads((HERE / "liner-runner-native-candidate-blueprint.json").read_text())
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
                raise ValueError("Changed own16part ownership: " + identity)
            cls.cases[identity] = dict(
                entry=entry, inputs=inputs, owners=json.loads(owner_bytes)["models"]["nativeDesign"]["parts"],
                original=tomllib.loads(inputs["source_bytes"].decode("utf-8"))["nativeDesign"],
                source_path=source_path, resource_path=resource_path)
        if set(cls.cases) != {"SH088", "SH089"}:
            raise ValueError("Both actual entries must be checked")
        # Authenticate ALL shared and per-member bytes BEFORE original creator import.
        cls.recipe = load_module("actual_arc_native_candidate", HERE / "liner-runner-native-candidate-recipe.py")
        cls.creator = load_module("actual_arc_original_creator", Path(plan["originalCreator"]["path"]))
        for identity, case in cls.cases.items():
            case["result"] = cls.recipe.build_candidate_native(identity, cls.creator, **case["inputs"])

    def test_both_actual_entries_keep_own16parts_and_exact9fixed_sources(self):
        for identity, case in self.cases.items():
            with self.subTest(identity=identity):
                self.assertEqual(case["result"]["id"], identity)
                self.check_actual_member(case)

    def check_actual_member(self, case):
        model, parts = case["result"]["nativeCandidate"], case["result"]["parts"]
        self.assertEqual(len(parts), 16)
        self.assertEqual([p["name"] for p in parts], [p["name"] for p in case["owners"]])
        self.assertLessEqual(len(model["faces"]), 512)
        self.assertEqual(set(model["faceMaterials"]), set(case["original"]["faceMaterials"]))
        # Only these SEVEN original curved parts (open arc and six lofts) change angular sampling.
        # The remaining9 parts must retain every actual original source value.
        curved = {0, 1, 8, 11, 12, 14, 15}
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

    def test_both_actual_arcs_keep_their_own_gap_endplanes_and_two_caps(self):
        for identity, case in self.cases.items():
            with self.subTest(identity=identity):
                model, part = case["result"]["nativeCandidate"], case["result"]["parts"][0]
                self.assertEqual(part["name"], "open curved loop")
                vertices = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
                faces = model["faces"][part["faceStart"]:part["faceStart"] + part["faceCount"]]
                first = set(range(part["vertexStart"], part["vertexStart"] + 4))
                last = set(range(part["vertexStart"] + part["vertexCount"] - 4,
                                 part["vertexStart"] + part["vertexCount"]))
                self.assertEqual(sum(set(face).issubset(first) for face in faces), 2)
                self.assertEqual(sum(set(face).issubset(last) for face in faces), 2)
                self.assertFalse(any(set(face) & first and set(face) & last for face in faces))
                self.assertTrue(all(p[0] < 0 for p in vertices[:4]))
                self.assertTrue(all(p[0] > 0 for p in vertices[-4:]))
                length, beam = case["entry"]["originalRecipe"]["length"], case["entry"]["originalRecipe"]["beam"]
                for row, angle in [(vertices[:4], math.pi / 2 + .25),
                                   (vertices[-4:], math.pi / 2 + math.tau - .25)]:
                    x, z = beam * .46 * math.cos(angle), length * .44 * math.sin(angle)
                    self.assertTrue(all(abs((p[0] - x) * math.sin(angle)
                                            - (p[2] - z) * math.cos(angle)) < 2e-6 for p in row))

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
        actual = self.cases["SH088"]["inputs"]
        for identity in ["", "Springbok Starliner", "Antelope", "springbok", "SH087", "SH088-extra"]:
            with self.subTest(alias=identity):
                with self.assertRaises(ValueError):
                    self.recipe.build_candidate_native(identity, NoGeometry(), **actual)


if __name__ == "__main__":
    unittest.main()
