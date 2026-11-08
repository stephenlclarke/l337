"""Measure exterior forward muzzle points on the two pinned Plans hulls."""

from hashlib import sha256
import json
import math
from pathlib import Path
import sys

import numpy as np


MANIFEST_SHA256 = "2e5a0bff5a42315ecaa2a4a5706093efa9a45b903c44aca310dc43c43573c58f"
MUZZLE_XY = {"SH124": (-.5, .25), "SH125": (-.5, 2)}
AXIAL_STANDOFF = .25
CLEARANCE = .10
EPSILON = 1e-8


def load(root, name, digest):
    data = (root / name).read_bytes()
    if sha256(data).hexdigest() != digest:
        raise ValueError(f"Changed input {name}")
    return json.loads(data)


def cross2(a, b):
    return a[..., 0] * b[..., 1] - a[..., 1] * b[..., 0]


def surface(triangles, x, y):
    """Intersect the axis from forward infinity and retain the first outward face."""
    xy = triangles[:, :, :2] - (x, y)
    area = cross2(xy[:, 1] - xy[:, 0], xy[:, 2] - xy[:, 0])
    indices = np.flatnonzero(np.abs(area) > EPSILON)
    projected = xy[indices]
    weights = np.stack(
        [cross2(projected[:, i], projected[:, j]) / area[indices]
         for i, j in ((1, 2), (2, 0), (0, 1))], axis=1)
    hits = np.flatnonzero(np.min(weights, axis=1) >= -EPSILON)
    heights = np.sum(weights[hits] * triangles[indices[hits], :, 2], axis=1)
    first = hits[np.argmax(heights)]
    face = indices[first]
    if np.min(weights[first]) <= EPSILON or area[face] <= EPSILON:
        raise ValueError("Backing point must be in the interior of a forward-facing triangle")
    normal = np.cross(triangles[face, 1] - triangles[face, 0],
                      triangles[face, 2] - triangles[face, 0])
    return float(np.max(heights)), int(face), float(normal[2] / np.linalg.norm(normal))


def clip_forward(triangle, threshold):
    """Clip one solid boundary face to the forward half-space."""
    points = []
    for start, end in zip(triangle, np.roll(triangle, -1, axis=0)):
        before, after = start[2] >= threshold, end[2] >= threshold
        if before:
            points.append(start[:2])
        if before != after:
            crossing = (threshold - start[2]) / (end[2] - start[2])
            points.append((start + crossing * (end - start))[:2])
    return np.asarray(points)


def projected_distance(points, xy):
    local = points - xy
    edges = np.roll(local, -1, axis=0) - local
    sides = cross2(local, edges)
    if abs(sides.sum()) > EPSILON and (np.all(sides >= -EPSILON) or np.all(sides <= EPSILON)):
        return 0
    lengths = np.einsum("ij,ij->i", edges, edges)
    dots = -np.einsum("ij,ij->i", local, edges)
    fraction = np.clip(np.divide(dots, lengths, out=np.zeros_like(dots), where=lengths > 0), 0, 1)
    return np.linalg.norm(local + fraction[:, None] * edges, axis=1).min()


def prove_clearance(triangles, muzzle):
    """Certify a tube around the forward ray, including a ball around its origin."""
    threshold = muzzle[2] - CLEARANCE - EPSILON
    for triangle in triangles:
        clipped = clip_forward(triangle, threshold)
        if clipped.size and projected_distance(clipped, muzzle[:2]) <= CLEARANCE + EPSILON:
            raise ValueError(f"A solid boundary enters the proposed clearance tube at {muzzle}")


def main(root):
    manifest = load(root, "manifest.json", MANIFEST_SHA256)
    pins = {Path(name).name: record["sha256"] for name, record in manifest["localInputs"].items()}
    pair = load(root, "initial-pair-placement.json", pins["initial-pair-placement.json"])
    hulls = {}
    muzzles = {}
    for hull, (x, y) in MUZZLE_XY.items():
        name = f"{hull}-collision-candidate.json"
        model = load(root, name, pins[name])
        if (model["catalogueID"], model["coordinateUnits"], model["forwardAxis"]) != (
            hull, "metres", "+Z"
        ):
            raise ValueError(f"Unexpected hull frame for {hull}")
        mesh = model["nativeDesign"]
        triangles = np.asarray(mesh["vertices"])[mesh["faces"]]
        z, face, normal_z = surface(triangles, x, y)
        muzzle_z = math.ceil((z + AXIAL_STANDOFF) * 1000) / 1000
        muzzle = np.array([x, y, muzzle_z])
        prove_clearance(triangles, muzzle)
        part = next(part for part in model["parts"]
                    if part["faceStart"] <= face < part["faceStart"] + part["faceCount"])
        hulls[hull] = triangles
        muzzles[hull] = dict(muzzleMetres=muzzle.tolist(), axis=[0, 0, 1],
                            backingPointMetres=[x, y, z], backingFace=face,
                            backingPart=part["index"], backingNormalZ=normal_z,
                            axialStandoffMetres=muzzle_z - z,
                            ownSolidForwardClearanceLowerBoundMetres=CLEARANCE)
    positions = {"SH124": pair["warshipOffsetMetres"], "SH125": pair["droneOffsetMetres"]}
    for hull, other in (("SH124", "SH125"), ("SH125", "SH124")):
        ray_y = muzzles[hull]["muzzleMetres"][1] + positions[hull][1]
        other_y = hulls[other][:, :, 1] + positions[other][1]
        separation = float(max(ray_y - other_y.max(), other_y.min() - ray_y))
        if separation <= 0:
            raise ValueError("The peer's bounds do not certify an unoccluded shot")
        muzzles[hull]["peerClearanceLowerBoundAtStaticPlacementMetres"] = separation
    with (root / "initial-pair-muzzles.json").open("x") as stream:
        json.dump(dict(schemaVersion=1, status="BARE_HULL_MUZZLE_GEOMETRY_ONLY",
                       manifestSHA256=MANIFEST_SHA256,
                       inputSHA256={name: pins[name] for name in (
                           "SH124-collision-candidate.json", "SH125-collision-candidate.json",
                           "initial-pair-placement.json")},
                       frame="Calibrated metres; authored origin; +Z forward, +Y up",
                       mounts=muzzles), stream, indent=2, sort_keys=True, allow_nan=False)
        stream.write("\n")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
