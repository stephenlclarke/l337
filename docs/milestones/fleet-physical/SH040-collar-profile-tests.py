"""G1-only nine-part capsule source tests; no native/physical/fidelity acceptance."""
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
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class NewtCapsuleNativeCandidateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        plan = json.loads((HERE / "SH040-collar-profile-blueprint.json").read_text())
        fields = {"source_bytes": "sourceGeometry", "creator_bytes": "originalCreator",
                  "primitive_bytes": "originalPrimitive", "resource_bytes": "currentResource"}
        cls.inputs = {}
        for key, field in fields.items():
            pin = plan[field]
            path = Path(pin["path"])
            path = path if path.is_absolute() else ROOT / path
            raw = path.read_bytes()
            if len(raw) != pin["bytes"] or hashlib.sha256(raw).hexdigest() != pin["sha256"]:
                raise ValueError("Changed actual capsule input: " + field)
            cls.inputs[key] = raw
        # Authenticate test/recipe/ownership/R3 bytes before importing either target module.
        for field in ["recipe", "tests", "originalOwnership", "currentR3Implementation"]:
            pin = plan[field]
            raw = (ROOT / pin["path"]).read_bytes()
            if len(raw) != pin["bytes"] or hashlib.sha256(raw).hexdigest() != pin["sha256"]:
                raise ValueError("Changed capsule source evidence: " + field)
        cls.source = tomllib.loads(cls.inputs["source_bytes"].decode())
        cls.resource = tomllib.loads(cls.inputs["resource_bytes"].decode())
        cls.ownership = json.loads((ROOT / plan["originalOwnership"]["path"]).read_text())
        cls.recipe = load_module("current_newt_native_recipe", HERE / plan["recipe"]["path"].split("/")[-1])
        cls.creator = load_module("actual_newt_original_creator", Path(plan["originalCreator"]["path"]))
        cls.result = cls.recipe.build_candidate_native(cls.creator, **cls.inputs)

    def test_nine_own_parts_capsule_domain_and_full_appearance_without_occupied_authority(self):
        result = self.result
        model = result["nativeCandidate"]
        self.assertEqual(result["id"], "SH040")
        self.assertEqual(result["objectKind"], "capsule")
        self.assertEqual(result["declaredNativeCrew"], 1)
        self.assertEqual(result["declaredConversionCrew"], 1)
        self.assertTrue(result["occupants"].startswith("UNISSUED"))
        self.assertEqual(self.resource["name"], "Newt Escape Pod")
        self.assertEqual(self.resource["catalogue"]["aliases"], [])
        self.assertFalse(self.resource["catalogue"]["playerFlyable"])
        self.assertEqual(self.resource["catalogue"]["purchasePolicy"], "never")
        for key in ["cargo", "fuel", "jump", "spool", "missiles", "facings", "cargoExpansion", "price"]:
            self.assertEqual(self.resource["game"][key], 0)
        self.assertEqual(self.resource["game"]["workTools"], [])
        self.assertEqual([p["name"] for p in result["parts"]], [
            "body primary pressure envelope", "cockpit glazing envelope",
            "cockpit connected structural crossmember", "seed circumferential collar",
            "seed circumferential collar", "seed explicit drive 0/propulsion casing",
            "seed explicit drive 0/propulsion luminous recess", "seed explicit drive 1/propulsion casing",
            "seed explicit drive 1/propulsion luminous recess"])
        self.assertEqual([p["originalMaterialIndex"] for p in result["parts"]], [0, 5, 2, 2, 2, 1, 6, 1, 6])
        self.assertTrue(all(len(face) == 3 for face in model["faces"]))
        self.assertLessEqual(sum(len(face) - 2 for face in model["faces"]), 512)
        vertex_end = face_end = 0
        for part in result["parts"]:
            self.assertEqual((part["vertexStart"], part["faceStart"]), (vertex_end, face_end))
            vertex_end += part["vertexCount"]
            face_end += part["faceCount"]
            faces = model["faces"][part["faceStart"]:face_end]
            self.assertEqual(set(model["faceMaterials"][part["faceStart"]:face_end]), {part["originalMaterialIndex"]})
            used = {v for face in faces for v in face}
            self.assertEqual(used, set(range(part["vertexStart"], vertex_end)))
            edges = Counter((a, b) for face in faces for a, b in zip(face, face[1:] + face[:1]))
            self.assertTrue(all(count == 1 and edges[(b, a)] == 1 for (a, b), count in edges.items()))
            neighbours = {v: set() for v in used}
            for a, b in edges:
                neighbours[a].add(b)
                neighbours[b].add(a)
            seen, pending = set(), [next(iter(used))]
            while pending:
                vertex = pending.pop()
                if vertex not in seen:
                    seen.add(vertex)
                    pending.extend(neighbours[vertex] - seen)
            self.assertEqual(seen, used)
        self.assertEqual((vertex_end, face_end), (len(model["vertices"]), len(model["faces"])))
        original = self.source["nativeDesign"]
        for key in original.keys() - {"vertices", "faces", "faceMaterials", "faceTextures"}:
            self.assertEqual(model[key], original[key])
        self.assertEqual(set(model["faceMaterials"]), set(original["faceMaterials"]))
        self.assertEqual(result["status"], "GENERATED_CANDIDATE_ONLY_NOT_INSTALLED_OR_NATIVE_QUALIFIED")

    def test_original_stations_fixed_crossmember_both_closed_collars_and_full_uv(self):
        model = self.result["nativeCandidate"]
        original = self.source["nativeDesign"]
        source_parts = self.ownership["models"]["nativeDesign"]["parts"]
        # Original resource1188 is a source metadata fact, never candidate cap compliance.
        self.assertEqual(self.ownership["models"]["nativeDesign"]["faces"], 1188)
        for index in [0, 1, 5, 6, 7, 8]:
            part, own = self.result["parts"][index], source_parts[index]
            points = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
            source_points = original["vertices"][own["vertexStart"]:own["vertexStart"] + own["vertexCount"]]
            self.assertEqual(sorted({p[2] for p in points}), sorted({p[2] for p in source_points}))
        part, own = self.result["parts"][2], source_parts[2]
        end, source_end = part["faceStart"] + part["faceCount"], own["faceStart"] + own["faceCount"]
        self.assertEqual(model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]],
                         original["vertices"][own["vertexStart"]:own["vertexStart"] + own["vertexCount"]])
        self.assertEqual([[v - part["vertexStart"] for v in face] for face in model["faces"][part["faceStart"]:end]],
                         [[v - own["vertexStart"] for v in face] for face in original["faces"][own["faceStart"]:source_end]])
        for key in ["faceMaterials", "faceTextures"]:
            self.assertEqual(model[key][part["faceStart"]:end], original[key][own["faceStart"]:source_end])
        major, minor = self.recipe.COLLAR_MAJOR_SAMPLES, self.recipe.COLLAR_MINOR_SAMPLES
        for index, centre_z in [(3, -1.9 * .20), (4, 1.9 * .24)]:
            part = self.result["parts"][index]
            points = model["vertices"][part["vertexStart"]:part["vertexStart"] + part["vertexCount"]]
            self.assertEqual(len(points), major * minor + 4)
            for row in range(major):
                angle = math.tau * row / major
                for column in range(minor):
                    theta = math.tau * column / minor
                    expected = [(1.15 * .39 + .04 * math.cos(theta)) * math.cos(angle),
                                (.37 + .04 * math.cos(theta)) * math.sin(angle),
                                centre_z + .04 * math.sin(theta)]
                    # Genuine source serializer precision; not a new full-profile tolerance.
                    self.assertEqual(points[row * minor + column], [round(float(v), 6) for v in expected])
        for index in (3, 4):
            own, part = source_parts[index], self.result["parts"][index]
            source_start = own["vertexStart"]
            first_new = part["vertexStart"] + major * minor
            self.assertEqual(
                model["vertices"][first_new:first_new + 4],
                [original["vertices"][source_start + row * 8] for row in (4, 8, 16, 20)],
            )
        self.assertEqual(len(model["faceTextures"]), len(model["faces"]))
        for face, material, texture in zip(model["faces"], model["faceMaterials"], model["faceTextures"]):
            self.assertEqual(texture["texture"], 0 if material == 0 else 2)
            self.assertEqual(len(texture["uv"]), len(face))
            self.assertTrue(all(len(uv) == 2 and all(math.isfinite(v) for v in uv) for uv in texture["uv"]))
        for key in ["design", "nativeDesign"]:
            self.assertEqual(self.source[key], self.resource[key])

    def test_restore_original_profile_parts_at_the_ten_audited_z_misses(self):
        plan = json.loads((HERE / "SH040-collar-profile-blueprint.json").read_text())

        def frozen_document(field):
            pin = plan[field]
            raw = Path(pin["path"]).read_bytes()
            self.assertEqual(len(raw), pin["bytes"])
            self.assertEqual(hashlib.sha256(raw).hexdigest(), pin["sha256"])
            return json.loads(raw)

        previous = frozen_document("previousCandidate")
        witnesses = frozen_document("frozenWitnesses")
        self.assertEqual(witnesses["candidateSHA256"], plan["previousCandidate"]["sha256"])
        self.assertEqual(witnesses["originalSHA256"], self.recipe.SOURCE_SHA256)
        lattice = witnesses["lattice"][2]
        self.assertEqual(lattice["axis"], 2)
        misses = [i for i, row in enumerate(lattice["samples"])
                  if any(row["reference"]) and not any(row["candidate"])]
        self.assertEqual(misses, [6, 10, 52, 66, 136, 152, 171, 185, 224, 234])
        for i in misses:
            reference = lattice["samples"][i]["reference"]
            self.assertTrue(reference[0] or reference[1])

        def local_part(model, part):
            start, first = part["vertexStart"], part["faceStart"]
            end = first + part["faceCount"]
            return (
                model["vertices"][start:start + part["vertexCount"]],
                [[i - start for i in face] for face in model["faces"][first:end]],
                model["faceMaterials"][first:end], model["faceTextures"][first:end],
            )

        original_parts = self.ownership["models"]["nativeDesign"]["parts"]
        for index, part in enumerate(self.result["parts"]):
            if index in (3, 4):
                continue
            if index < 2:
                model, expected = self.source["nativeDesign"], original_parts[index]
            else:
                model, expected = previous["nativeCandidate"], previous["parts"][index]
            with self.subTest(part=index):
                self.assertEqual(local_part(self.result["nativeCandidate"], part),
                                 local_part(model, expected))
        profile = frozen_document("qualifiedProfileCandidate")
        self.assertEqual(profile["id"], "SH040")
        for index in (3, 4):
            old_part = profile["parts"][index]
            new_part = self.result["parts"][index]
            before = local_part(profile["nativeCandidate"], old_part)
            after = local_part(self.result["nativeCandidate"], new_part)
            self.assertEqual(after[0][:-4], before[0])
            self.assertEqual(len(after[1]), len(before[1]) + 8)
            self.assertEqual(set(after[2]), {2})
        # Identical local geometry gives the restored original depth lists for
        # these parts. G1's independent lattice checks the actual ray outputs.

    def test_changed_real_input_refuses_before_any_geometry(self):
        class NoGeometry:
            def __getattr__(self, name):
                raise AssertionError("Invalid input reached geometry: " + name)
        for key in self.inputs:
            with self.subTest(key=key):
                changed = dict(self.inputs)
                changed[key] += b"\n"
                with self.assertRaises(ValueError):
                    self.recipe.build_candidate_native(NoGeometry(), **changed)
        self.assertEqual(hashlib.sha256(self.inputs["resource_bytes"]).hexdigest(), self.recipe.RESOURCE_SHA256)
        self.assertEqual(self.result["r3SHA256"], self.recipe.R3_SHA256)


if __name__ == "__main__":
    unittest.main()
