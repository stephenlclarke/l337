"""SH124 complete eight-part native candidate; only G1 may generate/qualify.

Retain both closed lobes, all FOUR end growths (including exact mirrored copies),
central growth and luminous aft part. Sampling changes are a new approximation,
not shape/profile/void fidelity, hardware, people or native qualification.
"""

import hashlib
import math
import tomllib


SOURCE_SHA256 = "1715f8fc7da8e0a7e3c0c17534087477b443508c174a0a4da4eb158829438732"
CREATOR_SHA256 = "3f029d5a417dea1b787dc5f0327d72687822275cc372de79790c3531e7cba429"
PRIMITIVE_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"
RESOURCE_SHA256 = "3a655b112425ad29131513cc6c3734c2cf54415b5c2e187eb865f6aa19990e5d"
R3_SHA256 = "851502c15a6922797e9c650e8a126fd73ce7ccc76f5e1419a870625c72abe21e"

# New sampling proposal only; count and actual source fidelity remain UNKNOWN.
LOFT_SIDES = 6
LOBE_SEGMENTS = 8
LOBE_MINOR_SAMPLES = 4


def build_candidate_native(creator, *, source_bytes, creator_bytes,
                           primitive_bytes, resource_bytes):
    """Build the actual per-ID candidate without installing/writing any resource."""
    for label, data, expected in [
        ("original SH124 source", source_bytes, SOURCE_SHA256),
        ("original fleet creator", creator_bytes, CREATOR_SHA256),
        ("original Hull primitives", primitive_bytes, PRIMITIVE_SHA256),
        ("current SH124 resource", resource_bytes, RESOURCE_SHA256),
    ]:
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(label + " changed; reconcile actual source before generation")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    resource = tomllib.loads(resource_bytes.decode("utf-8"))
    proposal = source["proposal"]
    if (proposal["id"], proposal["archetype"], proposal["palette"],
            proposal["forwardAxis"], proposal["upAxis"], resource["id"]) != (
            "SH124", "alien-lobes", "jade", "+Z", "+Y", "SH124"):
        raise ValueError("Original Warship identity/recipe/frame changed")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged Warship changed original " + key)
    hull = creator.Mesh("jade", native=True)
    if hull.vertices or hull.faces or hull.face_materials:
        raise ValueError("Use a fresh genuine Mesh; never modify the original/live body")
    hull.sides = LOFT_SIDES
    parts = []

    def part(name, material, operation):
        first_vertex, first_face = len(hull.vertices), len(hull.faces)
        operation()
        if len(hull.vertices) <= first_vertex or len(hull.faces) <= first_face:
            raise ValueError("Candidate omitted original part: " + name)
        if set(hull.face_materials[first_face:]) != {material}:
            raise ValueError("Candidate changed original material: " + name)
        parts.append({
            "index": len(parts), "name": name,
            "vertexStart": first_vertex, "vertexCount": len(hull.vertices) - first_vertex,
            "faceStart": first_face, "faceCount": len(hull.faces) - first_face,
            "originalMaterialIndex": material,
        })

    def closed_lobe(centre, rx, ry, tube):
        # Exact genuine Mesh.torus axis='y' equations, full closed360deg topology.
        # Both original lobes retain their full tube and open central void.
        steps, minor = LOBE_SEGMENTS, LOBE_MINOR_SAMPLES
        points, faces = [], []
        for i in range(steps):
            angle = math.tau * i / steps
            for j in range(minor):
                theta = math.tau * j / minor
                points.append([
                    centre[0] + (rx + tube * math.cos(theta)) * math.cos(angle),
                    centre[1] - tube * math.sin(theta),
                    centre[2] + (ry + tube * math.cos(theta)) * math.sin(angle),
                ])
        for i in range(steps):
            row = (i + 1) % steps
            for j in range(minor):
                k = (j + 1) % minor
                faces.append([i * minor + j, row * minor + j,
                              row * minor + k, i * minor + k])
        hull.raw(points, faces, 0)

    # Exact original SH124 row: alien-lobes/jade/length3.5/beam2.70/modules2.
    length, beam = 3.5, 2.70
    for side in [-1, 1]:
        part("closed alien lobe", 0,
             lambda: closed_lobe((side * .40, 0, -.10), beam * .27, length * .43, .22))
        first_vertex, first_face = len(hull.vertices), len(hull.faces)
        part("existing alien end growth", 0,
             lambda: hull.pod((side * beam * .34, -.08, -length * .14),
                              length * .74, .28, .19, 0, False))
        # Reflect this growth alone in original z=-.10 plane and reverse winding.
        # Never reflect the lobe or discard either fore/aft growth.
        growth = creator.np.array(hull.vertices[first_vertex:])
        growth[:, 2] = -.20 - growth[:, 2]
        faces = [[c - first_vertex, b - first_vertex, a - first_vertex]
                 for a, b, c in hull.faces[first_face:]]
        part("exact reflected copy of alien end growth", 0,
             lambda: hull.raw(growth, faces, 0))
    part("central alien structural growth", 2,
         lambda: hull.pod((0, .06, -.10), length * .65, .12, .12, 2, False))
    part("alien luminous aft organ", 6,
         lambda: hull.pod((0, -.08, -length * .35), length * .16, .16, .08, 6, False))
    if len(parts) != 8:
        raise ValueError("All eight original Warship parts must remain")
    if len(hull.faces) > 512:
        raise ValueError("Complete Warship candidate exceeds512; no omission/cap waiver")
    hull.checked()
    model = creator.mesh_dict(hull, adaptation=False)
    original = source["nativeDesign"]
    # UV/face assignments are regenerated by the genuine serializer. All other
    # appearance, material/emission, texture and license fields stay exact.
    geometry_keys = {"vertices", "faces", "faceMaterials", "faceTextures"}
    if model.keys() != original.keys():
        raise ValueError("Candidate serializer changed original fields")
    for key in original.keys() - geometry_keys:
        if model[key] != original[key]:
            raise ValueError("Candidate changed original appearance/source: " + key)
    if len(model["faceTextures"]) != len(model["faces"]):
        raise ValueError("Candidate lost per-face UV/texture mapping")
    if set(model["faceMaterials"]) != set(original["faceMaterials"]):
        raise ValueError("Candidate lost an original material")
    return {
        "status": "GENERATED_CANDIDATE_ONLY_NOT_INSTALLED_OR_NATIVE_QUALIFIED",
        "id": "SH124", "originalSourceSHA256": SOURCE_SHA256,
        "r3SHA256": R3_SHA256, "nativeCandidate": model, "parts": parts,
        "coordinateRule": "Original coordinates; no rescale/recentre/unit inference",
        "unproven": [
            "complete source-profile/material/UV/central-void fidelity",
            "actual native collision and occupied environment qualification",
            "installed hardware/power/people and empty/loaded mass, COM/full tensor",
            "genuine production/EMP/salvage/acquisition/current-save journeys",
        ],
    }
