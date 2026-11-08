"""Freeze the independently sourced SH010 rim correction in calibrated metres."""

from collections import Counter
from fractions import Fraction
from hashlib import sha256
import json
from pathlib import Path
import sys

import numpy as np


PINS = {
    "candidate.json": "4f3dad625a966050db0a3491e9be75901d7402d4a1bace0a964cabbbff7cd679",
    "reference.json": "6b2fcf012eaf7cea3bede3f95679c80dd74517f39cffc8a6356ea173070cfced",
    "witness.json": "60bf04125150e7a07501c291d93755bd8d2c64c5d4f5e222482f9c76a1fa33de",
    "physical.json": "30aba17c31f65a5d1bcb9a29455f45bb876628ce5906d4af5cf16f249d2a79a6",
}


def load(root, name):
    data = (root / name).read_bytes()
    if sha256(data).hexdigest() != PINS[name]:
        raise ValueError(f"Changed input {name}")
    return json.loads(data)


def ray_hit(triangles, origin, direction, limit):
    a, b, c = triangles.transpose(1, 0, 2)
    ab, ac = b - a, c - a
    perpendicular = np.cross(direction, ac)
    determinant = np.einsum("ij,ij->i", ab, perpendicular)
    inverse = np.divide(1, determinant, out=np.zeros_like(determinant),
                        where=np.abs(determinant) > 1e-10)
    delta = origin - a
    u = np.einsum("ij,ij->i", delta, perpendicular) * inverse
    cross = np.cross(delta, ab)
    v = (cross @ direction) * inverse
    distance = np.einsum("ij,ij->i", ac, cross) * inverse
    hits = np.flatnonzero((inverse != 0) & (u >= -1e-9) & (v >= -1e-9) &
                          (u + v <= 1 + 1e-9) & (distance > 1e-8) & (distance <= limit))
    if not hits.size:
        return None
    face = hits[np.argmin(distance[hits])]
    return int(face), float(distance[face])


def main(root):
    candidate = load(root, "candidate.json")
    reference = load(root, "reference.json")
    witness = load(root, "witness.json")
    physical = load(root, "physical.json")
    source = physical["detailedSourceSHA256"]
    if (candidate["id"], reference["id"], physical["id"]) != ("SH010",) * 3 or (
        candidate["originalSourceSHA256"] != source or reference["sourceSHA256"] != source
    ):
        raise ValueError("Geometry and calibration must share the original SH010 source")
    calibration = Fraction(physical["metresPerSourceUnitExact"])
    scale = float(calibration)
    design = candidate["nativeDesign"]
    original = reference["nativeDesign"]
    for key in ("appearanceLicense", "appearanceSource", "materials", "textures", "paletteName"):
        if design[key] != original[key]:
            raise ValueError(f"Changed appearance metadata {key}")
    vertices = np.asarray(design["vertices"]) * scale
    triangles = vertices[design["faces"]]
    if len(triangles) != 512 or len(candidate["parts"]) != 31:
        raise ValueError("Changed Goshawk tessellation")
    face_owners = []
    for part in candidate["parts"]:
        first, count = part["faceStart"], part["faceCount"]
        if first != len(face_owners):
            raise ValueError("Face ownership must be contiguous")
        face_owners.extend([part["index"]] * count)
        faces = design["faces"][first:first + count]
        edges = Counter((a, b) for face in faces for a, b in zip(face, face[1:] + face[:1]))
        a, b, c = triangles[first:first + count].transpose(1, 0, 2)
        if (any(n != 1 or edges[b, a] != 1 for (a, b), n in edges.items())
                or np.linalg.norm(np.cross(b - a, c - a), axis=1).min() <= 1e-10
                or np.einsum("ij,ij->", a, np.cross(b, c)) <= 0):
            raise ValueError(f"Open or degenerate part {part['index']}")
    if len(face_owners) != len(triangles):
        raise ValueError("Incomplete triangle ownership")
    owners = np.asarray(face_owners)
    for ray in witness["rays"]:
        indices = (np.flatnonzero(owners == ray["part"]) if ray["name"] == "well-floor"
                   else np.arange(len(triangles)))
        selected = triangles[indices]
        direction = np.array(ray.get("direction", [0, 0, 1]))
        limit = .105 if ray["name"] == "well-floor" else .055
        expected = ray["hits"]["candidate"]
        actual = ray_hit(selected, np.array(ray["origin"]) * scale, direction, limit * scale)
        if ((expected is None and actual is not None) or
                (expected is not None and
                 (actual is None or owners[indices[actual[0]]] != expected["part"]
                  or abs(actual[1] - expected["distance"] * scale) > 1e-8))):
            raise ValueError(f"Calibrated ray mismatch for {ray['name']}")
    packet = dict(
        schemaVersion=1, status="CALIBRATED_RIM_CORRECTION_SOURCE_ONLY", catalogueID="SH010",
        coordinateUnits="metres", forwardAxis="+Z", upAxis="+Y", calibration=str(calibration),
        originalSourceSHA256=source, inputSHA256=PINS, parts=candidate["parts"],
        nativeDesign={**design, "vertices": vertices.tolist()},
        calibratedRayCount=len(witness["rays"]),
    )
    with (root / "SH010-collision-candidate.json").open("x") as stream:
        json.dump(packet, stream, sort_keys=True, separators=(",", ":"), allow_nan=False)
        stream.write("\n")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
