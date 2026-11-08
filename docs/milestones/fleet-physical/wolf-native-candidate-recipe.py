"""Complete FOUR actual Wolf ship native source candidates; G1 alone may generate.

Closed explicit IDs157/158/159/160 share the genuine creator's mark formula, never an
identity/source/crew fallback. Every variant retains all29 original native parts.
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
MAIN_LOFT_SIDES = 6
COCKPIT_SIDES = 4
DRIVE_SIDES = 4

PINS = {
    "SH157": {
        "name": "Wolf Scout",
        "sourceSHA256": "065e52fa27d9d46ea52229e7a7135e5d6b49bb2d39edcb50a16fd1154cf30e0c",
        "resourceSHA256": "98b1f12fa74ed0434501e8de2d9acda4d192ef7d2d29297f1ef1ca638f14f506",
        "r3SHA256": "f0d74284c9d18ebf3116b8750fdc39f8aa1adefc36b73009230b879c4fd9d961"
    },
    "SH158": {
        "name": "Wolf Mk I",
        "sourceSHA256": "2a4f09b965f5fcbb38105bb3a11a4fe9245a6cf6be93895bcf888b06a9219a3b",
        "resourceSHA256": "5bce93d8cf1fdc578d608a5634a9b42e064f71a3f9cf3408eb99cd43c9e4189f",
        "r3SHA256": "08748137eeec587b584f66faa9d6139c7a41b45d9ed8920aa1498eb2f50ae024"
    },
    "SH159": {
        "name": "Wolf Mk II",
        "sourceSHA256": "6a683a22e7fb9238426da2f284d1eacb29bb008b4b3514208d18e666af0569eb",
        "resourceSHA256": "8f35cdf40aa1464b2ce1562fb7b12da535d7dee3a13bdeb66601203dbd75bf6a",
        "r3SHA256": "3e9dace75fa8fea326ff95d4137a49dd3b6918a86bcb1daeaaa7a9605e06d55a"
    },
    "SH160": {
        "name": "Wolf Cutter",
        "sourceSHA256": "febeb15ca6ed5dc6b53b3c59f8405edec733ff85af13f923fab3122d14f73083",
        "resourceSHA256": "085dbdafb20e8f4487d8dcefb298e17ec2e41e22ef1bac8c4d6d61b6f236a9cf",
        "r3SHA256": "59dd3fc84c4188f5b16873859cfab2eaafd28bba688e25d1cdb52b9b1ee9419e"
    }
}


def build_candidate_native(identity, creator, *, source_bytes, creator_bytes,
                           primitive_bytes, resource_bytes, family_bytes):
    """Require one actual per-ID source/resource; never substitute a family member."""
    if identity not in PINS:
        raise ValueError("Only actual Wolf IDs157/158/159/160 have candidate inputs")
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
            identity, "twin-spine", "navy-copper", "+Z", "+Y", identity, expected["name"]):
        raise ValueError("Actual Wolf identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Each Wolf retains its own actual ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged member changed its own original " + key)
    ships = json.loads(family_bytes)["ships"]
    members = sorted(s["id"] for s in ships if s["family"] == "wolf")
    if members != ["SH157", "SH158", "SH159", "SH160", "SH161"] or any(
            s["role"] != "military" or s["objectKind"] != "ship"
            for s in ships if s["id"] in PINS):
        raise ValueError("Genuine Wolf family/ship creator roles changed")
    # Genuine RECIPES[SH157] and mark formula over ALL FIVE family members.
    # PINS intentionally excludes Citadel161; its own station resource stays separate.
    mark = members.index(identity)
    length = 3.8 * (1 + .035 * mark)
    beam = 1.85 * (1 + .025 * mark)
    hull = creator.Mesh("navy-copper", native=True)
    if hull.vertices or hull.faces or hull.face_materials:
        raise ValueError("Use a fresh genuine Mesh, never the original/live body")
    hull.sides = MAIN_LOFT_SIDES
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
    hull.sides = COCKPIT_SIDES
    part("cockpit glazing envelope", [5],
         lambda: hull.pod((0, .29, length * .24), .42, .21, .21 * .55, 5, False))
    hull.sides = DRIVE_SIDES
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
    # Original military role emits all FOUR structural mount pieces.
    for side in [-1, 1]:
        x, y, z = side * beam * .22, -.31, length * .22
        part("explicit military mount upright", [2],
             lambda: hull.strut((x, y + .15, z), (x, y - .12, z), .09, .11, 2))
        part("explicit military mount longitudinal member", [3],
             lambda: hull.strut((x, y - .12, z - .18), (x, y - .12, z + .27), .07, .07, 3))
    if len(parts) != 29:
        raise ValueError("All29 original per-member components must remain")
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
