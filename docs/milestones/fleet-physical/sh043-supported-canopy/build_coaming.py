"""SH043 lower-canopy opaque coaming candidate; no native/admission authority."""
from collections import Counter, defaultdict
from copy import deepcopy
from hashlib import sha256
import itertools
import json
import math
from pathlib import Path
import tomllib

import numpy as np

INPUT_SHA256 = "8d7ad03c361e0da7dc402f9086d37df1aeb5362a74f0fd2d80b43e87276a0242"
PLAN_SHA256 = "98ca464837a220945ae0da44929babda8049a69a27eedadd960a03830f278327"

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


def read_inputs(root):
    raw = (root / "INPUTS.json").read_bytes()
    require(sha256(raw).hexdigest() == INPUT_SHA256, "Input manifest changed")
    pins = json.loads(raw)
    require({p.name for p in (root / "inputs").iterdir()} == set(pins), "Input set changed")
    values = {}
    for name, pin in pins.items():
        path = root / "inputs" / name
        require(path.is_file() and not path.is_symlink(), "Nonregular input")
        data = path.read_bytes()
        require(len(data) == pin["bytes"] and sha256(data).hexdigest() == pin["sha256"], "Input bytes changed")
        if path.suffix == ".toml":
            values[name] = tomllib.loads(data.decode())
        elif path.suffix == ".json":
            values[name] = json.loads(data)
    plan = (root / "PLAN.json").read_bytes()
    require(sha256(plan).hexdigest() == PLAN_SHA256, "Plan changed")
    return values, json.loads(plan)


def lower_faces(mesh, owner):
    points = np.asarray(mesh["vertices"])
    result = []
    for index in range(owner["faceStart"], owner["faceStart"] + owner["faceCount"]):
        y = points[mesh["faces"][index], 1]
        require(np.all(y <= 13) or np.all(y >= 13), "Canopy face crosses authored centre plane")
        require(not np.all(y == 13), "Canopy face lies in centre plane")
        if np.all(y <= 13):
            result.append(index)
    return result


def support(mesh, canopy, backbone):
    points, faces = np.array(mesh["vertices"]), np.array(mesh["faces"])
    validate_owner(points, faces, canopy)
    opaque = set(lower_faces(mesh, canopy))
    first, count = canopy["faceStart"], canopy["faceCount"]
    require(opaque and len(opaque) < count, "Missing opaque/glazing regions")
    for index in range(first, first + count):
        require(mesh["faceMaterials"][index] == (0 if index in opaque else 5),
                "Missing complete opaque lower coaming or changed upper glazing")
    edges = defaultdict(list)
    for index in range(first, first + count):
        face = mesh["faces"][index]
        for a, b in zip(face, face[1:] + face[:1]):
            edges[tuple(sorted((a, b)))].append(index)
    require(all(len(owners) == 2 for owners in edges.values()), "Open canopy edge")
    boundary, adjacency = defaultdict(set), defaultdict(set)
    for (a, b), (left, right) in edges.items():
        if (left in opaque) != (right in opaque):
            boundary[a].add(b)
            boundary[b].add(a)
        elif left in opaque:
            adjacency[left].add(right)
            adjacency[right].add(left)
    require(boundary and all(len(v) == 2 for v in boundary.values()), "Support perimeter not a cycle")
    seen, todo = set(), [next(iter(boundary))]
    while todo:
        vertex = todo.pop()
        if vertex not in seen:
            seen.add(vertex)
            todo.extend(boundary[vertex] - seen)
    require(seen == set(boundary), "Disconnected glazing support perimeter")
    seen, todo = set(), [next(iter(opaque))]
    while todo:
        face = todo.pop()
        if face not in seen:
            seen.add(face)
            todo.extend(adjacency[face] - seen)
    require(seen == opaque, "Disconnected opaque coaming")
    canopy_points = points[canopy["vertexStart"]:canopy["vertexStart"] + canopy["vertexCount"]]
    bottom = canopy_points[np.argmin(canopy_points[:, 1])]
    original_body = validate_owner(points, faces, backbone)
    winding = point_inside(bottom, original_body)
    require(abs(winding - 1) < 1e-8, "Lower opaque coaming not joined into original backbone")
    return dict(opaqueFaces=len(opaque), glazingFaces=count - len(opaque),
                sharedPerimeterEdges=len(boundary), connectedOpaqueCoaming=True,
                lowerJoinPointMetres=bottom.tolist(), backboneWinding=winding)


def triangle_moments(triangles, density):
    parts = []
    for a, b, c in triangles:
        mass = np.linalg.norm(np.cross(b - a, c - a)) * density / 2
        total = a + b + c
        second = mass * (np.outer(total, total) + np.outer(a, a)
                         + np.outer(b, b) + np.outer(c, c)) / 12
        parts.append((mass, mass * total / 3, second))
    return (math.fsum(p[0] for p in parts),
            np.array([math.fsum(p[1][i] for p in parts) for i in range(3)]),
            np.array([[math.fsum(p[2][i, j] for p in parts) for j in range(3)] for i in range(3)]))


def reference(stock, hardware, ident):
    total = add(stock, *hardware)
    reserve = math.ceil(total[0]) - total[0]
    centre = total[1] / total[0]
    result = component(add(total, box(reserve, centre, [0, 0, 0])), ident)
    require(np.linalg.eigvalsh(np.array(result["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3)).min() > 0,
            "Nonpositive proposed inertia")
    return dict(mass=result, unroundedMassKg=float(total[0]), roundingReserveKg=float(reserve))


def render_resource(raw, candidate):
    result, section = [], None
    for line in raw.splitlines(keepends=True):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1]
        if section in ["design", "nativeDesign"] and line.startswith("faceMaterials = "):
            line = "faceMaterials = " + json.dumps(candidate[section]["faceMaterials"], separators=(",", ":")) + "\n"
        elif section in ["design", "nativeDesign"] and line.startswith("faceTextures = "):
            textures = ["{texture=" + str(x["texture"]) + ",uv="
                        + json.dumps(x["uv"], separators=(",", ":")) + "}"
                        for x in candidate[section]["faceTextures"]]
            line = "faceTextures = [" + ",".join(textures) + "]\n"
        elif line.startswith("geometryContext = "):
            line = "geometryContext = " + json.dumps(candidate["geometryContext"]) + "\n"
        result.append(line)
    text = "# UNADOPTED SH043 lower-canopy coaming engineering candidate. Runtime remains pending.\n" + "".join(result)
    require(tomllib.loads(text) == candidate, "Candidate TOML round-trip changed other source")
    return text


def build(root):
    values, plan = read_inputs(root)
    ship, old, finite = values["resource.toml"], values["engineering.json"], values["finite.json"]
    require(ship["id"] == old["id"] == finite["id"] == plan["id"] == "SH043", "Wrong original hull")
    require(ship["nativeDesign"] == values["model.json"]["nativeDesign"], "Native model source changed")
    require(old["metresPerSourceUnit"] == 1 and old["dryMassKilograms"] == 295038
            and len(finite["finiteIntrinsicHardware"]) == 35, "Empty source changed")
    require(ship["catalogue"]["mechanicsStatus"] == "pending"
            and ship["catalogue"]["placementStatus"] == "pending"
            and ship["catalogue"]["authoredSystems"] == []
            and values["R3.toml"]["accommodation"]["nativeCrew"] == 28, "Unissued source changed")
    candidate, checks = deepcopy(ship), {}
    candidate["geometryContext"] = (
        "UNADOPTED lower-canopy opaque coaming engineering candidate. Original coordinates, "
        "faces, components and metre scale retained; lower canopy uses original opaque skin "
        "material and mapping. Stock reference changed; runtime and native acceptance remain pending.")
    changed = {}
    for key, owners, index in [
        ("design", values["detailed-components.json"]["design"], 15),
        ("nativeDesign", values["native-components.json"]["nativeDesign"], 11),
    ]:
        canopy, backbone = owners[index], owners[0]
        require(canopy["name"] == "capital bridge pressure canopy"
                and backbone["name"] == "capital command backbone", "Owner changed")
        mesh = candidate[key]
        changed[key] = lower_faces(mesh, canopy)
        require(all(mesh["faceMaterials"][i] == 5 for i in
                    range(canopy["faceStart"], canopy["faceStart"] + canopy["faceCount"])),
                "Original canopy material changed")
        for index in changed[key]:
            mesh["faceMaterials"][index] = 0
            triangle = np.asarray(mesh["vertices"])[mesh["faces"][index]]
            normal = np.cross(triangle[1] - triangle[0], triangle[2] - triangle[0])
            plane = [(2, 1), (0, 2), (0, 1)][int(np.argmax(abs(normal)))]
            mesh["faceTextures"][index] = dict(texture=0, uv=np.round(triangle[:, plane] * .16, 7).tolist())
        checks[key] = support(mesh, canopy, backbone)
    require(len(candidate["nativeDesign"]["faces"]) == 248 <= 512, "Native cap changed")
    roles = next(x for x in values["roles.json"]["rows"] if x["id"] == "SH043")
    densities = {x["materialIndex"]: x["kgPerSquareMetre"] for x in roles["faceStockAssignments"]}
    require(densities[0] == 14 and densities[5] == 5, "Adopted stock coefficients changed")
    mesh = candidate["design"]
    triangles = np.array(mesh["vertices"])[np.array(mesh["faces"])[changed["design"]]]
    delta = triangle_moments(triangles, densities[0] - densities[5])
    stock = add(*[(p["stockMassKg"], np.array(p["massFirst"]), np.array(p["massSecond"]).reshape(3, 3))
                  for p in old["stockComponents"]])
    proposed_stock = add(stock, delta)
    point_hardware = [box(p["massKg"], p["anchorMetres"], [0, 0, 0]) for p in old["intrinsicHardware"]]
    finite_hardware = [box(p["massKg"], p["centreMetres"], p["dimensionsMetres"])
                       for p in finite["finiteIntrinsicHardware"]]
    require(sum(p[0] for p in point_hardware) == sum(p[0] for p in finite_hardware)
            == old["intrinsicHardwareMassKg"] == 6480, "Hardware allocation changed")
    report = dict(status="UNADOPTED_OPAQUE_COAMING_SOURCE_CANDIDATE_NOT_NATIVE_OR_CAPITAL_ACCEPTANCE",
                  id="SH043", planSHA256=PLAN_SHA256, inputsSHA256=INPUT_SHA256,
                  geometryContactAndFaceIndicesUnchanged=True, nativeTriangles=248, nativeFaceLimit=512,
                  changedFaces=changed, support=checks, addedOpaqueStockAreaSquareMetres=float(delta[0] / 9),
                  addedStockMassKg=float(delta[0]), originalAdoptedDryMassKg=295038,
                  proposedPointReference=reference(proposed_stock, point_hardware, "SH043-coaming-point-proposal"),
                  proposedFiniteReference=reference(proposed_stock, finite_hardware, "SH043-coaming-finite-proposal"),
                  originalHardwareMassKg=6480, originalHardwareAllocations=8, originalFiniteDistributions=35,
                  adoptedResourceOrEngineeringEdited=False, pendingRegistrationRemoved=False,
                  actualNativeOrRendererRun=False, populationOrPeopleOrOperatingAuthorityGranted=False,
                  positiveCapitalAcceptance="OPEN: actual placement/personnel/load source unissued; G1 native/renderer qualification pending")
    return candidate, render_resource((root / "inputs/resource.toml").read_text(), candidate), report
