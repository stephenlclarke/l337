"""Independent finite-volume references for the separate SH029 empty proposal."""
from copy import deepcopy
import itertools
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest

import numpy as np

import build_sh029_empty as builder


ROOT = Path(__file__).resolve().parent
OUTPUT = Path(os.environ["SH029_RESULT_DIRECTORY"])


def quadrature_box(mass, centre, dimensions):
    points = np.array([np.array(centre) + np.array(dimensions) * np.array(s) / (2 * np.sqrt(3))
                       for s in itertools.product([-1, 1], repeat=3)])
    return mass, mass * points.mean(axis=0), mass * points.T @ points / 8


def tetrahedron_reference(part):
    geometry = part["equivalentDistributionGeometry"]
    triangles = np.array(geometry["vertices"])[geometry["faces"]]
    volume = 0.
    first, second = np.zeros(3), np.zeros((3, 3))
    for a, b, c in triangles:
        v = np.linalg.det(np.column_stack((a, b, c))) / 6
        total = a + b + c
        volume += v
        first += v * total / 4
        second += v * (np.outer(total, total) + np.outer(a, a) + np.outer(b, b) + np.outer(c, c)) / 20
    density = part["massKg"] / volume
    return volume, (volume * density, first * density, second * density)


def reference_properties(parts):
    mass = sum(p[0] for p in parts)
    first = sum(p[1] for p in parts)
    second = sum(p[2] for p in parts)
    centre = first / mass
    shifted = second - mass * np.outer(centre, centre)
    return mass, centre, np.trace(shifted) * np.eye(3) - shifted


class OkapiEmptyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.values, cls.plan = builder.read_inputs(ROOT)
        cls.old = cls.values["SH029-engineering.json"]
        cls.ship = cls.values["SH029-resource.toml"]
        cls.source = builder.build(ROOT)
        cls.controls = {}
        OUTPUT.mkdir()
        (OUTPUT / "SH029-finite-empty-source.json").write_text(
            json.dumps(cls.source, indent=2, sort_keys=True, allow_nan=False) + "\n")

    def test_all_eight_allocations_have_both_exact_owners_and_separate_finite_envelopes(self):
        parts = self.source["finiteIntrinsicHardware"]
        self.assertEqual(len(parts), 8)
        self.assertEqual(len(self.ship["nativeDesign"]["faces"]), 120)
        for index, part in enumerate(parts):
            allocation = self.old["intrinsicHardware"][index]
            self.assertEqual(part["originalHardwareAllocationIndex"], index)
            self.assertEqual(part["massKg"], allocation["massKg"])
            self.assertEqual(part["originalAnchorMetres"], allocation["anchorMetres"])
            self.assertEqual(part["detailedComponentIndex"], allocation["anchorComponent"])
            for key, owners, owner_id in [
                ("design", self.values["SH029-ownership.json"]["models"]["design"]["parts"],
                 part["detailedComponentIndex"]),
                ("nativeDesign", self.values["SH029-native-components.json"]["nativeDesign"],
                 part["nativeComponentIndex"]),
            ]:
                mesh, owner = self.ship[key], owners[owner_id]
                triangles = builder.validate_owner(np.array(mesh["vertices"]), np.array(mesh["faces"]), owner)
                self.assertTrue(builder.certify_box(part["centreMetres"], part["dimensionsMetres"],
                                                   triangles)["noBoundaryContact"])
                with self.assertRaisesRegex(ValueError, "outside"):
                    builder.certify_box([1000, 1000, 1000], part["dimensionsMetres"], triangles)
        builder.require_separation(parts)
        overlap = deepcopy(parts)
        overlap[3]["centreMetres"] = overlap[2]["centreMetres"]
        with self.assertRaisesRegex(ValueError, "overlap"):
            builder.require_separation(overlap)
        self.controls["outsideOrOverlappingAllocation"] = "REJECTED"

    def test_each_uniform_box_matches_independent_cube_and_tetrahedral_integrals(self):
        for part in self.source["finiteIntrinsicHardware"]:
            reference = quadrature_box(part["massKg"], part["centreMetres"], part["dimensionsMetres"])
            volume, tetra = tetrahedron_reference(part)
            self.assertAlmostEqual(volume, np.prod(part["dimensionsMetres"]), delta=1e-10)
            analytic = builder.box(part["massKg"], part["centreMetres"], part["dimensionsMetres"])
            for wanted, actual, integrated in zip(reference, analytic, tetra):
                np.testing.assert_allclose(actual, wanted, rtol=0, atol=1e-8)
                np.testing.assert_allclose(integrated, wanted, rtol=0, atol=1e-7)

    def stock_reference(self):
        mesh = self.ship["design"]
        vertices, faces = np.array(mesh["vertices"]), np.array(mesh["faces"])
        role = next(r for r in self.values["SH029-roles.json"]["rows"] if r["id"] == "SH029")
        densities = {r["materialIndex"]: r["kgPerSquareMetre"] for r in role["faceStockAssignments"]}
        weights = np.array([[2 / 3, 1 / 6, 1 / 6], [1 / 6, 2 / 3, 1 / 6], [1 / 6, 1 / 6, 2 / 3]])
        result = []
        for owner, old in zip(role["components"], self.old["stockComponents"]):
            self.assertEqual(owner["name"], old["name"])
            samples = []
            for index in range(owner["faceStart"], owner["faceStart"] + owner["faceCount"]):
                triangle = vertices[faces[index]]
                area = np.linalg.norm(np.cross(triangle[1] - triangle[0], triangle[2] - triangle[0])) / 2
                mass = area * densities[mesh["faceMaterials"][index]]
                points = weights @ triangle
                samples.append((mass, mass * points.mean(axis=0), mass * points.T @ points / 3))
            total = tuple(sum(p[k] for p in samples) for k in range(3))
            np.testing.assert_allclose(total[0], old["stockMassKg"], rtol=0, atol=1e-8)
            np.testing.assert_allclose(total[1], old["massFirst"], rtol=0, atol=1e-8)
            np.testing.assert_allclose(total[2], np.array(old["massSecond"]).reshape(3, 3), rtol=0, atol=1e-6)
            result.append(total)
        return result

    def test_whole_detailed_surface_quadrature_and_finite_tensor_preserve_empty_mass(self):
        parts = self.stock_reference()
        parts.extend(quadrature_box(p["massKg"], p["centreMetres"], p["dimensionsMetres"])
                     for p in self.source["finiteIntrinsicHardware"])
        _, before_reserve, _ = reference_properties(parts)
        parts.append(quadrature_box(self.old["roundingReserveKg"], before_reserve, [0, 0, 0]))
        mass, centre, inertia = reference_properties(parts)
        target = self.source["emptyDryReference"]
        self.assertAlmostEqual(mass, 45520, delta=1e-8)
        np.testing.assert_allclose(centre, target["centreMetres"], rtol=0, atol=1e-9)
        np.testing.assert_allclose(inertia, np.array(target["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3),
                                   rtol=0, atol=1e-6)
        self.assertTrue((np.linalg.eigvalsh(inertia) > 0).all())
        self.assertFalse(np.array_equal(inertia.reshape(-1), self.old["inertiaAboutCentreOfMassKgM2"]))
        self.controls["reuseOldPointTensor"] = "REJECTED_AS_CHANGED_FINITE_MODEL"

    def test_wrong_owner_and_missing_surface_cannot_qualify(self):
        for key, owners in [("design", self.values["SH029-ownership.json"]["models"]["design"]["parts"]),
                            ("nativeDesign", self.values["SH029-native-components.json"]["nativeDesign"])]:
            mesh = self.ship[key]
            vertices, faces = np.array(mesh["vertices"]), np.array(mesh["faces"])
            negative, positive = (8, 11) if key == "design" else (5, 6)
            part = self.source["finiteIntrinsicHardware"][0]
            positive_part = self.source["finiteIntrinsicHardware"][1]
            triangles = builder.validate_owner(vertices, faces, owners[positive])
            builder.certify_box(positive_part["centreMetres"], positive_part["dimensionsMetres"], triangles)
            with self.assertRaisesRegex(ValueError, "outside"):
                builder.certify_box(part["centreMetres"], part["dimensionsMetres"], triangles)
            owner = owners[negative]
            with self.assertRaisesRegex(ValueError, "open"):
                builder.validate_owner(vertices, faces, dict(owner, faceCount=owner["faceCount"] - 1))
        self.controls["oppositeActualDriveAsOwner"] = "REJECTED"
        self.controls["missingOwnerFace"] = "REJECTED"

    def test_full_tensor_impulse_reference_preserves_momentum_and_work(self):
        target = self.source["emptyDryReference"]
        mass, centre = target["massKg"], np.array(target["centreMetres"])
        inertia = np.array(target["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3)
        impulse, point = np.array([1200., -600., 900.]), np.array([4., 3., -10.])
        moment = np.cross(point - centre, impulse)
        angular = np.linalg.solve(inertia, moment)
        linear = impulse / mass
        energy = (impulse @ linear + moment @ angular) / 2
        np.testing.assert_allclose(mass * linear, impulse, rtol=0, atol=1e-9)
        np.testing.assert_allclose(inertia @ angular, moment, rtol=0, atol=1e-8)
        np.testing.assert_allclose(np.cross(centre, impulse) + inertia @ angular, np.cross(point, impulse),
                                   rtol=0, atol=1e-8)
        self.assertAlmostEqual(impulse @ (linear + np.cross(angular, point - centre)) / 2, energy, delta=1e-10)
        diagonal = moment / np.diag(inertia)
        self.assertGreater(np.linalg.norm(inertia @ diagonal - moment), 1e-6)
        (OUTPUT / "IMPULSE-REFERENCE.json").write_text(json.dumps(dict(
            pointMetres=point.tolist(), impulseNs=impulse.tolist(), centreVelocityDelta=linear.tolist(),
            angularMomentumDelta=moment.tolist(), angularVelocityDelta=angular.tolist(),
            kineticEnergyFromRestJoules=float(energy)), indent=2) + "\n")
        self.controls["diagonalOnlyTensor"] = "REJECTED"

    def test_proposal_has_no_adoption_and_tampered_inputs_refuse(self):
        self.assertTrue(self.source["sourceOnlyReference"])
        for field in ["adoptedSourceGeometryOrMassEdited", "adoptedKitOrLoadSemanticsEdited",
                      "installedCabinCrewPowerOrLoadedAuthorityGranted", "actualGameAcceptance"]:
            self.assertFalse(self.source[field])
        self.assertEqual(self.source["actualObservations"], [])
        self.assertEqual(self.source["originalPointAllocationReference"]["dryMassKilograms"], 45520)
        with tempfile.TemporaryDirectory(prefix="sh029-changed-input-") as temporary:
            changed = Path(temporary)
            shutil.copytree(ROOT / "inputs", changed / "inputs")
            (changed / "inputs").chmod(0o755)
            shutil.copy2(ROOT / "INPUTS.json", changed / "INPUTS.json")
            shutil.copy2(ROOT / "OKAPI-FINITE-PLAN.json", changed / "OKAPI-FINITE-PLAN.json")
            target = changed / "inputs/SH029-engineering.json"
            target.chmod(0o644)
            target.write_bytes(target.read_bytes() + b" ")
            with self.assertRaisesRegex(ValueError, "Input bytes changed"):
                builder.read_inputs(changed)
        self.controls["changedAdoptedInput"] = "REJECTED"

    @classmethod
    def tearDownClass(cls):
        (OUTPUT / "CONTROLS.json").write_text(json.dumps(cls.controls, indent=2) + "\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
