#!/usr/bin/env python3
"""Build the SH023 closed station-ring proposal from exact source-owned vertices."""
import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import tomllib

SOURCE_SHA = "b6fa2593479b011b08fe7818874da9263cc671d01270619081183f578c7ebbb3"
OWNER_SHA = "303caecc8c44ad16f2e98f1909d18a51a911d800382b7ce5d54a2dac99d3699f"
TIP = (3, 7, 11)
BROAD = (0, 2, 3, 4, 6, 9)
CARDINAL = (0, 3, 6, 9)
HEX = (1, 3, 5, 7, 9, 11)
PENTAGON = (1, 3, 5, 7, 11)
CASING = (HEX, TIP)
RECESS = (PENTAGON, TIP)
FORK = (TIP, BROAD, CARDINAL, TIP, CARDINAL)
CENTRAL = (TIP, BROAD, CARDINAL, TIP, TIP)
CANOPY = (TIP, PENTAGON, TIP, TIP, TIP)
RINGS = {0: FORK, 5: FORK, 13: CENTRAL, 19: CANOPY,
         22: CASING, 23: RECESS, 25: CASING, 26: RECESS}


def read(path, digest):
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != digest:
        raise ValueError(f"Changed SH023 input: {path}")
    return data


def ring_loft(rings):
    """Zip cyclic original azimuths without inventing a new station or vertex."""
    common = [angle for angle in rings[0] if all(angle in ring for ring in rings[1:])]
    if not common:
        raise ValueError("Source rings must share the loft seam")
    seam = 3 if 3 in common else common[0]
    offsets = []
    original_vertices = []
    for i, ring in enumerate(rings):
        offsets.append(len(original_vertices))
        original_vertices.extend(i * 12 + angle for angle in sorted(ring, key=lambda a: (a - seam) % 12))
    faces = [[0, k + 1, k] for k in range(1, len(rings[0]) - 1)]
    for s, (lower, upper) in enumerate(zip(rings, rings[1:])):
        a = sorted((angle - seam) % 12 for angle in lower) + [12]
        b = sorted((angle - seam) % 12 for angle in upper) + [12]
        i = j = 0
        while i < len(lower) or j < len(upper):
            low = offsets[s] + i % len(lower)
            high = offsets[s + 1] + j % len(upper)
            next_low = a[i + 1] if i < len(lower) else 13
            next_high = b[j + 1] if j < len(upper) else 13
            if next_low <= next_high:
                successor = offsets[s] + (i + 1) % len(lower)
                faces.append([low, successor, high])
                low = successor
                i += 1
            if next_high <= next_low:
                successor = offsets[s + 1] + (j + 1) % len(upper)
                faces.append([low, successor, high])
                j += 1
    first = offsets[-1]
    faces.extend([first, first + k, first + k + 1] for k in range(1, len(rings[-1]) - 1))
    return original_vertices, faces


def uv_for_face(points, material):
    """Apply the pinned original creator's .85-repeat dominant-axis chart."""
    a, b, c = [[Fraction(str(value)) for value in point] for point in points]
    u = [b[k] - a[k] for k in range(3)]
    v = [c[k] - a[k] for k in range(3)]
    normal = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
    axis = max(range(3), key=lambda k: abs(normal[k]))
    if normal[axis] == 0:
        raise ValueError("Degenerate candidate face")
    plane = ((2, 1), (0, 2), (0, 1))[axis]
    return {"texture": 0 if material == 0 else 2,
            "uv": [[float(round(Fraction(str(point[k])) * Fraction(85, 100), 6)) for k in plane] for point in points]}


def build(source, owner):
    original = tomllib.loads(read(source, SOURCE_SHA).decode())
    ownership = json.loads(read(owner, OWNER_SHA))
    if original["proposal"]["id"] != "SH023" or ownership["id"] != "SH023":
        raise ValueError("Own SH023 source required")
    native = original["nativeDesign"]
    model = {k: ([] if k in ("vertices", "faces", "faceMaterials", "faceTextures") else v)
             for k, v in native.items()}
    parts = []
    for i, old in enumerate(ownership["models"]["nativeDesign"]["parts"]):
        start, first = old["vertexStart"], old["faceStart"]
        end = first + old["faceCount"]
        points = native["vertices"][start:start + old["vertexCount"]]
        materials = native["faceMaterials"][first:end]
        textures = native["faceTextures"][first:end]
        local = [[v - start for v in f] for f in native["faces"][first:end]]
        original_vertices = list(range(len(points)))
        if i in RINGS:
            if len(points) != len(RINGS[i]) * 12 or len(set(materials)) != 1:
                raise ValueError("Changed original ring ownership")
            original_vertices, local = ring_loft(RINGS[i])
            points = [points[v] for v in original_vertices]
            materials = [materials[0]] * len(local)
            textures = [uv_for_face([points[v] for v in f], material)
                        for f, material in zip(local, materials)]
        v0, f0 = len(model["vertices"]), len(model["faces"])
        model["vertices"].extend(points)
        model["faces"].extend([[v0 + v for v in f] for f in local])
        model["faceMaterials"].extend(materials)
        model["faceTextures"].extend(textures)
        parts.append(dict(index=i, name=old["name"], vertexStart=v0, vertexCount=len(points),
                          faceStart=f0, faceCount=len(local),
                          originalVertexIDs=[start + v for v in original_vertices]))
    if len(parts) != 27 or len(model["faces"]) != 512:
        raise ValueError("Expected exact 27-part, 512-triangle construction")
    return {"id": "SH023", "status": "SOURCE_CANDIDATE_UNQUALIFIED",
            "originalSourceSHA256": SOURCE_SHA, "ownershipSHA256": OWNER_SHA,
            "nativeDesign": model, "parts": parts}


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("source", type=Path)
    cli.add_argument("ownership", type=Path)
    cli.add_argument("output", type=Path)
    args = cli.parse_args()
    candidate = build(args.source, args.ownership)
    with args.output.open("x") as file:
        json.dump(candidate, file, sort_keys=True, separators=(",", ":"), allow_nan=False)
        file.write("\n")


if __name__ == "__main__":
    main()
