"""G1-only four-Wolf-ship candidate checks; source authoring, UNEXECUTED.

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


class WolfNativeCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        plan = json.loads((HERE / "wolf-native-candidate-blueprint.json").read_text())
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
                raise ValueError("Changed own29part ownership: " + identity)
            cls.cases[identity] = dict(
                inputs=inputs, owners=json.loads(owner_bytes)["models"]["nativeDesign"]["parts"],
                original=tomllib.loads(inputs["source_bytes"].decode("utf-8"))["nativeDesign"],
                source_path=source_path, resource_path=resource_path)
        if set(cls.cases) != {"SH157", "SH158", "SH159", "SH160"}:
            raise ValueError("All four actual members must be checked")
        # Authenticate ALL shared and per-member bytes BEFORE original creator import.
        cls.recipe = load_module("wolf_native_candidate", HERE / "wolf-native-candidate-recipe.py")
        cls.creator = load_module("wolf_original_creator", Path(plan["originalCreator"]["path"]))
        for identity, case in cls.cases.items():
            case["result"] = cls.recipe.build_candidate_native(identity, cls.creator, **case["inputs"])

    def test_all_four_members_keep_their_own29parts_and_exact23fixed_sources(self):
        for identity, case in self.cases.items():
            with self.subTest(identity=identity):
                self.assertEqual(case["result"]["id"], identity)
                self.check_actual_member(case)

    def check_actual_member(self, case):
        model, parts = case["result"]["nativeCandidate"], case["result"]["parts"]
        self.assertEqual(len(parts), 29)
        self.assertEqual([p["name"] for p in parts], [p["name"] for p in case["owners"]])
        self.assertLessEqual(len(model["faces"]), 512)
        self.assertEqual(set(model["faceMaterials"]), set(case["original"]["faceMaterials"]))
        # Only these SIX original curved loft parts change angular sampling.
        # The remaining23 parts must retain every actual original source value.
        curved = {12, 17, 20, 21, 23, 24}
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

    def test_each_original_mark_keeps_body_and_cockpit_stations_and_complete_drives(self):
        for mark, identity in enumerate(["SH157", "SH158", "SH159", "SH160"]):
            with self.subTest(identity=identity):
                case = self.cases[identity]
                model, parts = case["result"]["nativeCandidate"], case["result"]["parts"]
                length = 3.8 * (1 + .035 * mark)
                body = parts[12]
                self.assertEqual(body["vertexCount"], 30)
                vertices = model["vertices"][body["vertexStart"]:body["vertexStart"] + body["vertexCount"]]
                expected_z = [length * .13 - length * .45 * .50,
                              length * .13 - length * .45 * .34,
                              length * .13 + length * .45 * .22,
                              length * .13 + length * .45 * .45,
                              length * .13 + length * .45 * .50]
                for station, z in enumerate(expected_z):
                    ring = vertices[station * 6:station * 6 + 6]
                    self.assertTrue(all(abs(p[2] - z) < 2e-6 for p in ring))
                    self.assertAlmostEqual(sum(p[0] for p in ring) / 6, 0, places=5)
                    self.assertAlmostEqual(sum(p[1] for p in ring) / 6, .03, places=5)
                self.assertEqual(parts[17]["vertexCount"], 20)
                for index in [20, 21, 23, 24]:
                    part = parts[index]
                    self.assertEqual(part["vertexCount"], 8)
                    vertices = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
                    self.assertEqual(len({p[2] for p in vertices}), 2)
                # Own exact23fixed checks include all10wells/spines/shoulders/mounts.
                # Sampling/stations alone do not prove full continuous fidelity.

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
        actual = self.cases["SH157"]["inputs"]
        for identity in ["", "Wolf", "wolf", "Wolf Scout", "SH156", "SH157-extra", "SH161"]:
            with self.subTest(alias=identity):
                with self.assertRaises(ValueError):
                    self.recipe.build_candidate_native(identity, NoGeometry(), **actual)


if __name__ == "__main__":
    unittest.main()
