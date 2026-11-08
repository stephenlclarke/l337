"""SH171 proposed finite equivalent distributions; validation required, no native authority.

New dimensions/central offsets are authored engineering choices, not recovered biology.
Run only on the orchestrator's existing MBA executor, never as an import-side effect.
"""
from pathlib import Path
from hashlib import sha256
from collections import Counter
import argparse, itertools, json, resource, tomllib
import numpy as np

PLAN_SHA256 = "6cef7eb607ec1d83d69206fc4721e515054d71965d356e7ff9e5fe8102a1fc56"
INPUT_MANIFEST_SHA256 = "5eb0f9dea0922aa2ae9806f2b22a18bb0084e5f784c24fc5ef326b9d80eefe9f"

def require(ok, message):
    if not ok:
        raise ValueError(message)


def add(*parts):
    return tuple(sum(p[k] for p in parts) for k in range(3))


def box(mass, centre, dimensions):
    c, d = np.array(centre), np.array(dimensions)
    return mass, mass * c, mass * (np.outer(c, c) + np.diag(d * d / 12))


def component(raw, ident):
    mass, first, second = raw
    c = first / mass
    inertia = np.eye(3) * np.trace(second) - second - mass * (np.eye(3) * (c @ c) - np.outer(c, c))
    return dict(
        id=ident,
        massKg=float(mass),
        centreMetres=c.tolist(),
        inertiaAboutCentreOfMassKgM2=inertia.reshape(-1).tolist(),
    )


def point_inside(point, triangles):
    v = triangles - point
    length = np.linalg.norm(v, axis=2)
    numerator = np.einsum("ij,ij->i", v[:, 0], np.cross(v[:, 1], v[:, 2]))
    denominator = np.prod(length, axis=1)
    denominator += np.einsum("ij,ij->i", v[:, 0], v[:, 1]) * length[:, 2]
    denominator += np.einsum("ij,ij->i", v[:, 1], v[:, 2]) * length[:, 0]
    denominator += np.einsum("ij,ij->i", v[:, 2], v[:, 0]) * length[:, 1]
    return float(np.sum(2 * np.arctan2(numerator, denominator)) / (4 * np.pi))


def triangle_box_contact(triangle, centre, half):
    t = triangle - centre
    edges = np.roll(t, -1, axis=0) - t
    axes = [*np.eye(3), np.cross(edges[0], edges[1])]
    axes += [np.cross(e, a) for e in edges for a in np.eye(3)]
    for axis in axes:
        norm = np.linalg.norm(axis)
        if norm < 1e-12:
            continue
        axis = axis / norm
        project = t @ axis
        radius = half @ abs(axis)
        if project.min() > radius + 1e-10 or project.max() < -radius - 1e-10:
            return False
    return True


def certify_box(centre, dimensions, triangles):
    c, d = np.array(centre), np.array(dimensions)
    winding = [
        point_inside(c + d / 2 * np.array(sign), triangles) for sign in itertools.product([-1, 1], repeat=3)
    ]
    require(
        all(abs(w - 1) < 1e-8 for w in winding),
        "Finite intrinsic hardware outside its native source component",
    )
    require(
        not any(triangle_box_contact(t, c, d / 2) for t in triangles),
        "Finite intrinsic hardware crosses its native source boundary",
    )
    return dict(cornerWinding=winding, noBoundaryContact=True)


def read_inputs(root):
    manifest_bytes = (root / "INPUTS.json").read_bytes()
    require(sha256(manifest_bytes).hexdigest() == INPUT_MANIFEST_SHA256, "Input manifest changed")
    manifest = json.loads(manifest_bytes)
    expected = {row["file"] for row in manifest}
    require({p.name for p in (root / "inputs").iterdir()} == expected, "Input file set changed")
    values = {}
    for row in manifest:
        path = root / "inputs" / row["file"]
        require(path.is_file() and not path.is_symlink(), "Nonregular input")
        data = path.read_bytes()
        require(len(data) == row["bytes"] and sha256(data).hexdigest() == row["sha256"], "Input bytes changed")
        values[row["file"]] = (tomllib.loads(data.decode()) if path.suffix == ".toml" else json.loads(data))
    plan_bytes = (root / "MEDUSA-FINITE-PLAN.json").read_bytes()
    require(sha256(plan_bytes).hexdigest() == PLAN_SHA256, "Engineering proposal changed")
    return values, json.loads(plan_bytes)


def validate_owner(vertices, faces, owner):
    first, count = owner["faceStart"], owner["faceCount"]
    local = faces[first:first + count]
    require(len(local) == count and local.ndim == 2 and local.shape[1] == 3, "Owner face range changed")
    directed = Counter((int(a), int(b)) for face in local for a, b in zip(face, np.roll(face, -1)))
    require(all(n == 1 and directed[(b, a)] == 1 for (a, b), n in directed.items()),
            "Owner surface open or inconsistently oriented")
    triangles = vertices[local]
    require(np.isfinite(triangles).all(), "Nonfinite source geometry")
    volume = np.linalg.det(triangles.transpose(0, 2, 1)).sum() / 6
    require(volume > 0, "Nonpositive owner volume")
    return triangles


def owned_box_geometry(centre, dimensions):
    c, d = np.array(centre), np.array(dimensions)
    vertices = [(c + d * np.array(sign) / 2).tolist() for sign in itertools.product([-1, 1], repeat=3)]
    # Eight corners and twelve consistently outward triangles of the authored distribution.
    faces = [[0,1,3],[0,3,2],[4,6,7],[4,7,5],[0,4,5],[0,5,1],
             [2,3,7],[2,7,6],[0,2,6],[0,6,4],[1,5,7],[1,7,3]]
    return dict(vertices=vertices, faces=faces,
                purpose="Equivalent mass-distribution geometry only; never original organ or native LOD",
                materialOrBiologicalFunctionQualified=False)


def require_separation(parts):
    for i, p in enumerate(parts):
        c, d = np.array(p["centreMetres"]), np.array(p["dimensionsMetres"])
        for q in parts[:i]:
            qc, qd = np.array(q["centreMetres"]), np.array(q["dimensionsMetres"])
            gap = abs(c - qc) - (d + qd) / 2
            require(np.any(gap > 1e-10), "Finite equivalent distributions overlap or touch")


def build(root):
    values, plan = read_inputs(root)
    ship, r3, old, model, ownership = [values["SH171-" + name] for name in
                                    ["resource.toml", "R3.toml", "engineering.json", "model.json", "ownership.json"]]
    require(ship["id"] == r3["id"] == old["id"] == plan["id"] == "SH171", "Wrong hull")
    require(ship["name"] == r3["name"] == plan["name"] == "Medusa", "Wrong original name")
    require(sha256((root / "inputs/SH171-R3.toml").read_bytes()).hexdigest() == old["contractSHA256"],
            "R3 source identity changed")
    require(old["metresPerSourceUnitExact"] == "5/41" and old["metresPerSourceUnit"] == 5/41
            and old["targetDetailedLengthMetres"] == 38 and old["sourceGeometryNotEdited"]
            and old["sourceOriginUnchanged"], "Source calibration/origin changed")
    require(r3["geometry"]["nativeFaceLimit"] == 512 and r3["accommodation"]["nativeCrew"] == 1
            and r3["accommodation"]["playerConversionCrew"] == 1
            and r3["accommodation"]["minimumOperatingCrewIncludingCommander"] == 1
            and r3["accommodation"]["intrinsicCrewPlaces"] == 1
            and not r3["accommodation"]["nativeAutonomous"]
            and not r3["fitting"]["roleKitIncludedInBareHull"], "Crew/paid-kit/cap source changed")
    require(old["actualNativePopulation"].startswith("UNISSUED")
            and not old["occupiedPeopleCabinsPaidEquipmentGranted"]
            and not old["actualPortsProvidersOrServiceRightsGranted"], "Population/service grant forbidden")
    require(model["nativeDesign"] == ship["nativeDesign"], "Original native geometry/appearance changed")
    require(model["sourceSHA256"] == r3["source"]["geometrySHA256"]
            == ownership["geometrySHA256"] == old["detailedSourceSHA256"], "Source provenance changed")
    require(len(ship["nativeDesign"]["faces"]) == 76228
            and len(ship["nativeDesign"]["vertices"]) == 39276, "Original native counts changed")
    require(len(old["intrinsicHardware"]) == len(plan["allocations"]) == 14, "Allocation count changed")
    scale = old["metresPerSourceUnit"]
    meshes = {}
    for key in ["nativeDesign", "design"]:
        meshes[key] = (np.array(ship[key]["vertices"]) * scale, np.array(ship[key]["faces"]))
    # Release the redundant JSON mesh after the full source identity comparison.
    del model
    parts, raw = [], []
    for i, row in enumerate(plan["allocations"]):
        allocation = old["intrinsicHardware"][i]
        require(row["originalAllocationIndex"] == i and row["massKg"] == allocation["massKg"]
                and allocation["count"] == 1 and row["originalAnchorMetres"] == allocation["anchorMetres"],
                "Original allocation/mass/anchor changed")
        require(row["detailedOwnerIndex"] == row["nativeOwnerIndex"] == allocation["anchorComponent"]
                and row["ownerName"] == allocation["anchorName"], "Owner substitution")
        require(not row["materialAndBiologicalFunctionQualified"], "Proposed distribution is not biology")
        offset = np.array(row["newCentreOffsetMetres"])
        dimensions = np.array(row["newDimensionsMetres"])
        require(offset.shape == dimensions.shape == (3,) and np.isfinite(offset).all()
                and np.isfinite(dimensions).all() and np.all(dimensions > 0), "Invalid finite design")
        if i < 8:
            require(np.array_equal(offset, np.zeros(3)), "Original organ anchor moved")
        centre = np.array(allocation["anchorMetres"]) + offset
        certificates = {}
        for key, ownerkey in [("nativeDesign", "nativeOwnerIndex"), ("design", "detailedOwnerIndex")]:
            owner = ownership["models"][key]["parts"][row[ownerkey]]
            require(owner["name"] == row["ownerName"], "Wrong source owner name")
            triangles = validate_owner(*meshes[key], owner)
            certificates[key] = certify_box(centre, dimensions, triangles)
        distribution = box(row["massKg"], centre, dimensions)
        part = component(distribution, row["id"])
        # A uniform box's analytic centre is the authored centre exactly. Re-deriving it
        # as (mass * centre) / mass can change source organ-anchor bits through roundoff.
        part["centreMetres"] = centre.tolist()
        geometry = owned_box_geometry(centre, dimensions)
        validate_owner(np.array(geometry["vertices"]), np.array(geometry["faces"]),
                       dict(faceStart=0, faceCount=12))
        part.update(originalHardwareAllocationIndex=i, originalAnchorMetres=row["originalAnchorMetres"],
                    nativeComponentIndex=row["nativeOwnerIndex"], detailedComponentIndex=row["detailedOwnerIndex"],
                    owningComponentName=row["ownerName"], dimensionsMetres=dimensions.tolist(),
                    newCentreOffsetMetres=offset.tolist(), newEngineeringDimensionBasis=row["newDimensionBasis"],
                    equivalentDistributionGeometry=geometry, certificates=certificates)
        parts.append(part)
        raw.append(distribution)
    require_separation(parts)
    stock = add(*[(p["stockMassKg"], np.array(p["massFirst"]), np.array(p["massSecond"]).reshape(3,3))
                  for p in old["stockComponents"]])
    require(abs(stock[0] - old["stockMassKg"]) < 1e-8, "Original surface stock changed")
    require(abs(sum(p["massKg"] for p in parts) - old["intrinsicHardwareMassKg"]) < 1e-8,
            "Intrinsic total changed")
    total = add(stock, *raw)
    reserve = old["roundingReserveKg"]
    require(reserve >= 0, "Invalid source reserve")
    reserve_c = total[1] / total[0]
    final = add(total, box(reserve, reserve_c, [0,0,0]))
    require(abs(final[0] - old["dryMassKilograms"]) < 1e-8, "Original dry total changed")
    finite = component(final, "finite-equivalent-empty-medusa-proposal")
    require(np.linalg.eigvalsh(np.array(finite["inertiaAboutCentreOfMassKgM2"]).reshape(3,3)).min() > 0,
            "Finite inertia not positive definite")
    return dict(schemaVersion=1, id="SH171", name="Medusa",
                status="PROPOSED_FINITE_EQUIVALENT_DISTRIBUTIONS_NOT_NATIVE_BIOLOGICAL_OR_OPERATIONAL_QUALIFICATION",
                planSHA256=PLAN_SHA256, inputManifestSHA256=INPUT_MANIFEST_SHA256,
                generatorSHA256=sha256(Path(__file__).read_bytes()).hexdigest(),
                r3SHA256=old["contractSHA256"], originalGeometrySHA256=old["detailedSourceSHA256"],
                engineeringSHA256=sha256((root / "inputs/SH171-engineering.json").read_bytes()).hexdigest(),
                resourceSHA256=sha256((root / "inputs/SH171-resource.toml").read_bytes()).hexdigest(),
                ownershipSHA256=sha256((root / "inputs/SH171-ownership.json").read_bytes()).hexdigest(),
                sourceGeometryNotEdited=True, sourceScaleExact="5/41", nativeSourceTriangles=76228,
                nativeFaceLimit=512, nativeAdmissionBlocked=True, finiteIntrinsicHardware=parts,
                unchangedStock=component(stock, "unchanged-original-area-lamina-stock"),
                stockModel="Original area-mass lamina budget retained; not material thickness, internal anatomy, pressure or free-volume qualification",
                roundingReserve=component(box(reserve,reserve_c,[0,0,0]), "reserve-at-new-com"),
                emptyDryReference=finite, originalPointAllocationReference={k:old[k] for k in
                  ["dryMassKilograms","centreOfMassMetres","inertiaAboutCentreOfMassKgM2"]},
                preservedR3={k:r3[k] for k in ["accommodation","fitting","acquisition"]},
                actualNativePopulation=old["actualNativePopulation"], actualObservations=[],
                materialAndBiologicalFunctionQualified=False, occupiedPeopleOrPaidEquipmentGranted=False,
                stockFuelEnergyAmmunitionServiceOrDeploymentGranted=False, operatingAuthorityGranted=False,
                sourceReading="Equivalent finite empty engineering distributions only, not resolved internal anatomy/free volume")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CPU, (30, resource.getrlimit(resource.RLIMIT_CPU)[1]))
    result = build(args.stage)
    require(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss <= 536870912, "512MiB exceeded")
    with args.output.open("x") as stream:
        json.dump(result, stream, indent=2, sort_keys=True, allow_nan=False)
        stream.write("\n")


if __name__ == "__main__":
    main()
