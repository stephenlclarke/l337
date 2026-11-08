"""Complete SH066 Rabbit Explorer source candidate; G1 alone may generate/qualify.

All14 original native components remain, including the actual OPEN oval-shuttle
arc/BOTH endcaps, ALL four wells and complete cockpit/support/drives. The source
name never converts the original arc into a closed ring.
No installed hardware/power, people, paid equipment or acquisition is issued.
"""

import hashlib
import math
import tomllib


SOURCE_SHA256 = "9ade27660044661f97105983b4995184ab7347aadf2efb5e62ae5d030b0f12e5"
CREATOR_SHA256 = "3f029d5a417dea1b787dc5f0327d72687822275cc372de79790c3531e7cba429"
PRIMITIVE_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"
RESOURCE_SHA256 = "c5f34e04e9b37b254834729e64e28b3d44fbebbecb83cff1cc53ebb089911cae"
R3_SHA256 = "10fe257691fbe5ee08953837dd65002ec547c02362a1f09436ab97d78e515676"

# NEW angular approximation only; actual count/fidelity remain UNKNOWN.
LOFT_SIDES = 8
ARC_SEGMENTS = 12
ARC_MINOR_SAMPLES = 4


def build_candidate_native(creator, *, source_bytes, creator_bytes, primitive_bytes,
                           resource_bytes):
    """Return a complete candidate without modifying any original or game resource."""
    for label, data, expected in [
        ("original SH066 source", source_bytes, SOURCE_SHA256),
        ("original fleet creator", creator_bytes, CREATOR_SHA256),
        ("original Hull primitives", primitive_bytes, PRIMITIVE_SHA256),
        ("current SH066 resource", resource_bytes, RESOURCE_SHA256),
    ]:
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(label + " changed; reconcile actual source before generation")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    resource = tomllib.loads(resource_bytes.decode("utf-8"))
    proposal = source["proposal"]
    if (proposal["id"], proposal["archetype"], proposal["palette"],
            proposal["forwardAxis"], proposal["upAxis"], resource["id"]) != (
            "SH066", "oval-shuttle", "violet-pearl", "+Z", "+Y", "SH066"):
        raise ValueError("Original Rabbit Explorer identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Rabbit Explorer must retain its actual current ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged Rabbit Explorer changed original " + key)
    # Exact original RECIPES[SH066]; Rabbit Explorer is its family's sole mark.
    length, beam = 2.6, 2.00
    hull = creator.Mesh("violet-pearl", native=True)
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
        raise ValueError("All14 original Rabbit Explorer parts must remain")
    if len(hull.faces) > 512:
        raise ValueError("Complete Rabbit Explorer candidate exceeds512; no omission/cap waiver")
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
        "id": "SH066", "originalSourceSHA256": SOURCE_SHA256,
        "r3SHA256": R3_SHA256, "nativeCandidate": model, "parts": parts,
        "coordinateRule": "Original coordinates; no rescale/recentre/unit inference",
        "unproven": [
            "complete source-profile/material/UV/void fidelity and actual native collision",
            "actual occupied environment and installed system approval",
            "installed hardware/power/people and empty/loaded mass, COM/full tensor",
            "genuine production, EMP/salvage/acquisition and current-save journeys",
        ],
    }
