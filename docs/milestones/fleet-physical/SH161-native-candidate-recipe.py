"""Complete SH161 Citadel source candidate; G1 alone may generate/qualify.

All31 original native components remain, including ALL ten recessed service wells,
two drive casings/recesses and six geometric docking-frame pieces. No operational
port/provider, pressure, installed hardware/power or zero-person census is inferred.
"""

import hashlib
import json
import math
import tomllib


SOURCE_SHA256 = "0335361ca8aac1cc868e380b3312e2ffb222318803329f5a10c70a21cdf89621"
CREATOR_SHA256 = "3f029d5a417dea1b787dc5f0327d72687822275cc372de79790c3531e7cba429"
PRIMITIVE_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"
RESOURCE_SHA256 = "7bf1de5fb1589f47a9ef65433f854e0645c97433f0e7cbe025d96851db813821"
FAMILY_SHA256 = "a792c7b4ec0665bc42a515262957bd3c6830c672379462ac2ac6145d4964f2ba"
R3_SHA256 = "354edb2f79b3b82e39dda176b9b68a6407172467547381e0a873665cb9d5e53b"

# NEW angular approximation only; actual count/fidelity remain UNKNOWN.
LOFT_SIDES = 4


def build_candidate_native(creator, *, source_bytes, creator_bytes, primitive_bytes,
                           resource_bytes, family_bytes):
    """Return a complete candidate without modifying any original or game resource."""
    for label, data, expected in [
        ("original SH161 source", source_bytes, SOURCE_SHA256),
        ("original fleet creator", creator_bytes, CREATOR_SHA256),
        ("original Hull primitives", primitive_bytes, PRIMITIVE_SHA256),
        ("current SH161 resource", resource_bytes, RESOURCE_SHA256),
        ("original family input", family_bytes, FAMILY_SHA256),
    ]:
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(label + " changed; reconcile actual source before generation")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    resource = tomllib.loads(resource_bytes.decode("utf-8"))
    proposal = source["proposal"]
    if (proposal["id"], proposal["archetype"], proposal["palette"],
            proposal["forwardAxis"], proposal["upAxis"], resource["id"]) != (
            "SH161", "twin-spine", "navy-copper", "+Z", "+Y", "SH161"):
        raise ValueError("Original Citadel identity/recipe/frame changed")
    if "game" in resource or resource["catalogue"]["objectKind"] != "station":
        raise ValueError("Citadel environment cannot borrow ordinary ship performance")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged Citadel changed original " + key)
    ships = json.loads(family_bytes)["ships"]
    actual = next((s for s in ships if s["id"] == "SH161"), None)
    if actual is None or actual["family"] != "wolf" or actual["role"] != "station":
        raise ValueError("Original Citadel family/station role changed")
    members = sorted(s["id"] for s in ships if s["family"] == actual["family"])
    if members != ["SH157", "SH158", "SH159", "SH160", "SH161"]:
        raise ValueError("Original Citadel mark index changed")
    # Exact original RECIPES[SH157] plus make_fleet_hull's explicit mark formula.
    mark = members.index("SH161")
    length = 3.8 * (1 + .035 * mark)
    beam = 1.85 * (1 + .025 * mark)
    hull = creator.Mesh("navy-copper", native=True)
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

    for side in [-1, 1]:
        part("twin spine pressure envelope", [0],
             lambda: hull.box((side * beam * .35, 0, 0), (.28, .68, length * .88), 0))
        part("twin spine shoulder envelope", [1],
             lambda: hull.box((side * beam * .35, .40, -length * .13), (.42, .16, length * .55), 1))
        for z in [-length * .25, 0, length * .25]:
            part("twin spine shoulder service well", [1, 3],
                 lambda: hull.well([side * beam * .35, .49, z],
                                   [1, 0, 0], [0, 0, -1], [0, 1, 0], .28, .30, 1))
    for z in [-length * .30, length * .15]:
        part("twin spine transverse bridge", [2],
             lambda: hull.box((0, -.20, z), (beam * .83, .18, .25), 2))
    stations = []

    def central_pod():
        stations.extend(hull.pod((0, .03, length * .13), length * .45, .25, .22, 0, False))
    part("twin spine central forward envelope", [0], central_pod)
    # Exact original Mesh.service native branch. Keep ALL four original wells;
    # sampling the envelope never removes the recessed shadow/rim geometry.
    for index, angle in enumerate([.72, 2.42, 3.86, 5.56]):
        z0, z1 = stations[0][0], stations[-1][0]
        z = z0 + (z1 - z0) * .26
        rx, ry, cx, cy = creator.base.station_at(stations, z)
        normal = creator.np.array([math.cos(angle) / rx, math.sin(angle) / ry, 0])
        normal /= creator.np.linalg.norm(normal)
        tangent = creator.np.array([-rx * math.sin(angle), ry * math.cos(angle), 0])
        tangent /= creator.np.linalg.norm(tangent)
        centre = creator.np.array([cx + rx * math.cos(angle), cy + ry * math.sin(angle), z]) + normal * .012
        part("twin spine central forward envelope/service-well-" + str(index) + "-0", [0, 3],
             lambda: hull.well(centre, tangent, [0, 0, 1], normal,
                               min(.30, .25 * .66), min(.35, length * .45 * .17), 0))
    part("cockpit glazing envelope", [5],
         lambda: hull.pod((0, .29, length * .24), .42, .21, .21 * .55, 5, False))
    part("cockpit connected structural crossmember", [2],
         lambda: hull.strut((-.21 * .85, .29, length * .24 - .10),
                            (.21 * .85, .29, length * .24 - .10), .020, .025, 2))
    for side, label in [(-1, "negative side"), (1, "positive side")]:
        x, y, z, radius = side * beam * .38, 0, -length * .43, .21
        part("engine_pair/" + label + "/connected support", [1],
             lambda: hull.strut((side * .12, .12, -length * .23),
                                (x, y, z + .12), .10, .11, 1))
        part("engine_pair/" + label + "/propulsion casing", [1],
             lambda: hull.loft([(z - .10, radius, radius, x, y),
                                (z + .18, radius * 1.13, radius * 1.13, x, y)], hull.sides, 1))
        part("engine_pair/" + label + "/propulsion luminous recess", [6],
             lambda: hull.loft([(z - .118, radius * .70, radius * .70, x, y),
                                (z - .105, radius * .70, radius * .70, x, y)], hull.sides, 6))
    # Exact SH161 twin-spine dock call. This is geometry, not a live port/service.
    width, height, z, depth, y = beam * .70, 1.15, length * .39, .70, -.16
    for index, side in enumerate([-1, 1]):
        part("dock lateral structural member " + str(index), [1],
             lambda: hull.box((side * width * .5, y, z), (.17, height, depth), 1))
    for index, sign in enumerate([-1, 1]):
        part("dock transverse structural member " + str(index), [0],
             lambda: hull.box((0, y + sign * height * .5, z), (width + .17, .17, depth), 0))
    for index, side in enumerate([-1, 1]):
        part("dock aperture guidance marker " + str(index), [6],
             lambda: hull.strut((side * width * .5, y - height * .42, z + depth * .51),
                                (side * width * .5, y + height * .42, z + depth * .51), .025, .025, 6))
    if len(parts) != 31:
        raise ValueError("All31 original Citadel parts must remain")
    if len(hull.faces) > 512:
        raise ValueError("Complete Citadel candidate exceeds512; no omission/cap waiver")
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
        "id": "SH161", "originalSourceSHA256": SOURCE_SHA256,
        "r3SHA256": R3_SHA256, "nativeCandidate": model, "parts": parts,
        "coordinateRule": "Original coordinates; no rescale/recentre/unit inference",
        "unproven": [
            "complete source-profile/material/UV/void fidelity and actual native collision",
            "actual operational dock/provider/service approval and occupied environment",
            "installed hardware/power/people and empty/loaded mass, COM/full tensor",
            "genuine station production, receiving and current-save journeys",
        ],
    }
