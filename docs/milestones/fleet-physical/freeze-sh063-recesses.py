"""Build SH063's exposed luminous caps and verify its authored mount rails."""

from fractions import Fraction
from hashlib import sha256
import json
from pathlib import Path
import runpy
import sys
import tomllib

import numpy as np


PINS = {
    "candidate.json": "daf9326c6b2ebc0f09e134f3a8ababc5a8c2442e5189b87897eed789f719ad9e",
    "reference.json": "5965142a4526b4db6eaff87acdb62ecc83082e9f6eea34be99a5745bae546a12",
    "criteria.json": "108153a6bc689ae0e0cf49452a05c677fc995f49eb933c4f28728cbbddb560f8",
    "witness.json": "f7866428e138643c4f91d41a6f4f72994061a95f45f307ffab7c667d55d81581",
    "physical.json": "eba997ff8fcb3cca2040d7237778fe29e19553383aee330c0155e2f5e44806dd",
    "source.toml": "557e9ad9e2a496ee0f29ae34b5db40a05ceddd7e8f8ed5ddf9a7ee0b78edc722",
    "resource.toml": "296b86cff9f25fbe83e60f6efaddb2b3f59474d7d9ff53df83eb054bc1ea0efa",
}
HERE = Path(__file__).resolve().parent
GEOMETRY = ("vertices", "faces", "faceMaterials", "faceTextures")


def read(root, name):
    data = (root / name).read_bytes()
    if sha256(data).hexdigest() != PINS[name]:
        raise ValueError(f"Changed input {name}")
    return tomllib.loads(data.decode()) if name.endswith(".toml") else json.loads(data)


def local(mesh, part):
    v, f = part["vertexStart"], part["faceStart"]
    end = f + part["faceCount"]
    return (mesh["vertices"][v:v + part["vertexCount"]],
            [[i-v for i in face] for face in mesh["faces"][f:end]],
            mesh["faceMaterials"][f:end], mesh["faceTextures"][f:end])


def expand_recess(current, original, loft):
    before, _, _, _ = current
    source, source_faces, source_materials, source_uvs = original
    # Use the exact twelve-point exposed cap and preserve the inboard octagon.
    rings = [tuple(range(12)), tuple(1.5 * i for i in range(8))]
    keys, faces = loft["ring_loft"](rings)
    points = [source[int(key)] if key < 12 else before[8 + round((key - 12) / 1.5)]
              for key in keys]
    cap = [(face, material, uv) for face, material, uv in
           zip(source_faces, source_materials, source_uvs) if max(face) < 12]
    if len(cap) != 10 or set(source_materials) != {6}:
        raise ValueError("Unexpected original cap or appearance")
    retained = {int(key): i for i, key in enumerate(keys) if key < 12}
    side_faces = [face for face in faces if not all(keys[i] < 12 for i in face)]
    return (points, [[retained[i] for i in face] for face, _, _ in cap] + side_faces,
            [6] * (len(cap) + len(side_faces)),
            [uv for _, _, uv in cap] +
            [loft["uv_for_face"]([points[i] for i in face], 6) for face in side_faces])


def emit(root, name, payload):
    with (root / name).open("x") as stream:
        json.dump(payload, stream, sort_keys=True, separators=(",", ":"), allow_nan=False)
        stream.write("\n")


def main(root):
    inputs = {name: read(root, name) for name in PINS}
    source, resource = inputs["source.toml"], inputs["resource.toml"]
    old = inputs["candidate.json"]
    reference = inputs["reference.json"]["nativeDesign"]
    record = inputs["physical.json"]
    if (source["proposal"]["id"], resource["id"], old["id"], record["id"]) != ("SH063",) * 4:
        raise ValueError("Expected independent Seriema sources")
    if (resource["design"] != source["design"] or source["nativeDesign"] != reference
            or record["detailedSourceSHA256"] != PINS["source.toml"]
            or old["originalSourceSHA256"] != PINS["source.toml"]):
        raise ValueError("Render, native source and physical calibration differ")

    loft = runpy.run_path(str(HERE.parents[2] / "Tools/authoring/sh023_native_topology.py"))
    verifier = runpy.run_path(str(HERE / "freeze-sh169-crest.py"))
    clearance = runpy.run_path(str(HERE / "naval-plans/measure-initial-pair-muzzles.py"))
    old_mesh = old["nativeDesign"]
    design = {key: [] if key in GEOMETRY else value for key, value in old_mesh.items()}
    source_parts = inputs["criteria.json"]["parts"]["originalPartRanges"]
    parts = []
    for part, source_part in zip(old["parts"], source_parts, strict=True):
        current = local(old_mesh, part)
        original = local(reference, source_part)
        if part["index"] in (10, 13):
            current = expand_recess(current, original, loft)
        if "explicit military mount" in part["name"] and current != original:
            raise ValueError("Changed authored mount geometry or appearance")
        points, faces, materials, textures = current
        v, f = len(design["vertices"]), len(design["faces"])
        parts.append(dict(part, vertexStart=v, vertexCount=len(points), faceStart=f,
                          faceCount=len(faces)))
        design["vertices"].extend(points)
        design["faces"].extend([[i + v for i in face] for face in faces])
        design["faceMaterials"].extend(materials)
        design["faceTextures"].extend(textures)
    calibration = Fraction(record["metresPerSourceUnitExact"])
    scale = float(calibration)
    vertices = np.asarray(design["vertices"]) * scale
    triangles = vertices[design["faces"]]
    if len(triangles) != 512 or len(parts) != 20:
        raise ValueError("Unexpected revised collision budget")
    owners = verifier["verify_parts"](design["faces"], triangles, parts)
    all_faces = np.arange(len(triangles))
    witness = inputs["witness.json"]
    for ray in witness["rays"]:
        verifier["verify_ray"](ray, ray["hits"]["candidate"], all_faces, triangles, owners, scale)
    rays_by_name = {ray["name"]: ray for ray in witness["rays"]}
    for isolated in witness["isolated"]:
        ray = rays_by_name[isolated["name"]]
        expected = isolated["hits"]["candidate"]
        subset = np.flatnonzero(owners == expected["part"])
        verifier["verify_ray"](ray, expected, subset, triangles, owners, scale)

    old_triangles = (np.asarray(old_mesh["vertices"]) * scale)[old_mesh["faces"]]
    source_triangles = (np.asarray(reference["vertices"]) * scale)[reference["faces"]]
    render = resource["design"]
    render_triangles = (np.asarray(render["vertices"]) * scale)[render["faces"]]
    ray_hit = verifier["RAY_HIT"]
    drive_probes = []
    mounts = []
    for sign, part in ((-1, 17), (1, 19)):
        for degrees in (30, 60, 120, 150, 210, 240, 300, 330):
            angle = np.deg2rad(degrees)
            origin = np.array([sign * .48 + .122 * np.cos(angle), .122 * np.sin(angle), -2.1])
            hits = [ray_hit(mesh, origin * scale, np.array([0, 0, 1]), .13 * scale)
                    for mesh in (source_triangles, old_triangles, triangles)]
            if hits[0] is None or hits[2] is None or (
                abs(hits[0][1] - hits[2][1]) > 1e-8 or owners[hits[2][0]] not in (10, 13)
                or (hits[1] is not None and hits[1][1] <= hits[2][1] + 1e-8)
            ):
                raise ValueError(f"Expected original exposed cap at {origin}: {hits}")
            drive_probes.append(dict(originMetres=(origin * scale).tolist(), direction=[0, 0, 1],
                                     limitMetres=.13 * scale,
                                     depthsMetres=[None if h is None else h[1] for h in hits]))
        backing = np.array([sign * .264, -.43, 1.238]) * scale
        muzzle = backing + [0, 0, .2]
        for mesh in (source_triangles, triangles, render_triangles):
            clearance["prove_clearance"](mesh, muzzle)
            backing_hit = ray_hit(mesh, muzzle, np.array([0, 0, -1]), .3)
            if backing_hit is None or abs(backing_hit[1] - .2) > 1e-8:
                raise ValueError("Mount backing differs between authored meshes")
        hit = ray_hit(triangles, muzzle, np.array([0, 0, -1]), .3)
        if hit is None or owners[hit[0]] != part or abs(hit[1] - .2) > 1e-8:
            raise ValueError("Expected authored rail directly behind the muzzle")
        mounts.append(dict(backingPart=part, backingMetres=backing.tolist(),
                           muzzleMetres=muzzle.tolist(), axis=[0, 0, 1],
                           forwardClearanceLowerBoundMetres=.1))

    emit(root, "SH063-collision-candidate.json", dict(
        schemaVersion=1, status="SOURCE_GEOMETRY_ONLY", catalogueID="SH063",
        coordinateUnits="metres", forwardAxis="+Z", upAxis="+Y", calibration=str(calibration),
        parts=parts, nativeDesign={**design, "vertices": vertices.tolist()}))
    emit(root, "SH063-source-witness.json", dict(
        inputSHA256=PINS, renderResource="Sources/L337Core/Resources/Ships/SH063.toml",
        renderSection="design", calibration=str(calibration), mounts=mounts, driveProbes=drive_probes,
        retainedRays=len(witness["rays"]) + len(witness["isolated"]),
        collisionSHA256=sha256((root / "SH063-collision-candidate.json").read_bytes()).hexdigest()))


if __name__ == "__main__":
    main(Path(sys.argv[1]))
