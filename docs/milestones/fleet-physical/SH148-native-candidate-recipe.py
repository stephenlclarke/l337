"""Complete SH148 Morepork source candidate; G1 alone may generate/qualify.

All24 original native components remain, including BOTH full body/shield envelopes,
ALL eight wells, both aft fins, complete cockpit/drives and four mount structures.
No installed hardware/power, people, paid equipment or acquisition is issued.
"""

import hashlib
import math
import tomllib


SOURCE_SHA256 = "c662ad791478a0709e2e136bcb70e3292665d48ac52d06c67e13a20d07879ecc"
CREATOR_SHA256 = "3f029d5a417dea1b787dc5f0327d72687822275cc372de79790c3531e7cba429"
PRIMITIVE_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"
RESOURCE_SHA256 = "d18070d603fd8331ea36797a691bcb5b3287d0e66effa5a0b5f191b686f8bb94"
R3_SHA256 = "2912c2fce8d5640f03b3847d8cdbe8f3bbcaff8981790a65ba9637160728bc57"

# NEW angular approximation only; actual count/fidelity remain UNKNOWN.
MAIN_LOFT_SIDES = 6
COCKPIT_SIDES = 4


def build_candidate_native(creator, *, source_bytes, creator_bytes, primitive_bytes,
                           resource_bytes):
    """Return a complete candidate without modifying any original or game resource."""
    for label, data, expected in [
        ("original SH148 source", source_bytes, SOURCE_SHA256),
        ("original fleet creator", creator_bytes, CREATOR_SHA256),
        ("original Hull primitives", primitive_bytes, PRIMITIVE_SHA256),
        ("current SH148 resource", resource_bytes, RESOURCE_SHA256),
    ]:
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(label + " changed; reconcile actual source before generation")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    resource = tomllib.loads(resource_bytes.decode("utf-8"))
    proposal = source["proposal"]
    if (proposal["id"], proposal["archetype"], proposal["palette"],
            proposal["forwardAxis"], proposal["upAxis"], resource["id"]) != (
            "SH148", "shield-fighter", "navy-copper", "+Z", "+Y", "SH148"):
        raise ValueError("Original Morepork identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Morepork must retain its actual current ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged Morepork changed original " + key)
    # Exact original RECIPES[SH148]; Morepork is its family's sole mark.
    length, beam = 2.7, 2.55
    hull = creator.Mesh("navy-copper", native=True)
    if hull.vertices or hull.faces or hull.face_materials:
        raise ValueError("Use a fresh genuine Mesh, never the original/live body")
    hull.sides = MAIN_LOFT_SIDES
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

    # Both original FIVE-station envelopes and all FOUR wells PER envelope.
    envelopes = [
        ("body primary pressure envelope", (0, 0, 0), length * .92, .39, .27),
        ("upper shielded pressure envelope", (0, .30, .08), length * .67, beam * .48, .13),
    ]
    for name, centre, pod_length, width, height in envelopes:
        stations = []

        def original_pod():
            stations.extend(hull.pod(centre, pod_length, width, height, 0, False))
        part(name, [0], original_pod)
        for index, angle in enumerate([.72, 2.42, 3.86, 5.56]):
            z0, z1 = stations[0][0], stations[-1][0]
            z = z0 + (z1 - z0) * .26
            rx, ry, cx, cy = creator.base.station_at(stations, z)
            normal = creator.np.array([math.cos(angle) / rx, math.sin(angle) / ry, 0])
            normal /= creator.np.linalg.norm(normal)
            tangent = creator.np.array([-rx * math.sin(angle), ry * math.cos(angle), 0])
            tangent /= creator.np.linalg.norm(tangent)
            well_centre = creator.np.array([cx + rx * math.cos(angle), cy + ry * math.sin(angle), z]) + normal * .012
            part(name + "/service-well-" + str(index) + "-0", [0, 3],
                 lambda: hull.well(well_centre, tangent, [0, 0, 1], normal,
                                   min(.30, width * .66), min(.35, pod_length * .17), 0))
    for side in [-1, 1]:
        part("shielded vertical aft support", [1],
             lambda: hull.box((side * beam * .35, .36, -length * .25), (.12, .65, .42), 1))
    # Explicit NEW cockpit-only angular proposal; keep all five original stations.
    hull.sides = COCKPIT_SIDES
    part("cockpit glazing envelope", [5],
         lambda: hull.pod((0, .34, length * .24), .54, .22, .22 * .55, 5, False))
    hull.sides = MAIN_LOFT_SIDES
    part("cockpit connected structural crossmember", [2],
         lambda: hull.strut((-.22 * .85, .34, length * .24 - .10),
                            (.22 * .85, .34, length * .24 - .10), .020, .025, 2))
    for side, label in [(-1, "negative side"), (1, "positive side")]:
        x, y, z, radius = side * beam * .42, 0, -length * .43, .20
        part("engine_pair/" + label + "/connected support", [1],
             lambda: hull.strut((side * .12, .12, -length * .23),
                                (x, y, z + .12), .10, .11, 1))
        part("engine_pair/" + label + "/propulsion casing", [1],
             lambda: hull.loft([(z - .10, radius, radius, x, y),
                                (z + .18, radius * 1.13, radius * 1.13, x, y)], hull.sides, 1))
        part("engine_pair/" + label + "/propulsion luminous recess", [6],
             lambda: hull.loft([(z - .118, radius * .70, radius * .70, x, y),
                                (z - .105, radius * .70, radius * .70, x, y)], hull.sides, 6))
    for side in [-1, 1]:
        x, y, z = side * beam * .22, -.31, length * .22
        part("explicit military mount upright", [2],
             lambda: hull.strut((x, y + .15, z), (x, y - .12, z), .09, .11, 2))
        part("explicit military mount longitudinal member", [3],
             lambda: hull.strut((x, y - .12, z - .18), (x, y - .12, z + .27), .07, .07, 3))
    if len(parts) != 24:
        raise ValueError("All24 original Morepork parts must remain")
    if len(hull.faces) > 512:
        raise ValueError("Complete Morepork candidate exceeds512; no omission/cap waiver")
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
        "id": "SH148", "originalSourceSHA256": SOURCE_SHA256,
        "r3SHA256": R3_SHA256, "nativeCandidate": model, "parts": parts,
        "coordinateRule": "Original coordinates; no rescale/recentre/unit inference",
        "unproven": [
            "complete source-profile/material/UV/void fidelity and actual native collision",
            "actual occupied environment and installed system approval",
            "installed hardware/power/people and empty/loaded mass, COM/full tensor",
            "genuine production, EMP/salvage/acquisition and current-save journeys",
        ],
    }
