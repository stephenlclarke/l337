"""Freeze SH125 collision geometry and compare finite rays against the pinned original."""
from fractions import Fraction
from hashlib import sha256
from importlib.util import module_from_spec, spec_from_file_location
import json
import math
from pathlib import Path
import sys
import tomllib

import numpy as np


def load_module(path):
    spec = spec_from_file_location(path.stem, path)
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read_pinned(path, expected):
    data = path.read_bytes()
    if sha256(data).hexdigest() != expected:
        raise ValueError(f"Changed input {path.name}")
    return data


def emit(path, data):
    with path.open("x") as stream:
        json.dump(data, stream, sort_keys=True, separators=(",", ":"), allow_nan=False)
        stream.write("\n")


def metre_mesh(design, scale):
    return {**design, "vertices": [[coordinate * scale for coordinate in point]
                                   for point in design["vertices"]]}


class RayMesh:
    def __init__(self, design):
        self.a, self.b, self.c = np.asarray(design["vertices"])[design["faces"]].transpose(1, 0, 2)
        self.edge1 = self.b - self.a
        self.edge2 = self.c - self.a
        self.materials = design["faceMaterials"]

    def hit(self, origin, direction, length):
        perpendicular = np.cross(direction, self.edge2)
        determinant = np.einsum("ij,ij->i", self.edge1, perpendicular)
        inverse = np.divide(1, determinant, out=np.zeros_like(determinant),
                            where=np.abs(determinant) > 1e-10)
        offset = origin - self.a
        u = np.einsum("ij,ij->i", offset, perpendicular) * inverse
        cross = np.cross(offset, self.edge1)
        v = (cross @ direction) * inverse
        t = np.einsum("ij,ij->i", self.edge2, cross) * inverse
        indices = np.flatnonzero((inverse != 0) & (u >= -1e-9) & (v >= -1e-9)
                                 & (u + v <= 1 + 1e-9) & (t > 1e-8) & (t <= length))
        if indices.size:
            nearest = indices[np.argmin(t[indices])]
            return dict(distanceMetres=float(t[nearest]), material=self.materials[nearest])
        return None


def witness(original, candidate, scale):
    meshes = [RayMesh(original), RayMesh(candidate)]
    controls = []

    def check(name, origin, direction, distance, allowed):
        start = np.asarray(origin) * scale
        hits = [mesh.hit(start, direction, distance * scale) for mesh in meshes]
        for hit in hits:
            material = None if hit is None else hit["material"]
            if material not in allowed:
                raise ValueError(f"{name} at {origin} produced {hits}; expected {allowed}")
        controls.append(dict(name=name, originMetres=start.tolist(), direction=list(direction),
                             lengthMetres=distance * scale, original=hits[0], candidate=hits[1]))

    for index in range(20):
        angle = math.tau * index / 20
        x, z = math.cos(angle), math.sin(angle)
        for y in (-.2925, 0, .2925):
            check("core through slot", (2*x, y, 2*z), (-x, 0, -z), 4, {2})
            for offset in (-.68, .68):
                check("open slot past core", (2*x-offset*z, y, 2*z+offset*x),
                      (-x, 0, -z), 4, {None})
            for sign in (-1, 1):
                check("slot rim", (.75*x, y, .75*z), (0, sign, 0), .065, {1})
        for y in (-.46, -.14625, .14625, .46):
            check("exterior band", (2*x, y, 2*z), (-x, 0, -z), 4, {0, 3, 4})
        if index % 2 == 0:
            for y in (-.14625, .14625):
                check("cavity wall", (.58*x, y, .58*z), (x, 0, z), .1, {1})
    return controls


def main(root):
    recipe_path = Path(__file__).resolve().parents[1] / "SH125-round-profile-recipe.py"
    recipe = load_module(recipe_path)
    source = read_pinned(root / "SH125-design.toml", recipe.SOURCE_SHA256)
    creator_path = root / "generate.py"
    creator_bytes = read_pinned(creator_path, recipe.CREATOR_SHA256)
    resource = read_pinned(root / "Sources/L337Core/Resources/Ships/SH125.toml",
                           recipe.RESOURCE_SHA256)
    physical_digest = "52f994685dd828bc8b77ec73ad1ee92189a129c1e3eb3db9523c6c129120e182"
    physical = json.loads(read_pinned(root / "SH125-physical.json", physical_digest))
    if physical["id"] != "SH125" or physical["detailedSourceSHA256"] != recipe.SOURCE_SHA256:
        raise ValueError("The engineering calibration must bind the original SH125 design")
    calibration = Fraction(physical["metresPerSourceUnitExact"])
    scale = float(calibration)
    result = recipe.build_candidate_native(load_module(creator_path), source_bytes=source,
                                          creator_bytes=creator_bytes, resource_bytes=resource)
    original = metre_mesh(tomllib.loads(source.decode())["nativeDesign"], scale)
    mesh = metre_mesh(result["nativeCandidate"], scale)
    if len(mesh["faces"]) != 460:
        raise ValueError("Unexpected ten-sector triangle count")
    for part in result["parts"]:
        start = part["faceStart"]
        faces = np.asarray(mesh["faces"][start:start + part["faceCount"]])
        a, b, c = np.asarray(mesh["vertices"])[faces].transpose(1, 0, 2)
        if (np.linalg.norm(np.cross(b - a, c - a), axis=1).min() <= 1e-9
                or np.einsum("ij,ij->", a, np.cross(b, c)) <= 0):
            raise ValueError(f"Degenerate face or nonpositive signed volume in {part['name']}")
    controls = witness(original, mesh, scale)
    packet = root / "SH125-collision-candidate.json"
    emit(packet, dict(schemaVersion=1, catalogueID="SH125", coordinateUnits="metres",
                      forwardAxis="+Z", upAxis="+Y", calibration=str(calibration),
                      status="SOURCE_GEOMETRY_ONLY", nativeDesign=mesh, parts=result["parts"],
                      sourceSHA256=recipe.SOURCE_SHA256, creatorSHA256=recipe.CREATOR_SHA256,
                      resourceSHA256=recipe.RESOURCE_SHA256, physicalSHA256=physical_digest,
                      recipeSHA256=sha256(recipe_path.read_bytes()).hexdigest()))
    emit(root / "SH125-collision-witness.json", dict(
        schemaVersion=1, candidateSHA256=sha256(packet.read_bytes()).hexdigest(),
        originalSHA256=recipe.SOURCE_SHA256, controls=controls))


if __name__ == "__main__":
    main(Path(sys.argv[1]).resolve())
