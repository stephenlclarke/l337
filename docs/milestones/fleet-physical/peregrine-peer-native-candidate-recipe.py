"""Complete THREE actual Peregrine peer ship native source candidates; G1 alone may generate.

Closed explicit IDs022/023/024 share the genuine creator's mark formula, never an
identity/source/crew fallback. Every variant retains all27 original native parts.
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
LOFT_SIDES = 4
# NEW coarse triangular drive proposal, not continuous curved-source fidelity.
DRIVE_SIDES = 3

PINS = {
    "SH022": {
        "name": "Peregrine Mk I",
        "sourceSHA256": "60cd55b2c752e53200a950ad9481c6f49bd6e9eed228071abb2d8794ed0a6979",
        "resourceSHA256": "a4e2830603cded5e8c2435819dcd554b1475096f0b519d2bdcdfd5da3473034d",
        "r3SHA256": "f8502a924dca78b9274ae9ad282cb3d9636ce094087a2ab4365aae7f733a736d"
    },
    "SH023": {
        "name": "Peregrine Mk III",
        "sourceSHA256": "b6fa2593479b011b08fe7818874da9263cc671d01270619081183f578c7ebbb3",
        "resourceSHA256": "3724c6aba40f20ee90c39380279ecc0d657cd5442867a1240f1624f4cee57457",
        "r3SHA256": "ecdb62da81e8b87f802dd92f60374dc4375375575855971b0bb25fb3ba0a679f"
    },
    "SH024": {
        "name": "Peregrine Mk IV",
        "sourceSHA256": "3148e8e17afe9a7be6e903cb563afd5e9547a4bb5c4f6267def86fbc78f37dbf",
        "resourceSHA256": "1f51038d878610b3e43961380ce0cdabea70825a7bda3f799632165e6bf7b643",
        "r3SHA256": "2117edc243ad7386d00555caa6c05bf155f0d91f32af288d04c5e67ee914844c"
    }
}


def build_candidate_native(identity, creator, *, source_bytes, creator_bytes,
                           primitive_bytes, resource_bytes, family_bytes):
    """Require one actual per-ID source/resource; never substitute a family member."""
    if identity not in PINS:
        raise ValueError("Only actual Peregrine peer IDs022/023/024 have candidate inputs")
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
            identity, "split-prow", "cobalt-cream", "+Z", "+Y", identity, expected["name"]):
        raise ValueError("Actual Peregrine peer identity/recipe/frame changed")
    if resource["catalogue"]["objectKind"] != "ship" or "game" not in resource:
        raise ValueError("Each Peregrine peer retains its own actual ship domain")
    for key in ("design", "nativeDesign"):
        if source[key] != resource[key]:
            raise ValueError("Packaged member changed its own original " + key)
    ships = json.loads(family_bytes)["ships"]
    members = sorted(s["id"] for s in ships if s["family"] == "peregrine")
    if members != ["SH022", "SH023", "SH024", "SH025"] or any(
            s["role"] != "trader" or s["objectKind"] != "ship"
            for s in ships if s["id"] in members):
        raise ValueError("Genuine Peregrine family/creator roles changed")
    # Original RECIPES[SH022] and mark formula over all FOUR actual members.
    # SH025 has its separate frozen method; this generator accepts022/023/024 only.
    mark = members.index(identity)
    length = 3.2 * (1 + .035 * mark)
    beam = 2.15 * (1 + .025 * mark)
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
    # Exact original fork branch: BOTH forward pods with all FOUR wells each.
    z = 0
    for member, x in enumerate([-beam * .34, beam * .34]):
        width = beam * .20
        complete_pod("pods explicit member " + str(member), (x, -.10, z),
                     length * .91, width, width * .72, 0)
    for side in [-1, 1]:
        part("fork longitudinal envelope", [1],
             lambda: hull.box((side * beam * .34, -.22, z), (.20, .28, length * .65), 1))
    part("fork aft cross bridge", [2],
         lambda: hull.box((0, .18, -length * .24), (beam * .72, .22, .38), 2))
    complete_pod("body primary pressure envelope", (0, .28, -length * .11),
                 length * .55, .28, .23, 0)
    part("split prow lower pressure envelope", [1],
         lambda: hull.box((0, -.36, -length * .08), (beam * .62, .22, length * .46), 1))
    part("cockpit glazing envelope", [5],
         lambda: hull.pod((0, .55, length * .06), .51, .23, .23 * .55, 5, False))
    part("cockpit connected structural crossmember", [2],
         lambda: hull.strut((-.23 * .85, .55, length * .06 - .10),
                            (.23 * .85, .55, length * .06 - .10), .020, .025, 2))
    hull.sides = DRIVE_SIDES
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
    if len(parts) != 27:
        raise ValueError("All27 original per-member components must remain")
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
