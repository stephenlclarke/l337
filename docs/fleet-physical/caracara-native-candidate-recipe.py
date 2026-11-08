"""Complete TWO actual Caracara native source candidates; G1 alone may generate.

Closed explicit IDs169/170 share the genuine creator's mark formula, never an
identity/source/crew fallback. Every variant retains all21 original raised-collar parts, including BOTH complete collars/tubes/holes.
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
LOFT_SIDES = 6
COLLAR_SEGMENTS = 8
COLLAR_MINOR_SAMPLES = 4

PINS = {
    "SH169": {
        "name": "Caracara Mk I",
        "sourceSHA256": "6257767fbb2cd35db071004b197f8f5655251f87ca3398e176343d12c0fb7b1c",
        "resourceSHA256": "1ffb117ac1f05b759d9e06c52fdd0fdb4d7d4b7aa3cae3d1fdbe6998111f195d",
        "r3SHA256": "45ee45d2ed594bf07c527138655844269d6c8987740d8f547cc8ef4818f0a2e1"
    },
    "SH170": {
        "name": "Caracara Mk II",
        "sourceSHA256": "db011887f67e1ae1c5f235fe2b7c4db4a65b29b37906a830433d69d9c8a5527b",
        "resourceSHA256": "e8412b14817fbf9035dcbc9be730f0626455fb8f66fe2655419bcfac2fef5de1",
        "r3SHA256": "5a9cafeee5de8e9c7d022fbd697a05c7205653e213f106fe5f09521a14a3b799"
    }
}


def build_candidate_native(identity, creator, *, source_bytes, creator_bytes,
                           primitive_bytes, resource_bytes, family_bytes):
    """Require one actual per-ID source/resource; never substitute a family member."""
    if identity not in PINS:
        raise ValueError("Only actual Caracara IDs169/170 have candidate inputs")
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
            identity, "raised-collar", "petrol-brass", "+Z", "+Y", identity, expected["name"]):
        raise ValueError("Actual Caracara identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Each Caracara retains its own actual ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged member changed its own original " + key)
    ships = json.loads(family_bytes)["ships"]
    members = sorted(s["id"] for s in ships if s["family"] == "caracara")
    if members != ["SH169", "SH170"] or any(
            s["role"] != "military" for s in ships if s["id"] in members):
        raise ValueError("Genuine Caracara family/creator role changed")
    # Exact RECIPES[SH169] and genuine make_fleet_hull mark formula.
    mark = members.index(identity)
    length = 3.0 * (1 + .035 * mark)
    beam = 2.15 * (1 + .025 * mark)
    hull = creator.Mesh("petrol-brass", native=True)
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
    width, pod_length = .39, length * .92

    def primary_pod():
        stations.extend(hull.pod((0, 0, 0), pod_length, width, .27, 0, False))
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
    def closed_collar(z):
        # Exact genuine full torus axis='z' equations/topology. BOTH original
        # collars retain complete tubes and actual central holes, no omitted arc.
        steps, minor = COLLAR_SEGMENTS, COLLAR_MINOR_SAMPLES
        points, faces = [], []
        for i in range(steps):
            angle = math.tau * i / steps
            for j in range(minor):
                theta = math.tau * j / minor
                points.append([
                    (beam * .30 + .11 * math.cos(theta)) * math.cos(angle),
                    (beam * .37 + .11 * math.cos(theta)) * math.sin(angle),
                    z + .11 * math.sin(theta),
                ])
        for i in range(steps):
            row = (i + 1) % steps
            for j in range(minor):
                k = (j + 1) % minor
                faces.append([i * minor + j, row * minor + j,
                              row * minor + k, i * minor + k])
        hull.raw(points, faces, 0)
    for z in [-length * .18, length * .17]:
        part("raised structural collar", [0], lambda: closed_collar(z))
    for index, side in enumerate([-1, 1]):
        part("wing_pair member " + str(index), [0],
             lambda: hull.wing([(side * .22, -length * .26),
                                (side * beam * .45, -length * .30 + .10),
                                (side * beam * .45, length * .06 + .10),
                                (side * .22, length * .26)], -.14, .12, 0))
    part("cockpit glazing envelope", [5],
         lambda: hull.pod((0, .34, length * .24), .54, .22, .22 * .55, 5, False))
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
