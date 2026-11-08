"""Freeze the Caracara Mk I collar crest correction in calibrated metres."""

from collections import Counter
from fractions import Fraction
from hashlib import sha256
import json
from pathlib import Path
import runpy
import sys

import numpy as np


PINS = {
    "candidate": "1ecb59c22eae9915a896ce65bf5513d74dea9ab68c08080e6b90bd3ec8389b40",
    "reference": "7dfb960a6b09d36e2425269bda78af408982799de17a1f717e7e8095d90d1003",
    "witness": "ffaf5c88cc8f11517db666657de30a1023d7ae21738dccb7fc6b7effebd3b042",
    "physical": "206b709130bbe749f089e84127abaf79218ecadcef3cb5ca5821b0d60d55821c",
}
RAY_HIT = runpy.run_path(str(Path(__file__).with_name("freeze-sh010-rims.py")))["ray_hit"]


def read(root, name, digest):
    data = (root / f"{name}.json").read_bytes()
    if sha256(data).hexdigest() != digest:
        raise ValueError(f"Changed {name} input")
    return json.loads(data)


def verify_parts(faces, triangles, parts):
    owners = []
    for part in parts:
        start, count = part["faceStart"], part["faceCount"]
        if start != len(owners):
            raise ValueError("Face ownership must be contiguous")
        owners.extend([part["index"]] * count)
        edges = Counter((a, b) for face in faces[start:start + count]
                        for a, b in zip(face, face[1:] + face[:1]))
        a, b, c = triangles[start:start + count].transpose(1, 0, 2)
        if (any(n != 1 or edges[b, a] != 1 for (a, b), n in edges.items())
                or np.linalg.norm(np.cross(b - a, c - a), axis=1).min() <= 1e-10
                or np.einsum("ij,ij->", a, np.cross(b, c)) <= 0):
            raise ValueError(f"Invalid closed part {part['index']}")
    if len(owners) != len(faces):
        raise ValueError("Incomplete part coverage")
    return np.asarray(owners)


def verify_ray(ray, expected, indices, triangles, owners, scale):
    hit = RAY_HIT(triangles[indices], np.asarray(ray["origin"]) * scale,
                  np.asarray(ray["direction"]), ray["limit"] * scale)
    if expected is None and hit is None:
        return
    if (expected is None or hit is None or owners[indices[hit[0]]] != expected["part"]
            or abs(hit[1] - expected["distance"] * scale) > 1e-8):
        raise ValueError(f"Changed calibrated ray {ray['name']}")


def main(root):
    inputs = {name: read(root, name, digest) for name, digest in PINS.items()}
    candidate, reference, physical = [inputs[name] for name in ("candidate", "reference", "physical")]
    source = physical["detailedSourceSHA256"]
    if (candidate["id"], reference["id"], physical["id"]) != ("SH169",) * 3 or (
        candidate["originalSourceSHA256"] != source or reference["sourceSHA256"] != source
    ):
        raise ValueError("Expected the original SH169 collision source and calibration")
    design, original = candidate["nativeDesign"], reference["nativeDesign"]
    for key in ("appearanceLicense", "appearanceSource", "materials", "textures", "paletteName"):
        if design[key] != original[key]:
            raise ValueError(f"Changed appearance metadata {key}")
    calibration = Fraction(physical["metresPerSourceUnitExact"])
    scale = float(calibration)
    vertices = np.asarray(design["vertices"]) * scale
    faces = design["faces"]
    triangles = vertices[faces]
    parts = candidate["parts"]
    if len(faces) != 512 or len(parts) != 21:
        raise ValueError("Unexpected collision count")
    owners = verify_parts(faces, triangles, parts)
    all_faces = np.arange(len(faces))
    checked = 0
    for ray in inputs["witness"]["rays"]:
        expected = ray["hits"]["candidate"]
        indices = np.flatnonzero(owners == expected["part"]) if "assembled" in ray else all_faces
        verify_ray(ray, expected, indices, triangles, owners, scale)
        checked += 1
        if "assembled" in ray:
            verify_ray(ray, ray["assembled"]["candidate"], all_faces, triangles, owners, scale)
            checked += 1
    output = dict(
        schemaVersion=1, status="CALIBRATED_COLLAR_CREST_SOURCE_ONLY", catalogueID="SH169",
        coordinateUnits="metres", forwardAxis="+Z", upAxis="+Y", calibration=str(calibration),
        originalSourceSHA256=source, inputSHA256=PINS, parts=parts, calibratedRayCount=checked,
        nativeDesign={**design, "vertices": vertices.tolist()},
    )
    with (root / "SH169-collision-candidate.json").open("x") as stream:
        json.dump(output, stream, sort_keys=True, separators=(",", ":"), allow_nan=False)
        stream.write("\n")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
