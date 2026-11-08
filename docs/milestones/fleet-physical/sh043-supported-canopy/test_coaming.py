"""New SH043 support/material criteria and changed-stock independent references."""
from copy import deepcopy
import json
import math
import os
from pathlib import Path
import unittest

import numpy as np

import build_coaming as builder


ROOT = Path(__file__).resolve().parent
OUTPUT = Path(os.environ["SH043_COAMING_OUTPUT"])


class CoamingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.values, _ = builder.read_inputs(ROOT)
        cls.candidate, cls.text, cls.result = builder.build(ROOT)
        OUTPUT.mkdir()
        (OUTPUT / "SH043-supported-canopy.toml").write_text(cls.text)
        (OUTPUT / "SH043-coaming-stock-reference.json").write_text(
            json.dumps(cls.result, indent=2, sort_keys=True, allow_nan=False) + "\n")

    def owners(self):
        return [("design", self.values["detailed-components.json"]["design"], 15),
                ("nativeDesign", self.values["native-components.json"]["nativeDesign"], 11)]

    def test_original_all_glazing_component_fails_and_changed_coaming_joins_real_backbone(self):
        for key, owners, index in self.owners():
            with self.assertRaisesRegex(ValueError, "opaque lower coaming"):
                builder.support(self.values["resource.toml"][key], owners[index], owners[0])
            result = builder.support(self.candidate[key], owners[index], owners[0])
            self.assertTrue(result["connectedOpaqueCoaming"])
            self.assertAlmostEqual(result["backboneWinding"], 1, delta=1e-8)
            self.assertEqual(result["opaqueFaces"], 480 if key == "design" else 4)
            self.assertEqual(result["glazingFaces"], 480 if key == "design" else 4)
            self.assertEqual(result["sharedPerimeterEdges"], 32 if key == "design" else 4)

    def test_independent_integer_halfspace_material_boundary_and_tampered_support(self):
        for key, owners, index in self.owners():
            old, new = self.values["resource.toml"][key], self.candidate[key]
            owner = owners[index]
            lower = []
            for face_id in range(owner["faceStart"], owner["faceStart"] + owner["faceCount"]):
                # Integer source decimals avoid introducing an angular/error tolerance.
                y = [int(round(old["vertices"][vertex][1] * 10000000)) - 130000000
                     for vertex in old["faces"][face_id]]
                is_lower = min(y) < 0 and max(y) <= 0
                self.assertTrue(is_lower or (min(y) >= 0 and max(y) > 0))
                self.assertEqual(new["faceMaterials"][face_id], 0 if is_lower else 5)
                if is_lower:
                    lower.append(face_id)
                    self.assertEqual(new["faceTextures"][face_id]["texture"], 0)
                else:
                    self.assertEqual(new["faceTextures"][face_id], old["faceTextures"][face_id])
            self.assertEqual(lower, self.result["changedFaces"][key])
            changed = deepcopy(new)
            changed["faceMaterials"][lower[0]] = 5
            with self.assertRaisesRegex(ValueError, "opaque lower coaming"):
                builder.support(changed, owner, owners[0])

    def test_entire_geometry_contact_palette_and_unrelated_faces_remain_exact(self):
        for key, _, _ in self.owners():
            old, new = self.values["resource.toml"][key], self.candidate[key]
            for field in set(old) - {"faceMaterials", "faceTextures"}:
                self.assertEqual(old[field], new[field])
            changed = set(self.result["changedFaces"][key])
            for index in range(len(old["faces"])):
                if index not in changed:
                    self.assertEqual(old["faceMaterials"][index], new["faceMaterials"][index])
                    self.assertEqual(old["faceTextures"][index], new["faceTextures"][index])
        self.assertEqual(len(self.candidate["nativeDesign"]["faces"]), 248)
        self.assertEqual(len(self.candidate["nativeDesign"]["vertices"]), 148)
        self.assertEqual(self.candidate["catalogue"], self.values["resource.toml"]["catalogue"])
        self.assertEqual(self.candidate["game"], self.values["resource.toml"]["game"])

    def test_changed_stock_matches_independent_surface_quadrature_and_hardware_stays_exact(self):
        mesh = self.candidate["design"]
        weights = np.array([[2 / 3, 1 / 6, 1 / 6], [1 / 6, 2 / 3, 1 / 6], [1 / 6, 1 / 6, 2 / 3]])
        raw, area_parts = [], []
        for index in self.result["changedFaces"]["design"]:
            triangle = np.array(mesh["vertices"])[mesh["faces"][index]]
            area = np.linalg.norm(np.cross(triangle[1] - triangle[0], triangle[2] - triangle[0])) / 2
            area_parts.append(area)
            mass, samples = area * 9, weights @ triangle
            raw.append((mass, mass * samples.mean(axis=0), mass * samples.T @ samples / 3))
        area = math.fsum(area_parts)
        delta = (math.fsum(x[0] for x in raw), sum(x[1] for x in raw), sum(x[2] for x in raw))
        triangles = np.array(mesh["vertices"])[np.array(mesh["faces"])[self.result["changedFaces"]["design"]]]
        analytic = builder.triangle_moments(triangles, 9)
        for a, b in zip(analytic, delta):
            np.testing.assert_allclose(a, b, rtol=0, atol=1e-6)
        self.assertAlmostEqual(area, self.result["addedOpaqueStockAreaSquareMetres"], delta=1e-10)
        self.assertAlmostEqual(area * (14 - 5), self.result["addedStockMassKg"], delta=1e-8)
        old = self.values["engineering.json"]
        stock = (sum(x["stockMassKg"] for x in old["stockComponents"]),
                 sum(np.array(x["massFirst"]) for x in old["stockComponents"]),
                 sum(np.array(x["massSecond"]).reshape(3, 3) for x in old["stockComponents"]))
        point_hardware = [(x["massKg"], x["anchorMetres"], [0, 0, 0]) for x in old["intrinsicHardware"]]
        finite_hardware = [(x["massKg"], x["centreMetres"], x["dimensionsMetres"])
                           for x in self.values["finite.json"]["finiteIntrinsicHardware"]]
        self.assertEqual(sum(x[0] for x in point_hardware), 6480)
        self.assertEqual(sum(x[0] for x in finite_hardware), 6480)
        for target, parts in [("proposedPointReference", point_hardware), ("proposedFiniteReference", finite_hardware)]:
            raw = [stock, delta]
            for mass, centre, dimensions in parts:
                samples = np.array([np.array(centre) + np.array(dimensions) * np.array(sign) / (2 * np.sqrt(3))
                                    for sign in __import__("itertools").product([-1, 1], repeat=3)])
                raw.append((mass, mass * samples.mean(axis=0), mass * samples.T @ samples / 8))
            mass = sum(x[0] for x in raw)
            centre = sum(x[1] for x in raw) / mass
            second = sum(x[2] for x in raw) - mass * np.outer(centre, centre)
            inertia = np.eye(3) * np.trace(second) - second
            expected = self.result[target]
            self.assertEqual(math.ceil(mass), expected["mass"]["massKg"])
            np.testing.assert_allclose(centre, expected["mass"]["centreMetres"], rtol=0, atol=1e-9)
            np.testing.assert_allclose(inertia.reshape(-1), expected["mass"]["inertiaAboutCentreOfMassKgM2"],
                                       rtol=0, atol=1e-6)
            self.assertTrue((np.linalg.eigvalsh(inertia) > 0).all())

    def test_no_pending_population_crew_or_acceptance_authority_is_created(self):
        catalogue = self.candidate["catalogue"]
        self.assertEqual(catalogue["mechanicsStatus"], "pending")
        self.assertEqual(catalogue["placementStatus"], "pending")
        for key in ["galaxies", "regions", "authoredSystems", "roleWeights"]:
            self.assertEqual(catalogue[key], [])
        crew = self.values["R3.toml"]["accommodation"]
        self.assertEqual(crew["nativeCrew"], 28)
        self.assertFalse(crew["nativeAutonomous"])
        for key in ["adoptedResourceOrEngineeringEdited", "pendingRegistrationRemoved",
                    "actualNativeOrRendererRun", "populationOrPeopleOrOperatingAuthorityGranted"]:
            self.assertFalse(self.result[key])
        self.assertTrue(self.result["positiveCapitalAcceptance"].startswith("OPEN"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
