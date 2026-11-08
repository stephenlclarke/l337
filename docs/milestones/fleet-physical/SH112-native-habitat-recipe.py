"""SH112 candidate habitat geometry recipe. Source authoring only; G4 must not execute.

G1 may invoke this reviewed recipe with the genuine pinned original Hull.box helper
and a NEW empty Hull. It emits proposal geometry, never an installed habitat, person,
power source, mass frame, native qualification or actor. Do not call design_dict:
the returned materials are the exact SH112 source palette, not its helper's palette.
"""

import hashlib
import tomllib


SOURCE_ID = "SH112"
SOURCE_BYTES = 880289
SOURCE_SHA256 = "32f71d1edac325cffe3299c12c89d87ade907c42f81986820622127ca6f716e1"
PRIMITIVE_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"

# NEW geometric design choices. None asserts native occupied size, pressure or fit.
CELL_WIDTH = 3.0
CELL_LENGTH = 4.0
CLEAR_HEIGHT = 2.4
WALL_THICKNESS = 0.02
CORRIDOR_WIDTH = 1.2
DOOR_WIDTH = 1.0
DOOR_HEIGHT = 2.1


def append_candidate_habitat(hull, *, source_bytes, primitive_bytes):
    """Build one unqualified proposal in a fresh helper buffer, without file writes."""
    if len(source_bytes) != SOURCE_BYTES or hashlib.sha256(source_bytes).hexdigest() != SOURCE_SHA256:
        raise ValueError("SH112 original source changed; review the actual new source")
    if hashlib.sha256(primitive_bytes).hexdigest() != PRIMITIVE_SHA256:
        raise ValueError("Original Hull.box primitive changed; review its actual implementation")
    if hull.vertices or hull.faces or hull.face_materials:
        raise ValueError("Use a fresh candidate Hull; never append to the original or a live body")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    proposal = source["proposal"]
    if (proposal["id"], proposal["coordinateUnits"], proposal["forwardAxis"], proposal["upAxis"]) != (
        SOURCE_ID, "metres", "+Z", "+Y"
    ):
        raise ValueError("SH112 source frame is not the pinned native metre frame")
    materials = source["design"]["materials"]
    if not materials or materials[0]["name"] != "jade-skin":
        raise ValueError("SH112 source palette changed; no colour-to-material inference")
    native = source["nativeDesign"]
    if any(len(face) != 3 for face in native["faces"]):
        raise ValueError("Retained native source is not triangulated")

    parts = []

    def box(name, centre, full_extent, purpose):
        # The pinned helper's extent argument is FULL dimension, not half-extent.
        if any(length <= 0 for length in full_extent):
            raise ValueError("Candidate panel has no positive physical extent")
        first_vertex = len(hull.vertices)
        first_face = len(hull.faces)
        hull.box(centre, full_extent, 0)
        if len(hull.vertices) - first_vertex != 8 or len(hull.faces) - first_face != 12:
            raise ValueError("Actual box helper differs from its pinned primitive contract")
        parts.append({
            "name": name, "purpose": purpose,
            "vertexStart": first_vertex, "vertexCount": len(hull.vertices) - first_vertex,
            "faceStart": first_face, "faceCount": len(hull.faces) - first_face,
            "appearanceMaterialIndex": 0,
            "physicalMaterial": "UNISSUED; source appearance is not density/strength/pressure evidence",
        })

    width = CELL_WIDTH
    length = CELL_LENGTH
    height = CLEAR_HEIGHT
    thickness = WALL_THICKNESS
    corridor = CORRIDOR_WIDTH
    door_width = DOOR_WIDTH
    door_height = DOOR_HEIGHT
    if not (0 < door_width < min(length, corridor) and 0 < door_height < height):
        raise ValueError("Candidate door does not fit its own proposed panel aperture")

    for side, name in [(-1, "negative-X-cell"), (1, "positive-X-cell")]:
        centre_x = side * (corridor / 2 + thickness + width / 2)
        outer_x = side * (corridor / 2 + thickness + width + thickness / 2)
        inner_x = side * (corridor / 2 + thickness / 2)
        box(name + "/outer-wall", (outer_x, height / 2, 0),
            (thickness, height, length + 2 * thickness), "new candidate enclosure wall")
        for end in [-1, 1]:
            box(name + "/end-wall-" + str(end),
                (centre_x, height / 2, end * (length / 2 + thickness / 2)),
                (width, height, thickness), "new candidate enclosure wall")
        box(name + "/floor", (centre_x, -thickness / 2, 0),
            (width, thickness, length), "new candidate floor; no occupied rating")
        box(name + "/roof", (centre_x, height + thickness / 2, 0),
            (width, thickness, length), "new candidate enclosure roof")
        side_span = (length - door_width) / 2
        for end in [-1, 1]:
            box(name + "/door-pier-" + str(end),
                (inner_x, height / 2, end * (door_width / 2 + side_span / 2)),
                (thickness, height, side_span), "new closed panel beside an authored aperture")
        box(name + "/door-lintel", (inner_x, (door_height + height) / 2, 0),
            (thickness, height - door_height, door_width), "new closed panel above aperture")
        box(name + "/closed-leaf", (inner_x, door_height / 2, 0),
            (thickness, door_height, door_width),
            "closed geometric leaf ONLY; no actuator/seal/power/operable-door assertion")

    box("shared-corridor/floor", (0, -thickness / 2, 0),
        (corridor, thickness, length), "new candidate shared floor")
    box("shared-corridor/roof", (0, height + thickness / 2, 0),
        (corridor, thickness, length), "new candidate shared roof")
    end_span = (corridor - door_width) / 2
    for end in [-1, 1]:
        z = end * (length / 2 + thickness / 2)
        for side in [-1, 1]:
            box("shared-corridor/end-" + str(end) + "/pier-" + str(side),
                (side * (door_width / 2 + end_span / 2), height / 2, z),
                (end_span, height, thickness), "new frame beside an UNISSUED assembly interface")
        box("shared-corridor/end-" + str(end) + "/lintel", (0, (door_height + height) / 2, z),
            (door_width, height - door_height, thickness),
            "new frame above an UNISSUED assembly interface")

    # Count is a necessary generation stop, never closure/material/void/native proof.
    # Actual later control/service/door hardware must be included and checked again.
    if any(len(face) != 3 for face in hull.faces):
        raise ValueError("Candidate helper output is not triangulated")
    if len(hull.faces) + len(native["faces"]) > 512:
        raise ValueError("Candidate plus retained source exceeds512; no cap or material waiver")
    return {
        "status": "GENERATED_PROPOSAL_ONLY_NOT_INSTALLED_OR_QUALIFIED",
        "sourceID": SOURCE_ID, "sourceSHA256": SOURCE_SHA256,
        "localFrame": "+Z forward/+Y up; corridor-floor centre is local origin",
        "hostPlacement": "UNCOMPUTED primary-component area-centroid candidate; no source recentering",
        "design": {
            "vertices": hull.vertices, "faces": hull.faces,
            "materials": materials, "faceMaterials": hull.face_materials,
            "license": "MIT", "source": "New SH112 internal habitat geometry proposal",
        },
        "parts": parts,
        "interfaces": [
            {"name": "forward-control-and-egress", "end": "+Z", "state": "OPEN_UNISSUED_ACTUAL_JOIN"},
            {"name": "aft-service", "end": "-Z", "state": "OPEN_UNISSUED_ACTUAL_JOIN"},
        ],
        "unissued": [
            "actual pressure/solid material recipe and structural proof",
            "native occupied/environment requirements and actual people",
            "actual door actuator/seals/control and connected power/life support",
            "real exterior hatch/route without deleting original mantle material",
            "derived mass/COM/full tensor and actual combined native/material/void qualification",
        ],
    }
