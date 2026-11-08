"""Complete SH163 Lammergeier source candidate; G1 alone may generate/qualify.

All21 original native components remain, including ALL EIGHT sawback blades, FOUR
recessed service wells, complete cockpit/support and both full drives/recesses.
No installed hardware/power, people, paid equipment or acquisition is issued.
"""

import hashlib
import math
import tomllib


SOURCE_SHA256 = "35c56db12a269759f3c87d95be388022146d95bfa4f8b8e4e09a4214cc84c9cc"
CREATOR_SHA256 = "3f029d5a417dea1b787dc5f0327d72687822275cc372de79790c3531e7cba429"
PRIMITIVE_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"
RESOURCE_SHA256 = "eefd1e476efca3ece00b5d2ba418eeb40798a6420f785a5a19b05b60fdfeb479"
R3_SHA256 = "305f10a91b6567072c62194bb67e4dafbc43b4d5bd6604696c05f2e43d278ba6"

# NEW angular approximation only; actual count/fidelity remain UNKNOWN.
LOFT_SIDES = 8


def build_candidate_native(creator, *, source_bytes, creator_bytes, primitive_bytes,
                           resource_bytes):
    """Return a complete candidate without modifying any original or game resource."""
    for label, data, expected in [
        ("original SH163 source", source_bytes, SOURCE_SHA256),
        ("original fleet creator", creator_bytes, CREATOR_SHA256),
        ("original Hull primitives", primitive_bytes, PRIMITIVE_SHA256),
        ("current SH163 resource", resource_bytes, RESOURCE_SHA256),
    ]:
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(label + " changed; reconcile actual source before generation")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    resource = tomllib.loads(resource_bytes.decode("utf-8"))
    proposal = source["proposal"]
    if (proposal["id"], proposal["archetype"], proposal["palette"],
            proposal["forwardAxis"], proposal["upAxis"], resource["id"]) != (
            "SH163", "sawback", "rust-ivory", "+Z", "+Y", "SH163"):
        raise ValueError("Original Lammergeier identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Lammergeier must retain its actual current ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged Lammergeier changed original " + key)
    # Exact original RECIPES[SH163]; Lammergeier is its family's sole mark.
    length, beam = 4.3, 2.00
    hull = creator.Mesh("rust-ivory", native=True)
    if hull.vertices or hull.faces or hull.face_materials:
        raise ValueError("Use a fresh genuine Mesh, never the original/live body")
    hull.sides = LOFT_SIDES
    parts = []

    def part(name, materials, operation):
        first_vertex, first_face = len(hull.vertices), len(hull.faces)
        operation()
        if len(hull.vertices) <= first_vertex or len(hull.faces) <= first_face:
            raise ValueError("Candidate omitted original part: " + name)
        if set(hull.face_materials[first_face:]) != set(materials):
            raise ValueError("Candidate changed actual part materials: " + name)
        parts.append({
            "index": len(parts), "name": name,
            "vertexStart": first_vertex, "vertexCount": len(hull.vertices) - first_vertex,
            "faceStart": first_face, "faceCount": len(hull.faces) - first_face,
            "originalMaterialIndices": list(materials),
        })

    stations = []
    width, pod_length = .34, length

    def primary_pod():
        stations.extend(hull.pod((0, 0, 0), pod_length, width, .26, 0, False))
    part("body primary pressure envelope", [0], primary_pod)
    # Preserve all FOUR actual analytical native service recesses, including rims.
    for index, angle in enumerate([.72, 2.42, 3.86, 5.56]):
        z0, z1 = stations[0][0], stations[-1][0]
        z = z0 + (z1 - z0) * .26
        rx, ry, cx, cy = creator.base.station_at(stations, z)
        normal = creator.np.array([math.cos(angle) / rx, math.sin(angle) / ry, 0])
        normal /= creator.np.linalg.norm(normal)
        tangent = creator.np.array([-rx * math.sin(angle), ry * math.cos(angle), 0])
        tangent /= creator.np.linalg.norm(tangent)
        centre = creator.np.array([cx + rx * math.cos(angle), cy + ry * math.sin(angle), z]) + normal * .012
        part("body primary pressure envelope/service-well-" + str(index) + "-0", [0, 3],
             lambda: hull.well(centre, tangent, [0, 0, 1], normal,
                               min(.30, width * .66), min(.35, pod_length * .17), 0))
    # Exact sawback count4 PER side, eight complete original blades total.
    for side in [-1, 1]:
        for z in creator.np.linspace(-length * .32, length * .28, 4):
            part("sawback blade", [1],
                 lambda: hull.wing([(side * .22, z - .22),
                                    (side * beam * .50, z - .46),
                                    (side * beam * .45, z + .03),
                                    (side * .22, z + .15)], -.05, .13, 1))
    part("cockpit glazing envelope", [5],
         lambda: hull.pod((0, .32, length * .28), .50, .22, .22 * .55, 5, False))
    part("cockpit connected structural crossmember", [2],
         lambda: hull.strut((-.22 * .85, .32, length * .28 - .10),
                            (.22 * .85, .32, length * .28 - .10), .020, .025, 2))
    for side, label in [(-1, "negative side"), (1, "positive side")]:
        x, y, z, radius = side * beam * .38, 0, -length * .43, .22
        part("engine_pair/" + label + "/connected support", [1],
             lambda: hull.strut((side * .12, .12, -length * .23),
                                (x, y, z + .12), .10, .11, 1))
        part("engine_pair/" + label + "/propulsion casing", [1],
             lambda: hull.loft([(z - .10, radius, radius, x, y),
                                (z + .18, radius * 1.13, radius * 1.13, x, y)], hull.sides, 1))
        part("engine_pair/" + label + "/propulsion luminous recess", [6],
             lambda: hull.loft([(z - .118, radius * .70, radius * .70, x, y),
                                (z - .105, radius * .70, radius * .70, x, y)], hull.sides, 6))
    if len(parts) != 21:
        raise ValueError("All21 original Lammergeier parts must remain")
    if len(hull.faces) > 512:
        raise ValueError("Complete Lammergeier candidate exceeds512; no omission/cap waiver")
    hull.checked()
    model = creator.mesh_dict(hull, adaptation=False)
    original = source["nativeDesign"]
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
        "id": "SH163", "originalSourceSHA256": SOURCE_SHA256,
        "r3SHA256": R3_SHA256, "nativeCandidate": model, "parts": parts,
        "coordinateRule": "Original coordinates; no rescale/recentre/unit inference",
        "unproven": [
            "complete source-profile/material/UV/void fidelity and actual native collision",
            "actual occupied environment and installed system approval",
            "installed hardware/power/people and empty/loaded mass, COM/full tensor",
            "genuine production, EMP/salvage/acquisition and current-save journeys",
        ],
    }
