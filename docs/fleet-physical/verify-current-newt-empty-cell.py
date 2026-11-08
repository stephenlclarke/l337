"""Independent exact display mask and physical subtraction controls on MBA."""

import argparse
from hashlib import sha256
import importlib.util
import json
from pathlib import Path

import numpy as np


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def origin_inertia(row):
    c = np.array(row["centreMetres"])
    mass = row["massKg"]
    return np.array(row["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3) + mass * (
        (c @ c) * np.eye(3) - np.outer(c, c)
    )


def verify(root, producer, resource):
    spec = importlib.util.spec_from_file_location("empty_producer", producer)
    p = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(p)
    raw = resource.read_bytes()
    d = json.loads(raw)
    require(p.derive(root) == d, "Empty source replay")
    spec = importlib.util.spec_from_file_location(
        "source_auth", root / "verify-sh040-current-admission-source.py"
    )
    a = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(a)
    source = a.authenticate(root)
    design = source[a.RESOURCE]["design"]
    by_material = [i for i, value in enumerate(design["faceMaterials"]) if value in [4, 5, 6, 7]]
    require(by_material == list(range(179, 391)), "Independent material ownership mask")
    retained = [i for i in range(415) if i not in by_material]
    require(retained == d["retainedFaceIndices"], "Retained structural face set")
    empty = d["emptyDisplayDesignMetres"]
    inverse = d["retainedVertexIndices"]
    require(len(inverse) == 120 and len(retained) == 203, "Exact empty vertex/face cardinality")
    for index, old in enumerate(retained):
        face = [inverse[v] for v in empty["faces"][index]]
        require(face == design["faces"][old], "Retained face geometry/winding")
        require(empty["faceMaterials"][index] == design["faceMaterials"][old], "Retained material binding")
        require(not any(104 <= v < 240 for v in face), "A transferred figure triangle remains")
    require(empty["materials"] == design["materials"][:4], "Exact retained palette")
    require(
        [i for i, mat in enumerate(empty["faceMaterials"]) if mat == 3] == [38]
        and empty["materials"][3]["opticalOpacity"] == 0.25,
        "One retained transparent lid",
    )
    # Off-by-one removal would leave a figure face and remove a lid-rail face.
    wrong_retained = [i for i in range(415) if not 178 <= i < 390]
    require(
        178 not in wrong_retained
        and 390 in wrong_retained
        and any(104 <= v < 240 for v in design["faces"][390]),
        "Off-by-one mask negative",
    )
    kit = json.loads((root / "SH029-current-newt-escape-kit-v1-loaded.json").read_text())
    occupied = kit["physicalExpectations"]["occupiedPod"]
    person = d["actualRemovedPerson"]
    cell = d["emptyConfiguredCellLocal"]
    mass = occupied["massKg"] - person["massKg"]
    centre = (
        occupied["massKg"] * np.array(occupied["centreMetres"])
        - person["massKg"] * np.array(person["centreMetres"])
    ) / mass
    origin = origin_inertia(occupied) - origin_inertia(person)
    inertia = origin - mass * ((centre @ centre) * np.eye(3) - np.outer(centre, centre))
    require(
        mass == 252.5
        and np.max(abs(centre - cell["centreMetres"])) < 1e-12
        and np.max(abs(inertia.reshape(-1) - cell["inertiaAboutCentreOfMassKgM2"])) < 1e-8,
        "Independent full-tensor person subtraction",
    )
    require(
        np.max(abs(inertia.reshape(-1) - occupied["inertiaAboutCentreOfMassKgM2"])) > 1,
        "Mass-only subtraction negative must expose retained body inertia",
    )
    # A deliberately changed exact input is refused before any geometry.
    name = "Sources/L337Core/OriginalCryostasisCapsule.swift"
    negative = root / "negative-source" / name
    negative.parent.mkdir(parents=True, exist_ok=True)
    negative.write_bytes((root / name).read_bytes() + b"\n")
    try:
        a.authenticate(root / "negative-source")
    except ValueError as error:
        require(str(error).startswith("Changed exact current cryopod input"), "Wrong pin-negative refusal")
    else:
        raise ValueError("Changed current source accepted")
    return dict(
        status="PASS_SOURCE_ONLY_ROSTER_MAPPING_RENDERER_NATIVE_PENDING",
        resourceBytes=len(raw),
        resourceSHA256=sha256(raw).hexdigest(),
        authenticatedCurrentInputs=9,
        exactRetainedFaces=203,
        removedFigureFaces=212,
        removedFigureVertices=136,
        removedFigureMaterials=4,
        fanTriangles=204,
        transparentLidFace=38,
        independentPersonMassRemovedKg=100,
        emptyConfiguredCellKg=252.5,
        wrongMaskRejected=True,
        massOnlyTensorRejected=True,
        changedExactInputRejected=True,
        deceasedWithHullMapping="NOT_EXECUTED_HERE; actual body remains occupied until proved transfer/removal",
        native=False,
        renderer=False,
        compiler=False,
        actorAdmission=False,
    )


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("root", "producer", "resource", "output"):
        p.add_argument("--" + name, type=Path, required=True)
    args = p.parse_args()
    d = verify(args.root, args.producer, args.resource)
    args.output.write_text(json.dumps(d, indent=2, sort_keys=True) + "\n")
    print(json.dumps(d, indent=2))


if __name__ == "__main__":
    main()
