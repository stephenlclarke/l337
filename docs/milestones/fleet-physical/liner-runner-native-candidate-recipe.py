"""Complete actual SH088/SH089 open-arc native candidates; G1 alone may generate.

Two separate real IDs/families share only their genuine creator code branch.
All16 components remain PER entry, including both arc crossmembers, FOUR wells,
BOTH bow endcaps and full cockpit/drives. No family/identity/crew/source fallback,
installed hardware/people, paid kit, actor, acquisition or save authority is issued.
"""

import hashlib
import json
import math
import tomllib


CREATOR_SHA256 = "3f029d5a417dea1b787dc5f0327d72687822275cc372de79790c3531e7cba429"
PRIMITIVE_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"
FAMILY_SHA256 = "a792c7b4ec0665bc42a515262957bd3c6830c672379462ac2ac6145d4964f2ba"

# NEW approximations only; actual complete counts/profile/void fidelity UNKNOWN.
LOFT_SIDES = 8
ARC_SEGMENTS = 12
ARC_MINOR_SAMPLES = 4

PINS = {
    "SH088": {
        "name": "Springbok Starliner",
        "sourceSHA256": "8382b438252441ae6bb373bf307f7d341ec4d5d16fc525ab8d3edfa8cefbb8de",
        "resourceSHA256": "9472ffe6e4ad44a82238624f50f4ef10b67f9364e8befc23dfa41f7a137f9606",
        "r3SHA256": "a68eca7fb52dba02989f82a1c23a1201ac4ce28b2125f9a6a357fd4eb785ee82",
        "archetype": "arc-liner",
        "palette": "violet-pearl",
        "length": 4.4,
        "beam": 2.4,
        "family": "springbok",
        "creatorRole": "leisure"
    },
    "SH089": {
        "name": "Antelope",
        "sourceSHA256": "75eaa16f5496ef1164f9665d1ee98da814d309562421addb3f86e78b778ed4d5",
        "resourceSHA256": "64111eb6f1dca889d1d8db7de4f8bc711f184425a899848daad43f529b858eef",
        "r3SHA256": "92cdce3357540ac17a213a8f5f034d0fc58f7af6e3b541539c951d45e0439d65",
        "archetype": "arc-runner",
        "palette": "sage-umber",
        "length": 3.2,
        "beam": 2.1,
        "family": "antelope",
        "creatorRole": "trader"
    }
}


def build_candidate_native(identity, creator, *, source_bytes, creator_bytes,
                           primitive_bytes, resource_bytes, family_bytes):
    """Require one actual per-ID source/resource; never substitute another entry."""
    if identity not in PINS:
        raise ValueError("Only actual IDs088/089 have candidate source inputs")
    expected = PINS[identity]
    for label, data, digest in [
        ("original per-ID source", source_bytes, expected["sourceSHA256"]),
        ("current per-ID resource", resource_bytes, expected["resourceSHA256"]),
        ("original fleet creator", creator_bytes, CREATOR_SHA256),
        ("original Hull primitives", primitive_bytes, PRIMITIVE_SHA256),
        ("original family input", family_bytes, FAMILY_SHA256),
    ]:
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError(label + " changed or belongs to another actual entry")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    resource = tomllib.loads(resource_bytes.decode("utf-8"))
    proposal = source["proposal"]
    if (proposal["id"], proposal["archetype"], proposal["palette"],
            proposal["forwardAxis"], proposal["upAxis"], resource["id"], resource["name"]) != (
            identity, expected["archetype"], expected["palette"], "+Z", "+Y", identity, expected["name"]):
        raise ValueError("Actual entry identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Each actual entry retains its own ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged entry changed its OWN original " + key)
    ships = json.loads(family_bytes)["ships"]
    members = [s for s in ships if s["family"] == expected["family"]]
    if len(members) != 1 or members[0]["id"] != identity or members[0]["role"] != expected["creatorRole"]:
        raise ValueError("Actual original family/sole-mark/creator role changed")
    # Exact original RECIPES[SH088] or RECIPES[SH089], both sole-family marks.
    length, beam = expected["length"], expected["beam"]
    hull = creator.Mesh(expected["palette"], native=True)
    if hull.vertices or hull.faces or hull.face_materials:
        raise ValueError("Use a fresh genuine Mesh, never original/live geometry")
    hull.sides = LOFT_SIDES
    parts = []

    def part(name, materials, operation):
        first_vertex, first_face = len(hull.vertices), len(hull.faces)
        operation()
        if len(hull.vertices) <= first_vertex or len(hull.faces) <= first_face:
            raise ValueError("Candidate omitted actual entry part: " + name)
        if set(hull.face_materials[first_face:]) != set(materials):
            raise ValueError("Candidate changed actual part materials: " + name)
        parts.append({
            "index": len(parts), "name": name,
            "vertexStart": first_vertex, "vertexCount": len(hull.vertices) - first_vertex,
            "faceStart": first_face, "faceCount": len(hull.faces) - first_face,
            "originalMaterialIndices": list(materials),
        })
    def open_loop():
        # Exact genuine torus axis='y' equations and both capped open ends.
        # Keep the ORIGINAL angular gap; never close/fill the horseshoe bow.
        start, end = math.pi / 2 + .25, math.pi / 2 + math.tau - .25
        steps, minor = ARC_SEGMENTS, ARC_MINOR_SAMPLES
        points, faces = [], []
        for i in range(steps + 1):
            angle = start + (end - start) * i / steps
            for j in range(minor):
                theta = math.tau * j / minor
                points.append([
                    (beam * .46 + .15 * math.cos(theta)) * math.cos(angle),
                    -.04 - .15 * math.sin(theta),
                    (length * .44 + .15 * math.cos(theta)) * math.sin(angle),
                ])
        for i in range(steps):
            for j in range(minor):
                k = (j + 1) % minor
                faces.append([i * minor + j, (i + 1) * minor + j,
                              (i + 1) * minor + k, i * minor + k])
        faces += [list(range(minor)),
                  list(reversed(range(steps * minor, (steps + 1) * minor)))]
        hull.raw(points, faces, 1)
    part("open curved loop", [1], open_loop)
    stations = []
    width, pod_length = beam * .20, length * .76

    def primary_pod():
        stations.extend(hull.pod((0, .16, 0), pod_length, width, .27, 0, False))
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
    # Both extra crossmembers in the actual arc-liner AND arc-runner branch.
    for z in [-length * .27, length * .25]:
        part("arc transverse connected support", [2],
             lambda: hull.box((0, .10, z), (beam * .70, .16, .22), 2))
    part("cockpit glazing envelope", [5],
         lambda: hull.pod((0, .43, length * .24), .52, .26, .26 * .55, 5, False))
    part("cockpit connected structural crossmember", [2],
         lambda: hull.strut((-.26 * .85, .43, length * .24 - .10),
                            (.26 * .85, .43, length * .24 - .10), .020, .025, 2))
    for side, label in [(-1, "negative side"), (1, "positive side")]:
        x, y, z, radius = side * beam * .38, 0, -length * .43, .19
        part("engine_pair/" + label + "/connected support", [1],
             lambda: hull.strut((side * .12, .12, -length * .23),
                                (x, y, z + .12), .10, .11, 1))
        part("engine_pair/" + label + "/propulsion casing", [1],
             lambda: hull.loft([(z - .10, radius, radius, x, y),
                                (z + .18, radius * 1.13, radius * 1.13, x, y)], hull.sides, 1))
        part("engine_pair/" + label + "/propulsion luminous recess", [6],
             lambda: hull.loft([(z - .118, radius * .70, radius * .70, x, y),
                                (z - .105, radius * .70, radius * .70, x, y)], hull.sides, 6))
    if len(parts) != 16:
        raise ValueError("All16 original actual entry parts must remain")
    if len(hull.faces) > 512:
        raise ValueError("Complete actual entry candidate exceeds512; no omission/cap waiver")
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
        "id": identity, "originalSourceSHA256": expected["sourceSHA256"],
        "r3SHA256": expected["r3SHA256"], "nativeCandidate": model, "parts": parts,
        "coordinateRule": "Original coordinates; no rescale/recentre/unit inference",
        "unproven": [
            "complete source-profile/material/UV/void fidelity and actual native collision",
            "actual occupied environment and installed system approval",
            "installed hardware/power/people and empty/loaded mass, COM/full tensor",
            "genuine production, EMP/salvage/acquisition and current-save journeys",
        ],
    }
