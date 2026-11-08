"""Authenticate and derive an empty display/person subtraction, on MBA only."""

import argparse
from copy import deepcopy
from hashlib import sha256
import importlib.util
import json
from pathlib import Path

import numpy as np


def derive(root):
    spec = importlib.util.spec_from_file_location(
        "current_source_audit", root / "verify-sh040-current-admission-source.py"
    )
    a = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(a)
    current = a.authenticate(root)  # Reuse unchanged dry/native proof; no rerun.
    spec = importlib.util.spec_from_file_location(
        "source_mass_math", root / "author-reference/build-sh029-current-newt-kit.py"
    )
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    raw = (root / "SH029-current-newt-escape-kit-v1-loaded.json").read_bytes()
    if sha256(raw).hexdigest() != "7ba94c62149a2f0b7b882367c946a41516f49c6c58861d5e85eec255ba9d4b4a":
        raise ValueError("Wrong current configured source")
    kit = json.loads(raw)
    design = current[a.RESOURCE]["design"]
    vertices, faces, materials = design["vertices"], design["faces"], design["faceMaterials"]
    figure_vertices = set(range(104, 240))
    figure_faces = []
    for index, face in enumerate(faces):
        overlap = figure_vertices.intersection(face)
        if overlap:
            if not set(face) <= figure_vertices:
                raise ValueError("Interior figure shares a retained structural face")
            figure_faces.append(index)
    if (
        figure_faces != list(range(179, 391))
        or [i for i, x in enumerate(materials) if x >= 4] != figure_faces
    ):
        raise ValueError("Actual frozen figure source ranges/material ownership differ")
    keep_vertices = [i for i in range(256) if i not in figure_vertices]
    remap = {old: new for new, old in enumerate(keep_vertices)}
    keep_faces = [i for i in range(415) if i not in figure_faces]
    empty = deepcopy(design)
    empty["vertices"] = (np.array(vertices)[keep_vertices] * (60 / 19)).tolist()
    empty["faces"] = [[remap[i] for i in faces[index]] for index in keep_faces]
    empty["faceMaterials"] = [materials[i] for i in keep_faces]
    empty["materials"] = design["materials"][:4]
    if (
        len(empty["vertices"]) != 120
        or len(empty["faces"]) != 203
        or sum(len(f) - 2 for f in empty["faces"]) != 204
        or empty["faces"][:179] != faces[:179]
        or empty["faces"][38] != [14, 15, 27, 26]
        or empty["faceMaterials"][38] != 3
    ):
        raise ValueError("Empty display changed retained geometry/lid")
    for index, old in enumerate(keep_faces):
        if [keep_vertices[i] for i in empty["faces"][index]] != faces[old]:
            raise ValueError("Retained face changed after vertex remap")
    if np.array(empty["vertices"])[:48].tolist() != (np.array(vertices[:48]) * (60 / 19)).tolist():
        raise ValueError("Pressure/collision prefix changed")
    person = kit["personProfile"]
    removed = [p for p in kit["releasedPartsLocal"] if p["id"] == person["id"]]
    if (
        len(removed) != 1
        or removed[0]["massKg"] != 100
        or removed[0]["dimensionsMetres"] != [0.56, 0.38, 1.72]
    ):
        raise ValueError("No exact actual adopted person allocation to remove")
    empty_mass = m.combine(
        "configured-empty-Newt-cell", [p for p in kit["releasedPartsLocal"] if p["id"] != person["id"]]
    )
    restored = m.combine("restored-occupied-cell", [empty_mass, removed[0]])
    occupied = kit["physicalExpectations"]["occupiedPod"]
    for key in ("massKg", "centreMetres", "inertiaAboutCentreOfMassKgM2"):
        if not np.allclose(restored[key], occupied[key], rtol=0, atol=1e-8):
            raise ValueError("Person removal/readdition loses full moments")
    if empty_mass["massKg"] != 252.5:
        raise ValueError("Empty configured cell still includes a person or lost hardware")
    pod_at = m.translate(empty_mass, kit["podCentreInCarrierMetres"])
    lowered = m.combine("retained-at-unlock", kit["retainedPartsLoweredCarrier"])
    reference_stowed = m.combine(
        "empty-person-cell-stowed-carrier", [kit["physicalExpectations"]["carrierBefore"], pod_at]
    )
    reference_unlock = m.combine(
        "empty-person-cell-lowered-carrier", [kit["physicalExpectations"]["bareParent"], lowered, pod_at]
    )
    examples = {}
    for name, case in kit["ordinaryLoadExamples"].items():
        examples[name] = dict(
            stowed=m.combine("example-empty-cell-stowed", [reference_stowed, *case["loadComponents"]]),
            lowered=m.combine("example-empty-cell-lowered", [reference_unlock, *case["loadComponents"]]),
        )
        if abs(case["installedOccupied"]["massKg"] - examples[name]["stowed"]["massKg"] - 100) > 1e-8:
            raise ValueError("Actual person was not removed from loaded carrier")
    return dict(
        schema=1,
        status="SOURCE_ONLY_EMPTY_DISPLAY_AND_ACTUAL_PERSON_SUBTRACTION_NOT_ACTOR_AUTHORITY",
        currentResourceBytes=27799,
        currentResourceSHA256=a.PINS[a.RESOURCE]["sha256"],
        currentPhysicalSHA256=a.PINS[a.PHYSICAL]["sha256"],
        configuredSourceSHA256=sha256(raw).hexdigest(),
        removedFigureVertexRange=dict(start=104, count=136),
        removedFigureFaceRange=dict(start=179, count=212),
        retainedVertexIndices=keep_vertices,
        retainedFaceIndices=keep_faces,
        removedFigureMaterialIndices=[4, 5, 6, 7],
        emptyDisplayDesignMetres=empty,
        opticalEnclosure=dict(paneFace=38, firstInteriorFace=91),
        collision="Unchanged current48vertices/92triangles. This is a display-only derivative, not a new catalogue alias/native hull or ordinary admission path.",
        actualRemovedPerson=removed[0],
        emptyConfiguredCellLocal=empty_mass,
        emptyInstalledStowedReference=reference_stowed,
        emptyInstalledLoweredReference=reference_unlock,
        loadedEmptyExamples=examples,
        mapping="Only a proved transfer of the selected original person removes physical mass/figure. Unknown roster is not empty. deceasedWithHull retains body mass and occupied display while the body remains. Scripted clock decoration is unchanged.",
        native=False,
        renderer=False,
        compiler=False,
        actorAdmission=False,
    )


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    d = derive(args.root)
    args.output.write_text(json.dumps(d, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(
        json.dumps(
            dict(
                bytes=args.output.stat().st_size,
                sha256=sha256(args.output.read_bytes()).hexdigest(),
                displayVertices=120,
                displayFaces=203,
                displayFanTriangles=204,
                emptyMass=d["emptyConfiguredCellLocal"],
            ),
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
