"""Unexecuted SH040 native tessellation proposal; G1 is the sole execution owner.

All nine original seed parts remain. Angular sampling is a NEW proposal, never
an assertion of shape/material/void/pressure equivalence or native qualification.
The genuine pinned creator performs primitives, validation and appearance mapping.
No CLI, file writer, runtime resource edit, installed hardware or evidence writer.
"""

import hashlib
import math
import tomllib


SOURCE_SHA256 = "94125f9da5db004437ac784ba47be3267271fe2401cf506f9a3715f2b2e3ae3a"
CREATOR_SHA256 = "3f029d5a417dea1b787dc5f0327d72687822275cc372de79790c3531e7cba429"
PRIMITIVE_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"
RESOURCE_SHA256 = "6f4cec0e21142b9ed9d35393def302ca277090bedae7c4ccfdb56d3d218b2b45"
R3_SHA256 = "f0a2f7b763aa35cc65022cf5485eb5c91f742147782d34125ff6c24bf9b72e1c"

# NEW tessellation choices only. No computed count, tolerance or native PASS.
ORIGINAL_PROFILE_SIDES = 12
DRIVE_LOFT_SIDES = 8
COLLAR_MAJOR_SAMPLES = 8
COLLAR_MINOR_SAMPLES = 4


def build_candidate_native(creator, *, source_bytes, creator_bytes, primitive_bytes, resource_bytes):
    """G1 supplies the genuine pinned creator module; no generated source is installed."""
    for label, data, expected in [
        ("SH040 source", source_bytes, SOURCE_SHA256),
        ("original fleet creator", creator_bytes, CREATOR_SHA256),
        ("original Hull primitives", primitive_bytes, PRIMITIVE_SHA256),
        ("current SH040 capsule resource", resource_bytes, RESOURCE_SHA256),
    ]:
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(label + " changed; review actual source before generation")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    resource = tomllib.loads(resource_bytes.decode("utf-8"))
    proposal = source["proposal"]
    if (proposal["id"], proposal["archetype"], proposal["palette"],
            proposal["forwardAxis"], proposal["upAxis"]) != (
            "SH040", "seed", "ice-blue", "+Z", "+Y"):
        raise ValueError("Original SH040 recipe/frame changed")
    catalogue = resource["catalogue"]
    if (resource["id"], resource["name"], catalogue["family"], catalogue["objectKind"],
            catalogue["origin"], catalogue["playerFlyable"], catalogue["normalPurchaseEligible"],
            catalogue["purchasePolicy"], catalogue["encounterMode"], catalogue["mechanicsStatus"],
            catalogue["placementStatus"], catalogue["roleWeights"], catalogue["aliases"]) != (
            "SH040", "Newt Escape Pod", "newt-escape-pod", "capsule", "human", False, False,
            "never", "authored", "pending", "pending", [], []):
        raise ValueError("Current SH040 capsule identity/domain changed")
    if resource.get("nativeHull") is not None or resource.get("nativeCombat") is not None:
        raise ValueError("Capsule must not bind an ordinary Hull or combat fallback")
    game = resource["game"]
    if any(game[key] != 0 for key in ["cargo", "fuel", "jump", "spool", "missiles", "facings",
                                     "cargoExpansion", "price"]) or game["workTools"] != []:
        raise ValueError("Capsule zero-drive/source allocation changed")
    current_r3 = [field["text"] for profile in resource.get("profiles", [])
                  for field in profile.get("fields", []) if field.get("key") == "r3.sha256"]
    if current_r3 != [R3_SHA256]:
        raise ValueError("Current SH040 R3 provenance changed")
    for key in ["design", "nativeDesign"]:
        if source[key] != resource[key]:
            raise ValueError("Current SH040 changed original " + key)
    # Keep original coordinate space: no metre inference, calibration or recentering.
    hull = creator.Mesh("ice-blue", native=True)
    if hull.vertices or hull.faces or hull.face_materials:
        raise ValueError("Original Mesh constructor did not supply a fresh buffer")
    parts = []

    def part(name, material, operation):
        vertex_start, face_start = len(hull.vertices), len(hull.faces)
        operation()
        if len(hull.vertices) <= vertex_start or len(hull.faces) <= face_start:
            raise ValueError("Candidate omitted original part: " + name)
        if set(hull.face_materials[face_start:]) != {material}:
            raise ValueError("Candidate changed original part material: " + name)
        parts.append({
            "index": len(parts), "name": name,
            "vertexStart": vertex_start, "vertexCount": len(hull.vertices) - vertex_start,
            "faceStart": face_start, "faceCount": len(hull.faces) - face_start,
            "originalMaterialIndex": material,
        })

    def collar(centre, rx, ry, tube):
        # Same complete z-axis torus equations, winding and Mesh.raw triangulation
        # as pinned Mesh.torus; newly chosen angular sample counts are the change.
        major, minor = COLLAR_MAJOR_SAMPLES, COLLAR_MINOR_SAMPLES
        points, quads = [], []
        for i in range(major):
            angle = math.tau * i / major
            for j in range(minor):
                theta = math.tau * j / minor
                points.append([
                    centre[0] + (rx + tube * math.cos(theta)) * math.cos(angle),
                    centre[1] + (ry + tube * math.cos(theta)) * math.sin(angle),
                    centre[2] + tube * math.sin(theta),
                ])
        for i in range(major):
            row = (i + 1) % major
            for j in range(minor):
                k = (j + 1) % minor
                quads.append([i * minor + j, row * minor + j,
                              row * minor + k, i * minor + k])
        # Preserve the original quad fan order before refining its outer rib.
        triangles = [face for q in quads for face in
                     ([q[0], q[1], q[2]], [q[0], q[2], q[3]])]
        # Restore source rows 4, 8, 16, 20 on the outer rib, where the
        # transverse witness rows approach the top and bottom collar arcs.
        for row, original_row in ((1, 4), (2, 8), (5, 16), (6, 20)):
            angle = math.tau * original_row / 24
            point = len(points)
            points.append([centre[0] + (rx + tube) * math.cos(angle),
                           centre[1] + (ry + tube) * math.sin(angle),
                           centre[2]])
            edge = {row * minor, (row + 1) * minor}
            refined = []
            splits = 0
            for face in triangles:
                for i in range(3):
                    a, b, c = face[i], face[(i + 1) % 3], face[(i + 2) % 3]
                    if {a, b} == edge:
                        refined.extend(([a, point, c], [point, b, c]))
                        splits += 1
                        break
                else:
                    refined.append(face)
            if splits != 2:
                raise ValueError("Original collar rib must have two adjacent triangles")
            triangles = refined
        # Route the already restored rib point into each off-centre owner
        # patch identified by 63154. Its opposite axial patch stays exact.
        for offset, (row, minor_index) in enumerate(((1, 3), (2, 0), (5, 3), (6, 0))):
            a, b, c, d = quads[row * minor + minor_index]
            point = major * minor + offset
            if minor_index == 3:
                replacements = [({a, b, c}, [a, b, point]),
                                ({a, c, point}, [b, c, point])]
            else:
                replacements = [({a, point, c}, [a, point, d]),
                                ({a, c, d}, [point, c, d])]
            for old_face, new_face in replacements:
                matches = [i for i, face in enumerate(triangles) if set(face) == old_face]
                if len(matches) != 1:
                    raise ValueError("Missing or ambiguous frozen collar diagonal")
                triangles[matches[0]] = new_face
        hull.raw(points, triangles, 2)

    # Exact SH040 seed row and seed-body/cockpit/drive parameters. Original pod
    # still retains all five longitudinal stations and closed end caps.
    length, beam = 1.9, 1.15
    hull.sides = ORIGINAL_PROFILE_SIDES
    part("body primary pressure envelope", 0,
         lambda: hull.pod((0, 0, 0), length, beam * .47, .42, 0, False))
    part("cockpit glazing envelope", 5,
         lambda: hull.pod((0, .40, .15), .60, .33, .33 * .55, 5, False))
    part("cockpit connected structural crossmember", 2,
         lambda: hull.strut((-.33 * .85, .40, .15 - .10),
                            (.33 * .85, .40, .15 - .10), .020, .025, 2))
    for z in [-length * .20, length * .24]:
        part("seed circumferential collar", 2,
             lambda z=z: collar((0, 0, z), beam * .39, .37, .04))
    hull.sides = DRIVE_LOFT_SIDES
    for index, side in enumerate([-1, 1]):
        x, y, z, radius = side * beam * .30, -.18, -length * .30, .09
        part("seed explicit drive " + str(index) + "/propulsion casing", 1,
             lambda x=x: hull.loft([
                 (z - .10, radius, radius, x, y),
                 (z + .18, radius * 1.13, radius * 1.13, x, y),
             ], hull.sides, 1))
        part("seed explicit drive " + str(index) + "/propulsion luminous recess", 6,
             lambda x=x: hull.loft([
                 (z - .118, radius * .70, radius * .70, x, y),
                 (z - .105, radius * .70, radius * .70, x, y),
             ], hull.sides, 6))

    if len(parts) != 9:
        raise ValueError("All nine original SH040 parts must remain")
    if any(len(face) != 3 for face in hull.faces):
        raise ValueError("Current native consumer requires triangular faces")
    if sum(len(face) - 2 for face in hull.faces) > 512:
        raise ValueError("Complete candidate exceeds512 fan triangles; no omission or cap waiver")
    hull.checked()
    model = creator.mesh_dict(hull, adaptation=False)
    # Same original mapper regenerates every per-face UV/texture assignment.
    # Appearance must stay exact; never drop textures/emissive/glazing materials.
    original = source["nativeDesign"]
    if model.keys() != original.keys():
        raise ValueError("Candidate serializer changed original fields")
    for key in original.keys() - {"vertices", "faces", "faceMaterials", "faceTextures"}:
        if model[key] != original[key]:
            raise ValueError("Candidate appearance differs from original: " + key)
    if set(model["faceMaterials"]) != set(original["faceMaterials"]):
        raise ValueError("Candidate lost original used material")
    if len(model["faceTextures"]) != len(model["faces"]):
        raise ValueError("Candidate has missing per-face texture mapping")
    return {
        "status": "GENERATED_CANDIDATE_ONLY_NOT_INSTALLED_OR_NATIVE_QUALIFIED",
        "id": "SH040", "originalSourceSHA256": SOURCE_SHA256,
        "currentResourceSHA256": RESOURCE_SHA256, "r3SHA256": R3_SHA256,
        "objectKind": "capsule", "declaredNativeCrew": 1, "declaredConversionCrew": 1,
        "occupants": "UNISSUED; a crew declaration is not a real person or occupied capsule",
        "coordinateRule": "Original source coordinates; no rescale/recentre/unit inference",
        "nativeCandidate": model, "parts": parts,
        "unproven": [
            "shape/profile/material/void fidelity against the complete original detailed source",
            "actual source calibration, closed collision admission and native qualification",
            "actual installed occupied cabin/door/life-support/power/people and escape path",
            "actual derived empty/loaded mass/COM/full tensor and current runtime/save rollback",
        ],
    }
