"""Unexecuted SH162 three-part native source proposal; only G1 may generate it.

Retain primary envelope, open capped structural arc and luminous aft part. No
biological/propulsion/people/power role is inferred. New sampling is not fidelity,
cap success, actual physical hardware, mission producer or native qualification.
"""

import hashlib
import math
import tomllib


SOURCE_SHA256 = "14d4e261029ca1fcf61a2688c43c192e17c7e523a268ffb9c9b726b087b14151"
CREATOR_SHA256 = "3f029d5a417dea1b787dc5f0327d72687822275cc372de79790c3531e7cba429"
PRIMITIVE_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"

# NEW angular sampling proposal; generated count/fidelity remain unknown.
LOFT_SIDES = 8
ARC_SEGMENTS = 8
ARC_MINOR_SAMPLES = 4


def build_candidate_native(creator, *, source_bytes, creator_bytes, primitive_bytes):
    """G1 supplies the genuine pinned creator; return a candidate, never install it."""
    for label, data, expected in [
        ("SH162 source", source_bytes, SOURCE_SHA256),
        ("original fleet creator", creator_bytes, CREATOR_SHA256),
        ("original Hull primitives", primitive_bytes, PRIMITIVE_SHA256),
    ]:
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(label + " changed; review actual source before generation")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    proposal = source["proposal"]
    if (proposal["id"], proposal["archetype"], proposal["palette"],
            proposal["forwardAxis"], proposal["upAxis"]) != (
            "SH162", "alien-probe", "jade", "+Z", "+Y"):
        raise ValueError("Original SH162 recipe/frame changed")
    # No source unit/calibration inference, no translation/rescale/recentering.
    hull = creator.Mesh("jade", native=True)
    if hull.vertices or hull.faces or hull.face_materials:
        raise ValueError("Original Mesh constructor did not supply a fresh buffer")
    hull.sides = LOFT_SIDES
    parts = []

    def part(name, material, operation):
        vertex_start, face_start = len(hull.vertices), len(hull.faces)
        operation()
        if len(hull.vertices) <= vertex_start or len(hull.faces) <= face_start:
            raise ValueError("Candidate omitted original part: " + name)
        if set(hull.face_materials[face_start:]) != {material}:
            raise ValueError("Candidate changed original part material: " + name)
        parts.append({
            "index": len(parts), "name": name,
            "vertexStart": vertex_start, "vertexCount": len(hull.vertices) - vertex_start,
            "faceStart": face_start, "faceCount": len(hull.faces) - face_start,
            "originalMaterialIndex": material,
        })

    def original_open_arc(centre, rx, ry, tube, start, end):
        # Pinned Mesh.torus axis='y' equations/topology including BOTH end caps.
        # The source arc stays open; never close its gap or remove its tube/ends.
        segments, minor = ARC_SEGMENTS, ARC_MINOR_SAMPLES
        rows = segments + 1
        points, polygons = [], []
        for i in range(rows):
            angle = start + (end - start) * i / segments
            for j in range(minor):
                theta = math.tau * j / minor
                points.append([
                    centre[0] + (rx + tube * math.cos(theta)) * math.cos(angle),
                    centre[1] - tube * math.sin(theta),
                    centre[2] + (ry + tube * math.cos(theta)) * math.sin(angle),
                ])
        for i in range(segments):
            row = i + 1
            for j in range(minor):
                k = (j + 1) % minor
                polygons.append([i * minor + j, row * minor + j,
                                 row * minor + k, i * minor + k])
        polygons += [list(range(minor)),
                     list(reversed(range((rows - 1) * minor, rows * minor)))]
        hull.raw(points, polygons, 2)

    # Exact SH162 creator row and alien-probe branch parameters. Both pods use
    # the original five longitudinal stations and both closed end caps.
    length, beam = 2.0, 1.45
    part("alien probe primary envelope", 0,
         lambda: hull.pod((0, 0, .10), length * .83, beam * .32, .22, 0, False))
    part("alien probe open structural arc", 2,
         lambda: original_open_arc((.19, 0, -.10), beam * .44,
                                   length * .48, .07, .3, math.tau - .3))
    part("alien luminous aft organ", 6,
         lambda: hull.pod((0, -.08, -length * .35), length * .16, .16, .08, 6, False))
    if len(parts) != 3:
        raise ValueError("All three original SH162 parts must remain")
    if len(hull.faces) > 512:
        raise ValueError("Complete candidate exceeds512; no omission or cap waiver")
    hull.checked()
    model = creator.mesh_dict(hull, adaptation=False)
    for key in ["materials", "textures", "paletteName", "appearanceLicense", "appearanceSource"]:
        if model[key] != source["nativeDesign"][key]:
            raise ValueError("Candidate appearance differs from original: " + key)
    if len(model["faceTextures"]) != len(model["faces"]):
        raise ValueError("Candidate has missing per-face texture mapping")
    return {
        "status": "GENERATED_CANDIDATE_ONLY_NOT_INSTALLED_OR_NATIVE_QUALIFIED",
        "id": "SH162", "originalSourceSHA256": SOURCE_SHA256,
        "coordinateRule": "Original source coordinates; no rescale/recentre/unit inference",
        "nativeCandidate": model, "parts": parts,
        "unproven": [
            "complete detailed-source shape/profile/material/void fidelity, including the actual arc gap",
            "actual calibration, closed collision admission and native qualification",
            "actual installed hardware/power/physical components and loaded mass/COM/full tensor",
            "genuine mission producer/ownership/current-save/cold/rollback acceptance",
        ],
    }
