"""Complete TWO actual Tapir native source candidates; G1 alone may generate.

Closed explicit IDs105/106 share the genuine creator's mark formula, never an
identity/source/crew fallback. Each variant retains all14 parts and its genuinely axisZ closed protective loop.
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
LOOP_SEGMENTS = 16
LOOP_MINOR_SAMPLES = 4

PINS = {
    "SH105": {
        "name": "Tapir Shuttle",
        "sourceSHA256": "daf3fa9551a9f488edbcfd5ee164507616cf120b43f912c07171a3ddead2d96e",
        "resourceSHA256": "86315197347263bc0e94b7ad76792cfef8144f3ae4a3f02df35b63a9d7664063",
        "r3SHA256": "c3e044e23e9f4c87d9d9f06318d5bda37e2a5d79d2c69a4e727a99039701c489"
    },
    "SH106": {
        "name": "Tapir Mk II",
        "sourceSHA256": "20131f3bbc888dc52c51e0e950a50a7b2ee72ce62c47cf42dae0151d5db8fc65",
        "resourceSHA256": "280c0ad039985f509ccb4c4f3778c3c2f4ca2e81ae9db60af69c623e4f9ac16c",
        "r3SHA256": "3afaae56e461c018053ee63f4629b4ec9412fa0fa34d80e954d8dd315a5a3ff3"
    }
}


def build_candidate_native(identity, creator, *, source_bytes, creator_bytes,
                           primitive_bytes, resource_bytes, family_bytes):
    """Require one actual per-ID source/resource; never substitute a family member."""
    if identity not in PINS:
        raise ValueError("Only actual Tapir IDs105/106 have candidate inputs")
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
            identity, "shuttle-loop", "ivory-teal", "+Z", "+Y", identity, expected["name"]):
        raise ValueError("Actual Tapir identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Each Tapir retains its own actual ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged member changed its own original " + key)
    ships = json.loads(family_bytes)["ships"]
    members = sorted(s["id"] for s in ships if s["family"] == "tapir")
    if members != ["SH105", "SH106"] or any(
            s["role"] != "transporter" for s in ships if s["id"] in members):
        raise ValueError("Genuine Tapir family/creator role changed")
    # Exact RECIPES[SH105] and genuine make_fleet_hull mark formula.
    mark = members.index(identity)
    length = 2.7 * (1 + .035 * mark)
    beam = 1.80 * (1 + .025 * mark)
    hull = creator.Mesh("ivory-teal", native=True)
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
    def closed_loop():
        # Genuine Mesh.torus full closed360deg axis='z' equations/topology.
        # Keep the entire tube and central opening, including the last/first join.
        steps, minor = LOOP_SEGMENTS, LOOP_MINOR_SAMPLES
        points, faces = [], []
        for i in range(steps):
            angle = math.tau * i / steps
            for j in range(minor):
                theta = math.tau * j / minor
                points.append([
                    (beam * .48 + .14 * math.cos(theta)) * math.cos(angle),
                    .16 + (.90 + .14 * math.cos(theta)) * math.sin(angle),
                    .14 * math.sin(theta),
                ])
        for i in range(steps):
            row = (i + 1) % steps
            for j in range(minor):
                k = (j + 1) % minor
                faces.append([i * minor + j, row * minor + j,
                              row * minor + k, i * minor + k])
        hull.raw(points, faces, 0)
    part("closed shuttle loop", [0], closed_loop)
    stations = []
    width, pod_length = .38, length * .86

    def primary_pod():
        stations.extend(hull.pod((0, -.18, 0), pod_length, width, .30, 0, False))
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
    if len(parts) != 14:
        raise ValueError("All14 original actual Tapir member parts must remain")
    if len(hull.faces) > 512:
        raise ValueError("Complete actual Tapir member candidate exceeds512; no omission/cap waiver")
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
