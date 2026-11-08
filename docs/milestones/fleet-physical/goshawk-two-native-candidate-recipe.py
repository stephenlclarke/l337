"""Complete TWO actual Goshawk variant native source candidates; G1 alone may generate.

Closed explicit IDs010/011 share the genuine creator's mark formula, never an
identity/source/crew fallback. Every variant retains all31 original native parts.
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
LOFT_SIDES = 3
# NEW coarse triangular angular proposal; full continuous fidelity UNKNOWN.

PINS = {
    "SH010": {
        "name": "Goshawk Mk II Custom",
        "sourceSHA256": "3e131707177a4b934ad969dc62da49963adf9aa6a71985e6dcf21c8ba9dd179c",
        "resourceSHA256": "66f8a18a52854fad92f8c0b1cb76ef3d0b6f7405d6e8e66e944b1b9e63bb89d3",
        "r3SHA256": "755f776227dcb1d7816b5e426fbe239a98f0f9d1df46fc1ebdbd90c5b15e5983"
    },
    "SH011": {
        "name": "Goshawk Scout",
        "sourceSHA256": "f0e1bf789ccad1f445f9d576c03affc853b7beb41b6820c03739b7e45a5e6884",
        "resourceSHA256": "dec7c21964fd5e4521cde5c07fae024eb8c926607fc9223b2a3667830600729e",
        "r3SHA256": "2d61d0afa8810dfec66208bee0b5b95555f64ddd9d2df76ce54b9a5c8a7c8ad1"
    }
}


def build_candidate_native(identity, creator, *, source_bytes, creator_bytes,
                           primitive_bytes, resource_bytes, family_bytes):
    """Require one actual per-ID source/resource; never substitute a family member."""
    if identity not in PINS:
        raise ValueError("Only actual Goshawk IDs010/011 have candidate inputs")
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
            identity, "wishbone", "forest-silver", "+Z", "+Y", identity, expected["name"]):
        raise ValueError("Actual Goshawk identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Each Goshawk retains its own actual ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged member changed its own original " + key)
    ships = json.loads(family_bytes)["ships"]
    members = sorted(s["id"] for s in ships if s["family"] == "goshawk")
    if members != ["SH008", "SH009", "SH010", "SH011"] or any(
            s["role"] != "military" or s["objectKind"] != "ship"
            for s in ships if s["id"] in PINS):
        raise ValueError("Genuine Goshawk family/variant roles changed")
    # Original RECIPES[SH008] and mark2/3 over ALL FOUR actual family members.
    # PINS admits only010/011; existing008/009 resources stay untouched.
    mark = members.index(identity)
    length = 3.8 * (1 + .035 * mark)
    beam = 2.20 * (1 + .025 * mark)
    hull = creator.Mesh("forest-silver", native=True)
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
    for side in [-1, 1]:
        part("wishbone connected arm", [1],
             lambda: hull.strut((side * .12, -.09, -length * .40),
                                (side * beam * .46, -.09, length * .34), .27, .27, 1))
        complete_pod("wishbone forward envelope", (side * beam * .38, -.09, length * .20),
                     length * .26, .22, .19, 0)
    part("wishbone forward cross bridge", [2],
         lambda: hull.box((0, .19, length * .18), (beam * .76, .17, .29), 2))
    part("aft transverse bridge", [2],
         lambda: hull.box((0, .16, -length * .24), (beam * .65, .18, .28), 2))
    complete_pod("body primary pressure envelope", (0, .17, -length * .10),
                 length * .53, .27, .23, 0)
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
    # Original military role emits all FOUR structural mount pieces.
    for side in [-1, 1]:
        x, y, z = side * beam * .22, -.31, length * .22
        part("explicit military mount upright", [2],
             lambda: hull.strut((x, y + .15, z), (x, y - .12, z), .09, .11, 2))
        part("explicit military mount longitudinal member", [3],
             lambda: hull.strut((x, y - .12, z - .18), (x, y - .12, z + .27), .07, .07, 3))
    if len(parts) != 31:
        raise ValueError("All31 original per-member components must remain")
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
