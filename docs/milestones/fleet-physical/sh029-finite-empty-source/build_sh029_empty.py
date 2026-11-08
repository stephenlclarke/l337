"""Separate SH029 finite intrinsic EMPTY engineering; no runtime or load adoption."""
from pathlib import Path
from hashlib import sha256
from collections import Counter
import argparse
import itertools
import json
import tomllib

import numpy as np

PLAN_SHA256 = "bc85c90747bb32b8c87bb6724f75fd7daadc16bc0a1c785d932bf5e4a012955c"
INPUT_MANIFEST_SHA256 = "59d693224f0a605deffacfbdf3099d3368e1eed3df0120d334334820e3bc94a8"

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
                purpose="Equivalent empty mass geometry only; never recovered installed mechanism or native LOD",
                materialOrBiologicalFunctionQualified=False)


def require_separation(parts):
    for i, p in enumerate(parts):
        c, d = np.array(p["centreMetres"]), np.array(p["dimensionsMetres"])
        for q in parts[:i]:
            qc, qd = np.array(q["centreMetres"]), np.array(q["dimensionsMetres"])
            gap = abs(c - qc) - (d + qd) / 2
            require(np.any(gap > 1e-10), "Finite equivalent distributions overlap or touch")


def read_inputs(root):
    manifest = (root / "INPUTS.json").read_bytes()
    require(sha256(manifest).hexdigest() == INPUT_MANIFEST_SHA256, "Input manifest changed")
    pins = json.loads(manifest)
    require({p.name for p in (root / "inputs").iterdir()} == {p["file"] for p in pins},
            "Input file set changed")
    values = {}
    for pin in pins:
        path = root / "inputs" / pin["file"]
        require(path.is_file() and not path.is_symlink(), "Nonregular input")
        data = path.read_bytes()
        require(len(data) == pin["bytes"] and sha256(data).hexdigest() == pin["sha256"],
                "Input bytes changed: " + pin["file"])
        values[pin["file"]] = tomllib.loads(data.decode()) if path.suffix == ".toml" else json.loads(data)
    plan = (root / "OKAPI-FINITE-PLAN.json").read_bytes()
    require(sha256(plan).hexdigest() == PLAN_SHA256, "Engineering proposal changed")
    return values, json.loads(plan)


def build(root):
    values, plan = read_inputs(root)
    ship, r3, old, model = [values["SH029-" + name] for name in
                           ["resource.toml", "R3.toml", "engineering.json", "model.json"]]
    detailed, native = values["SH029-detailed.toml"], values["SH029-native.toml"]
    ownership = values["SH029-ownership.json"]["models"]["design"]["parts"]
    native_owners = values["SH029-native-components.json"]["nativeDesign"]
    require(ship["id"] == r3["id"] == old["id"] == plan["id"] == "SH029", "Wrong hull")
    require(ship["name"] == r3["name"] == plan["name"] == "Okapi", "Wrong original name")
    require(old["dryMassKilograms"] == 45520 and old["metresPerSourceUnit"] == 1
            and old["sourceGeometryNotEdited"] and old["sourceOriginUnchanged"],
            "Changed original empty mass, units or origin")
    require(old["contractSHA256"] == sha256((root / "inputs/SH029-R3.toml").read_bytes()).hexdigest()
            and old["detailedSourceSHA256"] == sha256((root / "inputs/SH029-detailed.toml").read_bytes()).hexdigest()
            and model["sourceSHA256"] == sha256((root / "inputs/SH029-native.toml").read_bytes()).hexdigest(),
            "Changed source provenance")
    require(ship["design"] == detailed["design"] and ship["nativeDesign"] == native["nativeDesign"]
            == model["nativeDesign"], "Changed detailed/native geometry or appearance")
    require(model["coordinateUnits"] == "metres" and model["id"] == "SH029", "Changed native units")
    require(len(ship["nativeDesign"]["faces"]) == 120
            and len(ship["nativeDesign"]["vertices"]) == 76 and len(native_owners) == 8
            and len(ownership) == len(old["stockComponents"]) == 30, "Changed source ownership counts")
    require(len(old["intrinsicHardware"]) == len(plan["allocations"]) == 8, "Changed allocation count")
    meshes = {key: (np.array(ship[key]["vertices"]), np.array(ship[key]["faces"]))
              for key in ["design", "nativeDesign"]}
    parts, raw = [], []
    for index, row in enumerate(plan["allocations"]):
        allocation = old["intrinsicHardware"][index]
        require(row["originalAllocationIndex"] == index and allocation["count"] == 1
                and row["massKg"] == allocation["massKg"]
                and row["originalAnchorMetres"] == allocation["anchorMetres"],
                "Original allocation mass/anchor/count changed")
        require(row["detailedOwnerIndex"] == allocation["anchorComponent"]
                and row["detailedOwnerName"] == allocation["anchorName"], "Detailed owner substitution")
        require(row["nativeOwnerIndex"] == ([5, 6][index] if index < 2 else 0),
                "Native component substitution")
        centre = np.array(row["originalAnchorMetres"]) + np.array(row["newCentreOffsetMetres"])
        dimensions = np.array(row["newDimensionsMetres"])
        require(centre.shape == dimensions.shape == (3,) and np.isfinite(centre).all()
                and np.isfinite(dimensions).all() and (dimensions > 0).all(), "Invalid finite design")
        certificates = {}
        for key, owner, name in [("design", ownership[row["detailedOwnerIndex"]], row["detailedOwnerName"]),
                                  ("nativeDesign", native_owners[row["nativeOwnerIndex"]], row["nativeOwnerName"])]:
            require(owner["name"] == name, "Named source owner changed")
            triangles = validate_owner(*meshes[key], owner)
            certificates[key] = certify_box(centre, dimensions, triangles)
        distribution = box(row["massKg"], centre, dimensions)
        part = component(distribution, row["id"])
        part.update(centreMetres=centre.tolist(), dimensionsMetres=dimensions.tolist(),
                    originalHardwareAllocationIndex=index, originalAnchorMetres=row["originalAnchorMetres"],
                    detailedComponentIndex=row["detailedOwnerIndex"], nativeComponentIndex=row["nativeOwnerIndex"],
                    detailedOwnerName=row["detailedOwnerName"], nativeOwnerName=row["nativeOwnerName"],
                    newCentreOffsetMetres=row["newCentreOffsetMetres"],
                    newDimensionBasis=row["newDimensionBasis"], certificates=certificates,
                    equivalentDistributionGeometry=owned_box_geometry(centre, dimensions))
        parts.append(part)
        raw.append(distribution)
    require_separation(parts)
    stock = add(*[(p["stockMassKg"], np.array(p["massFirst"]), np.array(p["massSecond"]).reshape(3, 3))
                  for p in old["stockComponents"]])
    require(abs(stock[0] - old["stockMassKg"]) < 1e-8, "Stock mass changed")
    require(abs(sum(p["massKg"] for p in parts) - old["intrinsicHardwareMassKg"]) < 1e-8,
            "Intrinsic mass changed")
    total = add(stock, *raw)
    reserve = old["roundingReserveKg"]
    require(reserve >= 0, "Negative reserve")
    centre = total[1] / total[0]
    final = add(total, box(reserve, centre, [0, 0, 0]))
    require(abs(final[0] - old["dryMassKilograms"]) < 1e-8, "Dry mass changed")
    mass = component(final, "SH029-proposed-finite-empty")
    require(np.linalg.eigvalsh(np.array(mass["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3)).min() > 0,
            "Nonpositive inertia")
    return dict(schemaVersion=1, id="SH029", name="Okapi",
                status="PROPOSED_FINITE_INTRINSIC_EMPTY_REFERENCE_NOT_ADOPTED_LOAD_OR_INSTALLATION",
                planSHA256=PLAN_SHA256, inputManifestSHA256=INPUT_MANIFEST_SHA256,
                generatorSHA256=sha256(Path(__file__).read_bytes()).hexdigest(),
                r3SHA256=old["contractSHA256"], detailedSourceSHA256=old["detailedSourceSHA256"],
                nativeSourceSHA256=model["sourceSHA256"],
                engineeringSHA256=sha256((root / "inputs/SH029-engineering.json").read_bytes()).hexdigest(),
                resourceSHA256=sha256((root / "inputs/SH029-resource.toml").read_bytes()).hexdigest(),
                coordinateUnits="metres", metresPerSourceUnit=1, nativeTriangles=120, nativeFaceLimit=512,
                nativeComponents=native_owners, finiteIntrinsicHardware=parts, emptyDryReference=mass,
                unchangedStock=component(stock, "SH029-original-area-lamina-stock"),
                roundingReserve=component(box(reserve, centre, [0, 0, 0]), "reserve-at-new-com"),
                originalPointAllocationReference={k: old[k] for k in
                  ["dryMassKilograms", "centreOfMassMetres", "inertiaAboutCentreOfMassKgM2"]},
                adoptedSourceGeometryOrMassEdited=False, adoptedKitOrLoadSemanticsEdited=False,
                installedCabinCrewPowerOrLoadedAuthorityGranted=False,
                sourceOnlyReference=True, actualObservations=[], actualGameAcceptance=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = build(args.stage)
    with args.output.open("x") as stream:
        json.dump(result, stream, indent=2, sort_keys=True, allow_nan=False)
        stream.write("\n")


if __name__ == "__main__":
    main()
