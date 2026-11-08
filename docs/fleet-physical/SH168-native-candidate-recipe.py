"""Complete SH168 Armadillo Miner source candidate; G1 alone may generate/qualify.

All21 original native components remain: four capped Z-axis half arches,
both complete literal-eight-sided boring heads/supports, four wells and full
cockpit/support/drives. Tool geometry is not operating mining equipment.
No installed hardware/power, people, paid equipment or acquisition is issued.
"""

import hashlib
import math
import tomllib


SOURCE_SHA256 = "6b938c4b4879fa1e41b29fc1f1c81c5a950733937e8ad8337b5439854dca237f"
CREATOR_SHA256 = "3f029d5a417dea1b787dc5f0327d72687822275cc372de79790c3531e7cba429"
PRIMITIVE_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"
RESOURCE_SHA256 = "3d15c8d9d5113ea73d1953bc846f537cb93ece173ef1ba8c00a75817e165a6e9"
R3_SHA256 = "22b33bde70014ed2ef02dd07cf436a5dfc4ffb0c98887e614aae060d725c6087"

# NEW angular approximation only; actual count/fidelity remain UNKNOWN.
MAIN_LOFT_SIDES = 6
COCKPIT_SIDES = 4
DRIVE_SIDES = 4
ARCH_SEGMENTS = 4
ARCH_MINOR_SAMPLES = 4


def build_candidate_native(creator, *, source_bytes, creator_bytes, primitive_bytes,
                           resource_bytes):
    """Return a complete candidate without modifying any original or game resource."""
    for label, data, expected in [
        ("original SH168 source", source_bytes, SOURCE_SHA256),
        ("original fleet creator", creator_bytes, CREATOR_SHA256),
        ("original Hull primitives", primitive_bytes, PRIMITIVE_SHA256),
        ("current SH168 resource", resource_bytes, RESOURCE_SHA256),
    ]:
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(label + " changed; reconcile actual source before generation")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    resource = tomllib.loads(resource_bytes.decode("utf-8"))
    proposal = source["proposal"]
    if (proposal["id"], proposal["archetype"], proposal["palette"],
            proposal["forwardAxis"], proposal["upAxis"], resource["id"]) != (
            "SH168", "segmented-hopper", "slate-orange", "+Z", "+Y", "SH168"):
        raise ValueError("Original Armadillo Miner identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Armadillo Miner must retain its actual current ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged Armadillo Miner changed original " + key)
    # Exact original RECIPES[SH168]; Armadillo Miner is its family's sole mark.
    length, beam = 3.5, 2.20
    hull = creator.Mesh("slate-orange", native=True)
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

    stations = []
    width, pod_length = beam * .26, length * .70

    def primary_pod():
        stations.extend(hull.pod((0, .15, -length * .10), pod_length, width, .31, 0, False))
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

    def hopper_arch(z):
        # Genuine torus equations, original default axis Z and range0..pi.
        # NEW sampling only; keep every arch and BOTH real endcaps.
        steps, minor = ARCH_SEGMENTS, ARCH_MINOR_SAMPLES
        points, faces = [], []
        for i in range(steps + 1):
            angle = math.pi * i / steps
            for j in range(minor):
                theta = math.tau * j / minor
                points.append([
                    (beam * .42 + .12 * math.cos(theta)) * math.cos(angle),
                    -.06 + (.52 + .12 * math.cos(theta)) * math.sin(angle),
                    z + .12 * math.sin(theta),
                ])
        for i in range(steps):
            for j in range(minor):
                k = (j + 1) % minor
                faces.append([i * minor + j, (i + 1) * minor + j,
                              (i + 1) * minor + k, i * minor + k])
        faces += [list(range(minor)),
                  list(reversed(range(steps * minor, (steps + 1) * minor)))]
        hull.raw(points, faces, 1)
    for z in creator.np.linspace(-length * .30, length * .24, 4):
        part("open hopper collar", [1], lambda: hopper_arch(z))
    for side in [-1, 1]:
        x, z = side * beam * .27, length * .24
        part("boring-head structural support", [2],
             lambda: hull.strut((x, -.20, -.10), (x, -.20, z + .25), .13, .13, 2))
        # Original literal8 is independent of hull.sides. Keep ALL THREE stations.
        part("boring head", [2],
             lambda: hull.loft([(z, .15, .15, x, -.20),
                                (z + .42, .15, .15, x, -.20),
                                (z + .62, .018, .018, x, -.20)], 8, 2))
    # Explicit NEW cockpit-only angular proposal; keep all five original stations.
    hull.sides = COCKPIT_SIDES
    part("cockpit glazing envelope", [5],
         lambda: hull.pod((0, .48, -length * .08), .47, .24, .24 * .55, 5, False))
    hull.sides = DRIVE_SIDES
    part("cockpit connected structural crossmember", [2],
         lambda: hull.strut((-.24 * .85, .48, -length * .08 - .10),
                            (.24 * .85, .48, -length * .08 - .10), .020, .025, 2))
    for side, label in [(-1, "negative side"), (1, "positive side")]:
        x, y, z, radius = side * beam * .38, 0, -length * .43, .24
        part("engine_pair/" + label + "/connected support", [1],
             lambda: hull.strut((side * .12, .12, -length * .23),
                                (x, y, z + .12), .10, .11, 1))
        part("engine_pair/" + label + "/propulsion casing", [1],
             lambda: hull.loft([(z - .10, radius, radius, x, y),
                                (z + .18, radius * 1.13, radius * 1.13, x, y)], hull.sides, 1))
        part("engine_pair/" + label + "/propulsion luminous recess", [6],
             lambda: hull.loft([(z - .118, radius * .70, radius * .70, x, y),
                                (z - .105, radius * .70, radius * .70, x, y)], hull.sides, 6))
    if len(parts) != 21:
        raise ValueError("All21 original Armadillo Miner parts must remain")
    if len(hull.faces) > 512:
        raise ValueError("Complete Armadillo Miner candidate exceeds512; no omission/cap waiver")
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
        "id": "SH168", "originalSourceSHA256": SOURCE_SHA256,
        "r3SHA256": R3_SHA256, "nativeCandidate": model, "parts": parts,
        "coordinateRule": "Original coordinates; no rescale/recentre/unit inference",
        "unproven": [
            "complete source-profile/material/UV/void fidelity and actual native collision",
            "actual occupied environment and installed system approval",
            "installed hardware/power/people and empty/loaded mass, COM/full tensor",
            "genuine production, EMP/salvage/acquisition and current-save journeys",
        ],
    }
