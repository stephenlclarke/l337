"""Authored independent Medusa proposal checks; execution belongs to the owned MBA slot."""
from pathlib import Path
from hashlib import sha256
from unittest.mock import patch
import importlib.util, itertools, json, resource, time, tomllib, traceback, unittest
import datetime, os, socket, sys
import numpy as np

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("medusa_finite_builder", ROOT / "build-medusa-finite-source.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


def quadrature_box(mass, centre, dimensions):
    # Eight Gauss points independently integrate every second-order uniform-box moment.
    points = np.array([np.array(centre) + np.array(dimensions) * np.array(sign) / np.sqrt(12)
                       for sign in itertools.product([-1, 1], repeat=3)])
    return mass, mass * points.mean(axis=0), mass * points.T @ points / 8


def source_stock_quadrature(ship, old):
    vertices = np.array(ship["design"]["vertices"]) * old["metresPerSourceUnit"]
    faces = np.array(ship["design"]["faces"])
    result = (0.0, np.zeros(3), np.zeros((3, 3)))
    for row in old["stockComponents"]:
        triangles = vertices[faces[row["faceStart"]:row["faceStart"] + row["faceCount"]]]
        area = np.linalg.norm(np.cross(triangles[:,1] - triangles[:,0],
                                       triangles[:,2] - triangles[:,0]), axis=1) / 2
        weights = area * row["stockKgPerSquareMetre"]
        points = [triangles[:,k] * (2/3) + triangles[:,(k+1)%3] / 6
                  + triangles[:,(k+2)%3] / 6 for k in range(3)]
        raw = (weights.sum(), sum((weights[:,None] * p).sum(axis=0) / 3 for p in points),
               sum(np.einsum("i,ij,ik->jk", weights / 3, p, p) for p in points))
        result = tuple(a + b for a,b in zip(result, raw))
    return result


def independent_properties(raw):
    mass, first, second = raw
    centre = first / mass
    inertia_origin = np.eye(3) * np.trace(second) - second
    shift = mass * (np.eye(3) * np.dot(centre, centre) - np.outer(centre, centre))
    return mass, centre, inertia_origin - shift


class FiniteDistributionReferenceTests(unittest.TestCase):
    def test_known_offset_box_tensor_and_owned_closed_geometry(self):
        # Twelve kg, dimensions2/4/6: Ixx52,Iyy40,Izz20 about its own COM.
        raw = quadrature_box(12, [1,2,3], [2,4,6])
        mass, centre, inertia = independent_properties(raw)
        self.assertAlmostEqual(mass, 12)
        np.testing.assert_allclose(centre, [1,2,3], rtol=1e-14, atol=1e-14)
        np.testing.assert_allclose(inertia, np.diag([52,40,20]), rtol=1e-14, atol=1e-12)
        record = builder.component(builder.box(12, [1,2,3], [2,4,6]), "known-reference")
        np.testing.assert_allclose(record["inertiaAboutCentreOfMassKgM2"], inertia.reshape(-1), rtol=1e-14, atol=1e-12)
        geometry = builder.owned_box_geometry([1,2,3], [2,4,6])
        triangles = builder.validate_owner(np.array(geometry["vertices"]), np.array(geometry["faces"]),
                                           dict(faceStart=0, faceCount=12))
        self.assertTrue(builder.certify_box([1,2,3], [1,2,3], triangles)["noBoundaryContact"])


class MedusaFiniteProposalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Reuse the same once-authenticated source values, not a second 22MB TOML parse.
        # The actual builder still performs every exact-byte/plan/owner/physical check.
        original_read = builder.read_inputs
        captured = []
        def capture_authenticated(root):
            values, plan = original_read(root)
            captured.append((values, plan))
            return values, plan
        with patch.object(builder, "read_inputs", side_effect=capture_authenticated):
            cls.result = builder.build(ROOT)
        if len(captured) != 1:
            raise AssertionError("Expected exactly one authenticated input read")
        values, cls.plan = captured[0]
        cls.old = values["SH171-engineering.json"]
        cls.ship = values["SH171-resource.toml"]
        cls.ownership = values["SH171-ownership.json"]
        values.pop("SH171-model.json")  # Redundant mesh was already compared in full.

    def test_mass_allocation_organ_anchors_and_new_dimensions_are_distinct_source_claims(self):
        parts = self.result["finiteIntrinsicHardware"]
        self.assertEqual(len(parts), 14)
        self.assertEqual(sum(p["massKg"] for p in parts), 8640)
        for i, (part, proposed, old) in enumerate(zip(parts, self.plan["allocations"], self.old["intrinsicHardware"])):
            self.assertEqual(part["originalHardwareAllocationIndex"], i)
            self.assertEqual(part["massKg"], old["massKg"])
            self.assertEqual(part["originalAnchorMetres"], old["anchorMetres"])
            self.assertEqual(part["owningComponentName"], old["anchorName"])
            self.assertEqual(part["nativeComponentIndex"], old["anchorComponent"])
            self.assertEqual(part["detailedComponentIndex"], old["anchorComponent"])
            self.assertIn("NEW_PROPOSED", part["newEngineeringDimensionBasis"])
            self.assertFalse(proposed["materialAndBiologicalFunctionQualified"])
            if i < 8:
                self.assertEqual(part["centreMetres"], old["anchorMetres"])
                self.assertEqual(proposed["newCentreOffsetMetres"], [0,0,0])
        self.assertEqual(self.result["emptyDryReference"]["massKg"], 40712)

    def test_whole_owned_box_geometry_closed_positive_and_inside_both_source_owners(self):
        # Convert each unchanged full source mesh once; keep every per-owner check below.
        meshes = {}
        for key in ["nativeDesign", "design"]:
            v = np.array(self.ship[key]["vertices"]) * self.old["metresPerSourceUnit"]
            f = np.array(self.ship[key]["faces"])
            v.setflags(write=False)
            f.setflags(write=False)
            meshes[key] = (v, f)
        for part in self.result["finiteIntrinsicHardware"]:
            geometry = part["equivalentDistributionGeometry"]
            self.assertEqual(len(geometry["vertices"]), 8)
            self.assertEqual(len(geometry["faces"]), 12)
            self.assertFalse(geometry["materialOrBiologicalFunctionQualified"])
            builder.validate_owner(np.array(geometry["vertices"]), np.array(geometry["faces"]),
                                   dict(faceStart=0, faceCount=12))
            for key, index in [("nativeDesign", part["nativeComponentIndex"]),
                               ("design", part["detailedComponentIndex"])]:
                v, f = meshes[key]
                owner = self.ownership["models"][key]["parts"][index]
                self.assertEqual(owner["name"], part["owningComponentName"])
                triangles = builder.validate_owner(v, f, owner)
                certificate = builder.certify_box(part["centreMetres"], part["dimensionsMetres"], triangles)
                self.assertTrue(certificate["noBoundaryContact"])
                self.assertEqual(len(certificate["cornerWinding"]), 8)
        builder.require_separation(self.result["finiteIntrinsicHardware"])

    def test_independent_triangle_and_box_quadrature_preserves_full_mass_com_tensor(self):
        stock = source_stock_quadrature(self.ship, self.old)
        self.assertAlmostEqual(stock[0], self.old["stockMassKg"], delta=1e-7)
        raw = stock
        for p in self.result["finiteIntrinsicHardware"]:
            raw = tuple(a+b for a,b in zip(raw, quadrature_box(p["massKg"], p["centreMetres"], p["dimensionsMetres"])))
        precentre = raw[1] / raw[0]
        reserve = self.old["roundingReserveKg"]
        raw = tuple(a+b for a,b in zip(raw, (reserve, reserve*precentre, reserve*np.outer(precentre, precentre))))
        mass, centre, inertia = independent_properties(raw)
        target = self.result["emptyDryReference"]
        self.assertAlmostEqual(mass, 40712, delta=1e-7)
        np.testing.assert_allclose(centre, target["centreMetres"], rtol=1e-10, atol=1e-10)
        np.testing.assert_allclose(inertia.reshape(-1), target["inertiaAboutCentreOfMassKgM2"], rtol=1e-10, atol=1e-7)
        self.assertGreater(np.linalg.eigvalsh(inertia).min(), 0)
        self.assertFalse(np.allclose(inertia.reshape(-1), self.old["inertiaAboutCentreOfMassKgM2"],
                                     rtol=1e-12, atol=1e-9))
        impulse = np.array([1200., -600., 900.])
        lever = np.array([4., 3., -10.]) - centre
        angular_momentum = np.cross(lever, impulse)
        angular = np.linalg.solve(inertia, angular_momentum)
        linear = impulse / mass
        energy = (impulse @ linear + angular_momentum @ angular) / 2
        np.testing.assert_allclose(inertia @ angular, angular_momentum, rtol=1e-12, atol=1e-9)
        self.assertAlmostEqual(impulse @ (linear + np.cross(angular, lever)) / 2, energy, delta=1e-9)
        # Independent exact non-diagonal 2x2 solve, not a Medusa performance/energy grant.
        tensor = np.array([[4.,1.,0.],[1.,3.,0.],[0.,0.,2.]])
        np.testing.assert_allclose(np.linalg.solve(tensor, [1,0,0]), [3/11,-1/11,0], rtol=1e-14, atol=1e-14)

    def test_missing_face_outside_overlap_touch_and_wrong_owner_cannot_be_certificates(self):
        part = self.result["finiteIntrinsicHardware"][0]
        key = "nativeDesign"
        v = np.array(self.ship[key]["vertices"]) * self.old["metresPerSourceUnit"]
        f = np.array(self.ship[key]["faces"])
        owner = self.ownership["models"][key]["parts"][part["nativeComponentIndex"]]
        local = f[owner["faceStart"]:owner["faceStart"]+owner["faceCount"]]
        with self.assertRaises(ValueError):
            builder.validate_owner(v, local[:-1], dict(faceStart=0, faceCount=len(local)-1))
        triangles = builder.validate_owner(v, f, owner)
        with self.assertRaises(ValueError):
            builder.certify_box([1e6,1e6,1e6], part["dimensionsMetres"], triangles)
        duplicates = [dict(centreMetres=[0,0,0], dimensionsMetres=[1,1,1])]*2
        with self.assertRaises(ValueError):
            builder.require_separation(duplicates)
        touching = [duplicates[0], dict(centreMetres=[1,0,0], dimensionsMetres=[1,1,1])]
        with self.assertRaises(ValueError):
            builder.require_separation(touching)
        # Opposite organ retains its complete authentic owner; never substitute an artificial cube.
        opposite = self.ownership["models"][key]["parts"][35]
        with self.assertRaises(ValueError):
            builder.certify_box(part["centreMetres"], part["dimensionsMetres"], builder.validate_owner(v,f,opposite))

    def test_changed_input_pin_and_native_population_or_service_grant_never_issue(self):
        original = Path.read_bytes
        def corrupted(path):
            return b"changed" if path == ROOT / "inputs/SH171-resource.toml" else original(path)
        with patch.object(Path, "read_bytes", corrupted):
            with self.assertRaisesRegex(ValueError, "Input bytes changed"):
                builder.read_inputs(ROOT)
        r3 = tomllib.loads((ROOT / "inputs/SH171-R3.toml").read_text())
        self.assertEqual(self.result["preservedR3"], {k:r3[k] for k in ["accommodation","fitting","acquisition"]})
        self.assertEqual(r3["accommodation"]["nativeCrew"], 1)
        self.assertEqual(r3["accommodation"]["playerConversionCrew"], 1)
        self.assertFalse(r3["accommodation"]["nativeAutonomous"])
        self.assertFalse(r3["fitting"]["roleKitIncludedInBareHull"])
        self.assertEqual(self.result["actualNativePopulation"], self.old["actualNativePopulation"])
        self.assertTrue(self.result["actualNativePopulation"].startswith("UNISSUED"))
        self.assertEqual(self.result["actualObservations"], [])
        self.assertEqual(self.result["nativeSourceTriangles"], 76228)
        self.assertEqual(self.result["nativeFaceLimit"], 512)
        self.assertTrue(self.result["nativeAdmissionBlocked"])
        for field in ["materialAndBiologicalFunctionQualified", "occupiedPeopleOrPaidEquipmentGranted",
                      "stockFuelEnergyAmmunitionServiceOrDeploymentGranted", "operatingAuthorityGranted"]:
            self.assertFalse(self.result[field])


class ImmediateFailureResult(unittest.TextTestResult):
    # Preserve the first traceback before a later CPU limit can prevent suite-end reporting.
    def addFailure(self, test, error):
        super().addFailure(test, error)
        self.stream.writeln("".join(traceback.format_exception(*error)))
        self.stream.flush()

    def addError(self, test, error):
        super().addError(test, error)
        self.stream.writeln("".join(traceback.format_exception(*error)))
        self.stream.flush()


if __name__ == "__main__":
    resource.setrlimit(resource.RLIMIT_CPU, (30, resource.getrlimit(resource.RLIMIT_CPU)[1]))
    print(json.dumps(dict(event="MEDUSA_ACTUAL_PROCESS_START", pid=os.getpid(),
                          host=socket.gethostname(), executable=sys.executable, argv=sys.argv,
                          utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                          testSourceSHA256=sha256(Path(__file__).read_bytes()).hexdigest(),
                          builderSourceSHA256=sha256((ROOT / "build-medusa-finite-source.py").read_bytes()).hexdigest(),
                          planSHA256=sha256((ROOT / "MEDUSA-FINITE-PLAN.json").read_bytes()).hexdigest(),
                          inputManifestSHA256=sha256((ROOT / "INPUTS.json").read_bytes()).hexdigest(),
                          CPUSeconds=30, peakRSSBytes=536870912, workers=1)), flush=True)
    started = time.perf_counter()
    suite = unittest.TestSuite([unittest.defaultTestLoader.loadTestsFromTestCase(cls)
                                for cls in [FiniteDistributionReferenceTests, MedusaFiniteProposalTests]])
    result = unittest.TextTestRunner(verbosity=2, resultclass=ImmediateFailureResult).run(suite)
    print(json.dumps(dict(testsRun=result.testsRun, failures=len(result.failures), errors=len(result.errors),
                         successful=result.wasSuccessful(), seconds=time.perf_counter()-started,
                         peakRSSBytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                         nativeSwiftTestsRun=False, actualObservations=[]), sort_keys=True))
    raise SystemExit(0 if result.wasSuccessful() and resource.getrusage(resource.RUSAGE_SELF).ru_maxrss <= 536870912 else 1)
