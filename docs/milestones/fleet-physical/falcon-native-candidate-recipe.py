"""Complete FOUR actual Falcon native source candidates; G1 alone may generate.

Closed explicit IDs136/137/138/139 share the genuine creator's mark formula, never an
identity/source/crew fallback. Every variant retains all21 original split-keel parts, including all six wells.
Only angular sampling changes; no actor, installed hardware, people, paid kit,
acquisition, mission or current-save authority is created by these candidates.
"""

import hashlib
import json
import math
import tomllib


CREATOR_SHA256 = "3f029d5a417dea1b787dc5f0327d72687822275cc372de79790c3531e7cba429"
PRIMITIVE_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"
FAMILY_SHA256 = "a792c7b4ec0665bc42a515262957bd3c6830c672379462ac2ac6145d4964f2ba"

# NEW approximation only; actual counts/profile/void fidelity remain UNKNOWN.
LOFT_SIDES = 8

PINS = {
    "SH136": {
        "name": "Falcon Mk I",
        "sourceSHA256": "fdbf3fb120a965482dcf3f00cca9b27598f881aab297911f4ba802c17a90a6fc",
        "resourceSHA256": "c602702e4b5045ffad669cad5b8c777029b04d2e30b19d6e5fa13837b181b677",
        "r3SHA256": "7ab120fd7e6a97467bc5faf76d4bbb6f616d933219ea07e3845acf3ea5595625"
    },
    "SH137": {
        "name": "Falcon Mk II",
        "sourceSHA256": "1ae68958ef5c8372692b3540b03a3ce699c8de8f247958b06e5f18d344d78137",
        "resourceSHA256": "2893d72e520571aae41c2a0623e8d70ed806dec267a875aa6f8318427965409b",
        "r3SHA256": "773713dedad2f1352d296b425a65ddeb2abebc3681c7201f6a9b42f78fd3012e"
    },
    "SH138": {
        "name": "Falcon Mk III",
        "sourceSHA256": "459a954252a56474df93d17d5e7e103d5cf2918af442c1630a26e65cb5e309ef",
        "resourceSHA256": "203d759a6df714cf7ea721c13650e1a29f8cc442ca4ba2e274265884ae7c94e5",
        "r3SHA256": "7e1f9e93799c01e265397bc4737c99932c6f910142c68d06a0ba701711373814"
    },
    "SH139": {
        "name": "Falcon Mk IV",
        "sourceSHA256": "2c55c3a5c5d954684cc71cf7ee9c6420771cd2f1243d1cb888f89f9f3e0cee39",
        "resourceSHA256": "5aef4995471fb4cf5741a563894a96323db3390a8718e6bfa892516307ac5da7",
        "r3SHA256": "d033cfb048e5fb53bb9688bc4841b7bb9476431401c6a8e1f1c82c5d3945e19c"
    }
}


def build_candidate_native(identity, creator, *, source_bytes, creator_bytes,
                           primitive_bytes, resource_bytes, family_bytes):
    """Require one actual per-ID source/resource; never substitute a family member."""
    if identity not in PINS:
        raise ValueError("Only actual Falcon IDs136/137/138/139 have candidate inputs")
    expected = PINS[identity]
    for label, data, digest in [
        ("original per-ID source", source_bytes, expected["sourceSHA256"]),
        ("current per-ID resource", resource_bytes, expected["resourceSHA256"]),
        ("original fleet creator", creator_bytes, CREATOR_SHA256),
        ("original Hull primitives", primitive_bytes, PRIMITIVE_SHA256),
        ("original family input", family_bytes, FAMILY_SHA256),
    ]:
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError(label + " changed or belongs to another member")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    resource = tomllib.loads(resource_bytes.decode("utf-8"))
    proposal = source["proposal"]
    if (proposal["id"], proposal["archetype"], proposal["palette"],
            proposal["forwardAxis"], proposal["upAxis"], resource["id"], resource["name"]) != (
            identity, "split-keel", "ice-blue", "+Z", "+Y", identity, expected["name"]):
        raise ValueError("Actual Falcon identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Each Falcon retains its own actual ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged member changed its own original " + key)
    ships = json.loads(family_bytes)["ships"]
    members = sorted(s["id"] for s in ships if s["family"] == "falcon")
    if members != ["SH136", "SH137", "SH138", "SH139"] or any(
            s["role"] != "military" for s in ships if s["id"] in members):
        raise ValueError("Genuine Falcon family/creator role changed")
    # Exact RECIPES[SH136] and genuine make_fleet_hull mark formula.
    mark = members.index(identity)
    length = 3.1 * (1 + .035 * mark)
    beam = 1.95 * (1 + .025 * mark)
    hull = creator.Mesh("ice-blue", native=True)
    if hull.vertices or hull.faces or hull.face_materials:
        raise ValueError("Use a fresh genuine Mesh, never the original/live body")
    hull.sides = LOFT_SIDES
    parts = []

    def part(name, materials, operation):
        first_vertex, first_face = len(hull.vertices), len(hull.faces)
        operation()
        if len(hull.vertices) <= first_vertex or len(hull.faces) <= first_face:
            raise ValueError("Candidate omitted actual member part: " + name)
        if set(hull.face_materials[first_face:]) != set(materials):
            raise ValueError("Candidate changed original part material: " + name)
        parts.append({
            "index": len(parts), "name": name,
            "vertexStart": first_vertex, "vertexCount": len(hull.vertices) - first_vertex,
            "faceStart": first_face, "faceCount": len(hull.faces) - first_face,
            "originalMaterialIndices": list(materials),
        })
    stations = []
    width, pod_length = .27, length * .66

    def primary_pod():
        stations.extend(hull.pod((0, .24, .08), pod_length, width, .24, 0, False))
    part("body primary pressure envelope", [0], primary_pod)
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
    for index, side in enumerate([-1, 1]):
        part("split keel vertical envelope", [1],
             lambda: hull.box((side * beam * .29, -.14, -.04), (.20, .94, length * .83), 1))
        part("wing structural member", [0],
             lambda: hull.wing([(side * .18, -length * .20), (side * beam * .47, -length * .31),
                                (side * beam * .46, -.04), (side * .18, .14)], -.26, .12, 0))
        x, y, z, radius = side * beam * .29, -.31, -length * .47, .22
        # BOTH original explicit keel drive parts; no invented engine_pair support.
        part("split keel explicit drive " + str(index) + "/propulsion casing", [1],
             lambda: hull.loft([(z - .10, radius, radius, x, y),
                                (z + .18, radius * 1.13, radius * 1.13, x, y)], hull.sides, 1))
        part("split keel explicit drive " + str(index) + "/propulsion luminous recess", [6],
             lambda: hull.loft([(z - .118, radius * .70, radius * .70, x, y),
                                (z - .105, radius * .70, radius * .70, x, y)], hull.sides, 6))
        part("split keel recessed service well", [1, 3],
             lambda: hull.well([side * beam * .29, .35, .08],
                               [1, 0, 0], [0, 0, -1], [0, 1, 0], .17, .32, 1))
    part("cockpit glazing envelope", [5],
         lambda: hull.pod((0, .52, length * .23), .45, .22, .22 * .55, 5, False))
    part("cockpit connected structural crossmember", [2],
         lambda: hull.strut((-.22 * .85, .52, length * .23 - .10),
                            (.22 * .85, .52, length * .23 - .10), .020, .025, 2))
    # Genuine original military structural mounts, not installed guns/paid kit.
    for side in [-1, 1]:
        x, y, z = side * beam * .22, -.31, length * .22
        part("explicit military mount upright", [2],
             lambda: hull.strut((x, y + .15, z), (x, y - .12, z), .09, .11, 2))
        part("explicit military mount longitudinal member", [3],
             lambda: hull.strut((x, y - .12, z - .18), (x, y - .12, z + .27), .07, .07, 3))
    if len(parts) != 21:
        raise ValueError("All21 original per-member components must remain")
    if len(hull.faces) > 512:
        raise ValueError("Complete actual member exceeds512; no omission/cap waiver")
    hull.checked()
    model = creator.mesh_dict(hull, adaptation=False)
    original = source["nativeDesign"]
    geometry_keys = {"vertices", "faces", "faceMaterials", "faceTextures"}
    if model.keys() != original.keys():
        raise ValueError("Candidate serializer changed member fields")
    for key in original.keys() - geometry_keys:
        if model[key] != original[key]:
            raise ValueError("Candidate changed member appearance/source: " + key)
    if len(model["faceTextures"]) != len(model["faces"]):
        raise ValueError("Candidate lost per-face UV/texture mapping")
    if set(model["faceMaterials"]) != set(original["faceMaterials"]):
        raise ValueError("Candidate lost an actual member material")
    return {
        "status": "GENERATED_CANDIDATE_ONLY_NOT_INSTALLED_OR_NATIVE_QUALIFIED",
        "id": identity, "originalSourceSHA256": expected["sourceSHA256"],
        "r3SHA256": expected["r3SHA256"], "nativeCandidate": model, "parts": parts,
        "coordinateRule": "Own original coordinates; no rescale/recentre/unit inference",
        "unproven": [
            "complete actual member curved-profile/void/material/UV fidelity",
            "actual native collision, occupied environment and installed systems",
            "hardware/power/people and empty/loaded mass, COM/full tensor",
            "genuine production, EMP/salvage/acquisition and current-save journeys",
        ],
    }
