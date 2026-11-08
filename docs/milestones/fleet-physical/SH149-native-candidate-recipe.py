"""Complete SH149 Owlet Mk II source candidate; G1 alone may generate/qualify.

All30 original native components remain: both complete forkpods/centralbody,
ALL twelve wells, BOTH deep keel envelopes/bridge, full cockpit/drives/FOUR mounts.
NEW all-triangular curved components are coarse, not qualified source fidelity.
No installed hardware/power, people, paid equipment or acquisition is issued.
"""

import hashlib
import math
import tomllib


SOURCE_SHA256 = "4759ef063f9c3ad2b1f733a2eb975744b3e6c34b8531a6a03bad8b1aed5fb595"
CREATOR_SHA256 = "3f029d5a417dea1b787dc5f0327d72687822275cc372de79790c3531e7cba429"
PRIMITIVE_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"
RESOURCE_SHA256 = "b7ac93115e5fb82440e8ffb466ab29616c14265e14641aa8f1c1e3acdefb96c1"
R3_SHA256 = "0000721bfa356c4bf251e1cc8ef5569595f3ac5628190fdb9789e21d7c73f4f2"

# NEW angular approximation only; actual count/fidelity remain UNKNOWN.
LOFT_SIDES = 3
# NEW coarse angular proposal; every original station/radius remains.


def build_candidate_native(creator, *, source_bytes, creator_bytes, primitive_bytes,
                           resource_bytes):
    """Return a complete candidate without modifying any original or game resource."""
    for label, data, expected in [
        ("original SH149 source", source_bytes, SOURCE_SHA256),
        ("original fleet creator", creator_bytes, CREATOR_SHA256),
        ("original Hull primitives", primitive_bytes, PRIMITIVE_SHA256),
        ("current SH149 resource", resource_bytes, RESOURCE_SHA256),
    ]:
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(label + " changed; reconcile actual source before generation")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    resource = tomllib.loads(resource_bytes.decode("utf-8"))
    proposal = source["proposal"]
    if (proposal["id"], proposal["archetype"], proposal["palette"],
            proposal["forwardAxis"], proposal["upAxis"], resource["id"]) != (
            "SH149", "fork-keel", "plum-gold", "+Z", "+Y", "SH149"):
        raise ValueError("Original Owlet Mk II identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Owlet Mk II must retain its actual current ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged Owlet Mk II changed original " + key)
    # Exact original RECIPES[SH149]; Owlet Mk II is its family's sole mark.
    length, beam = 3.7, 1.65
    hull = creator.Mesh("plum-gold", native=True)
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

    def complete_pod(name, centre, pod_length, width, height, material):
        stations = []

        def original_pod():
            stations.extend(hull.pod(centre, pod_length, width, height, material, False))
        part(name, [material], original_pod)
        for index, angle in enumerate([.72, 2.42, 3.86, 5.56]):
            z0, z1 = stations[0][0], stations[-1][0]
            z = z0 + (z1 - z0) * .26
            rx, ry, cx, cy = creator.base.station_at(stations, z)
            normal = creator.np.array([math.cos(angle) / rx, math.sin(angle) / ry, 0])
            normal /= creator.np.linalg.norm(normal)
            tangent = creator.np.array([-rx * math.sin(angle), ry * math.cos(angle), 0])
            tangent /= creator.np.linalg.norm(tangent)
            well_centre = creator.np.array([cx + rx * math.cos(angle), cy + ry * math.sin(angle), z]) + normal * .012
            part(name + "/service-well-" + str(index) + "-0", [material, 3],
                 lambda: hull.well(well_centre, tangent, [0, 0, 1], normal,
                                   min(.30, width * .66), min(.35, pod_length * .17), material))
    # Exact original fork branch: BOTH forward pods with all FOUR wells each.
    z = 0
    for member, x in enumerate([-beam * .34, beam * .34]):
        width = beam * .20
        complete_pod("pods explicit member " + str(member), (x, -.10, z),
                     length * .91, width, width * .72, 0)
    for side in [-1, 1]:
        part("fork longitudinal envelope", [1],
             lambda: hull.box((side * beam * .34, -.22, z), (.20, .51, length * .65), 1))
    part("fork aft cross bridge", [2],
         lambda: hull.box((0, .18, -length * .24), (beam * .72, .22, .38), 2))
    complete_pod("body primary pressure envelope", (0, .28, -length * .11),
                 length * .55, .28, .23, 0)
    part("cockpit glazing envelope", [5],
         lambda: hull.pod((0, .55, length * .06), .51, .23, .23 * .55, 5, False))
    part("cockpit connected structural crossmember", [2],
         lambda: hull.strut((-.23 * .85, .55, length * .06 - .10),
                            (.23 * .85, .55, length * .06 - .10), .020, .025, 2))
    for side, label in [(-1, "negative side"), (1, "positive side")]:
        x, y, z, radius = side * beam * .38, 0, -length * .43, .23
        part("engine_pair/" + label + "/connected support", [1],
             lambda: hull.strut((side * .12, .12, -length * .23),
                                (x, y, z + .12), .10, .11, 1))
        part("engine_pair/" + label + "/propulsion casing", [1],
             lambda: hull.loft([(z - .10, radius, radius, x, y),
                                (z + .18, radius * 1.13, radius * 1.13, x, y)], hull.sides, 1))
        part("engine_pair/" + label + "/propulsion luminous recess", [6],
             lambda: hull.loft([(z - .118, radius * .70, radius * .70, x, y),
                                (z - .105, radius * .70, radius * .70, x, y)], hull.sides, 6))
    # Original bountyHunter role emits all FOUR structural mount pieces.
    for side in [-1, 1]:
        x, y, z = side * beam * .22, -.31, length * .22
        part("explicit military mount upright", [2],
             lambda: hull.strut((x, y + .15, z), (x, y - .12, z), .09, .11, 2))
        part("explicit military mount longitudinal member", [3],
             lambda: hull.strut((x, y - .12, z - .18), (x, y - .12, z + .27), .07, .07, 3))
    if len(parts) != 30:
        raise ValueError("All30 original Owlet Mk II parts must remain")
    if len(hull.faces) > 512:
        raise ValueError("Complete Owlet Mk II candidate exceeds512; no omission/cap waiver")
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
        "id": "SH149", "originalSourceSHA256": SOURCE_SHA256,
        "r3SHA256": R3_SHA256, "nativeCandidate": model, "parts": parts,
        "coordinateRule": "Original coordinates; no rescale/recentre/unit inference",
        "unproven": [
            "complete source-profile/material/UV/void fidelity and actual native collision",
            "actual occupied environment and installed system approval",
            "installed hardware/power/people and empty/loaded mass, COM/full tensor",
            "genuine production, EMP/salvage/acquisition and current-save journeys",
        ],
    }
