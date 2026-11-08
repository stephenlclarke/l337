"""Complete FOUR actual Osprey native source candidates; G1 alone may generate.

Closed explicit IDs152/153/154/155 share the genuine creator's mark formula, never an
identity/source/crew fallback. Every variant retains all30 original native parts.
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
BOOM_SEGMENTS = 2
BOOM_MINOR_SAMPLES = 4
# NEW coarse triangular angular proposal; full continuous fidelity UNKNOWN.

PINS = {
    "SH152": {
        "name": "Osprey Scout",
        "sourceSHA256": "72139a9ccf2ee7df38ffafce1f17bb823f639e7fdefbc4e027e815edb263e02c",
        "resourceSHA256": "4c215d8d2bff13550b8c0bb53e9980853d0573b5c4d478f38885c07260604854",
        "r3SHA256": "0ac6d029f0fd74af9ea5567b2f047ffa011a9902c97a2ea2639d26b0c6dc4026"
    },
    "SH153": {
        "name": "Osprey Strike",
        "sourceSHA256": "9ccb8ce4115e6f93a7fa06618e6ca2c001761b6d3135fbca477e7d1acb6be085",
        "resourceSHA256": "953256bd24d90a05e47b54ba0515b0b3e4fc1927f8a9b8e0e3712f9a07386ca4",
        "r3SHA256": "427aa1f5f2f0a41dc45834002c9efcb2e918a1942aa156f4f1000ca470b3f1b6"
    },
    "SH154": {
        "name": "Osprey Patrol",
        "sourceSHA256": "e629276d66b367e05424ec84ab029be99558b41b76f6670e775c031030f6d790",
        "resourceSHA256": "fb753ab358bf556b117eec537f022683abd7c5ff7cf5bdfac9472513e81c34e9",
        "r3SHA256": "9b7c879723fd2b465f06efe8d06c5a6516ba7758485200f583930461ec773472"
    },
    "SH155": {
        "name": "Osprey Support",
        "sourceSHA256": "63ddbc6a3f6e21dbd1641b8fd703297bfac0403e724b4926be46f2e57346fddb",
        "resourceSHA256": "75a220eb88647dbbc3a6e9eaf899d54163de49e806a7c983fdead99e070b5a80",
        "r3SHA256": "c01b5c1545db7cd07860f71f43158bfde32b4eab4fd147aa96f73d63bedaf992"
    }
}


def build_candidate_native(identity, creator, *, source_bytes, creator_bytes,
                           primitive_bytes, resource_bytes, family_bytes):
    """Require one actual per-ID source/resource; never substitute a family member."""
    if identity not in PINS:
        raise ValueError("Only actual Osprey IDs152/153/154/155 have candidate inputs")
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
            identity, "arched-boom", "cobalt-cream", "+Z", "+Y", identity, expected["name"]):
        raise ValueError("Actual Osprey identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Each Osprey retains its own actual ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged member changed its own original " + key)
    ships = json.loads(family_bytes)["ships"]
    members = sorted(s["id"] for s in ships if s["family"] == "osprey")
    if members != ["SH152", "SH153", "SH154", "SH155"] or any(
            s["role"] != "military" or s["objectKind"] != "ship"
            for s in ships if s["id"] in members):
        raise ValueError("Genuine Osprey family/creator roles changed")
    # Original RECIPES[SH152] and all FOUR actual family marks.
    # Current155 is Support; archive Carrier is provenance, never a runtime alias.
    mark = members.index(identity)
    length = 3.9 * (1 + .035 * mark)
    beam = 2.40 * (1 + .025 * mark)
    hull = creator.Mesh("cobalt-cream", native=True)
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
    def arched_boom(side):
        # Genuine original torus(0..pi) followed by its actual rotation/offset.
        # NEW coarse angular sampling only; keep BOTH original endcaps and gap.
        steps, minor = BOOM_SEGMENTS, BOOM_MINOR_SAMPLES
        points, faces = [], []
        for i in range(steps + 1):
            angle = math.pi * i / steps
            for j in range(minor):
                theta = math.tau * j / minor
                old_x = (length * .44 + .14 * math.cos(theta)) * math.cos(angle)
                old_y = (.65 + .14 * math.cos(theta)) * math.sin(angle)
                old_z = .14 * math.sin(theta)
                points.append([old_z + side * beam * .36, old_y + .10, -old_x])
        for i in range(steps):
            for j in range(minor):
                k = (j + 1) % minor
                faces.append([i * minor + j, (i + 1) * minor + j,
                              (i + 1) * minor + k, i * minor + k])
        faces += [list(range(minor)),
                  list(reversed(range(steps * minor, (steps + 1) * minor)))]
        hull.raw(points, faces, 1)
    for side in [-1, 1]:
        part("arched connected boom", [1], lambda: arched_boom(side))
    for member, x in enumerate([-beam * .36, beam * .36]):
        width = .22
        complete_pod("pods explicit member " + str(member), (x, -.10, -length * .02),
                     length * .90, width, width * .72, 0)
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
    if len(parts) != 30:
        raise ValueError("All30 original per-member components must remain")
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
