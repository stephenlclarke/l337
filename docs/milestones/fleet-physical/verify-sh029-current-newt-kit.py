"""Independent numeric/geometry controls for the one newly authored Newt kit.

Run on MBA. No Swift, native, renderer, stock issue or occupied actor admission.
"""

import argparse
from copy import deepcopy
from hashlib import sha256
import importlib.util
import itertools
import json
from pathlib import Path

import numpy as np


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def moments(row):
    mass = row["massKg"]
    centre = np.asarray(row["centreMetres"])
    inertia = np.asarray(row["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3)
    # Work in Cartesian second moments, independently of producer's I merge.
    central_second = np.trace(inertia) / 2 * np.eye(3) - inertia
    return mass, mass * centre, central_second + mass * np.outer(centre, centre)


def expect_sum(expected, rows):
    m, f, s = moments(expected)
    items = [moments(p) for p in rows]
    require(abs(m - sum(r[0] for r in items)) < 1e-8, "Mass conservation")
    require(np.max(np.abs(f - sum(r[1] for r in items))) < 1e-7, "First moment conservation")
    require(np.max(np.abs(s - sum(r[2] for r in items))) < 2e-6, "Full second moment conservation")


def volume_moments(vertices, density):
    # Separate exact tetrahedral integrator. Each hexahedron is partitioned
    # along the body diagonal into six non-overlapping tetrahedra.
    indices = [(0, 1, 2, 6), (0, 2, 3, 6), (0, 3, 7, 6), (0, 7, 4, 6), (0, 4, 5, 6), (0, 5, 1, 6)]
    m, f, s = 0.0, np.zeros(3), np.zeros((3, 3))
    for ids in indices:
        t = np.asarray(vertices)[list(ids)]
        dm = abs(np.linalg.det((t[1:] - t[0]).T)) / 6 * density
        total = t.sum(axis=0)
        m += dm
        f += dm * total / 4
        s += dm * (np.outer(total, total) + t.T @ t) / 20
    return m, f, s


def verify(root, producer_path, verifier_path, resource):
    spec = importlib.util.spec_from_file_location("kit_producer", producer_path)
    producer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(producer)
    audit, data, pins = producer.load_inputs(root, verifier_path)
    raw = resource.read_bytes()
    kit = json.loads(raw)
    replay = producer.build(root, verifier_path)
    require(kit == replay, "Producer replay differs")
    phases = kit["physicalExpectations"]
    phase_cases = [
        ("occupiedPod", kit["releasedPartsLocal"]),
        ("retainedStowed", kit["retainedPartsCarrier"]),
        ("retainedExtended", kit["retainedPartsAfterStrokeCarrier"]),
        ("carrierBefore", [phases["bareParent"], phases["retainedStowed"]]),
        ("carrierAfter", [phases["bareParent"], phases["retainedExtended"]]),
        (
            "installedOccupied",
            [phases["carrierBefore"], producer.translate(phases["occupiedPod"], producer.POSE)],
        ),
    ]
    for name, parts in phase_cases:
        expect_sum(phases[name], parts)
    tetra_cases = 0
    for row in kit["retainedPartsCarrier"] + kit["releasedPartsLocal"]:
        if "verticesMetres" not in row:
            continue
        actual = volume_moments(row["verticesMetres"], row["densityKgM3"])
        if "subtractedVerticesMetres" in row:
            base = volume_moments(row["subtractedVerticesMetres"], row["densityKgM3"])
            actual = tuple(a - b for a, b in zip(actual, base, strict=True))
        expected = moments(row)
        for a, b in zip(actual, expected, strict=True):
            require(np.max(np.abs(np.asarray(a) - b)) < 5e-9, "Independent wedge tetrahedral moments")
        tetra_cases += 1
    # Independent tensor quadrature for authored uniform boxes and hollow arms.
    box_cases = 0
    for row in kit["retainedPartsCarrier"] + kit["releasedPartsLocal"]:
        if "dimensionsMetres" not in row and "outerDimensionsMetres" not in row:
            continue
        centre = np.asarray(row["centreMetres"])
        if "outerDimensionsMetres" in row:
            pieces = [
                (1, np.array(row["outerDimensionsMetres"])),
                (-1, np.array(row["innerDimensionsMetres"])),
            ]
            rho = row["densityKgM3"]
        else:
            pieces = [(1, np.asarray(row["dimensionsMetres"]))]
            rho = row["massKg"] / np.prod(pieces[0][1])
        m, f, s = 0.0, np.zeros(3), np.zeros((3, 3))
        for sign, dims in pieces:
            dm = sign * rho * np.prod(dims) / 8
            for signs in itertools.product((-1, 1), repeat=3):
                p = centre + np.asarray(signs) * dims / (2 * np.sqrt(3))
                m += dm
                f += dm * p
                s += dm * np.outer(p, p)
        for a, b in zip((m, f, s), moments(row), strict=True):
            require(np.max(np.abs(np.asarray(a) - b)) < 1e-8, "Independent box quadrature")
        box_cases += 1
    # Continuous swept corridor uses bounds, not a sparse successful mesh sample.
    # The sampled SAT controls additionally check real geometry at 181 poses.
    native = data[audit.RESOURCE]["nativeDesign"]
    pv = np.asarray(native["vertices"]) * (60 / 19)
    triangles = pv[np.asarray(native["faces"])] + producer.POSE
    lowered = kit["retainedPartsLoweredCarrier"]
    rails = [p for p in lowered if p["id"].startswith("longitudinal-rail-")]
    sampled = 0
    for travel in np.linspace(0, 0.9, 181):
        for rail in rails:
            centre, half = np.asarray(rail["centreMetres"]), np.asarray(rail["dimensionsMetres"]) / 2
            require(
                not any(audit.triangle_box_contact(t + [travel, 0, 0], centre, half) for t in triangles),
                "Lowered support rail crosses actual moving pod",
            )
        sampled += 1
    # Restore the original unlowered support and prove that the geometry control
    # catches the actual obstruction rather than reporting a vacuous pass.
    obstructed = False
    for rail in kit["retainedPartsCarrier"]:
        if rail["id"].startswith("longitudinal-rail-"):
            obstructed |= any(
                audit.triangle_box_contact(
                    t + [0.25, 0, 0], np.array(rail["centreMetres"]), np.array(rail["dimensionsMetres"]) / 2
                )
                for t in triangles
            )
    require(obstructed, "Negative unlowered-rack control did not detect obstruction")
    rel = kit["release"]
    require(
        rel["conservativeDurationSeconds"] <= rel["maximumDurationSeconds"],
        "Timed stages exceed source window",
    )
    require(
        rel["initialStoredMechanicalJ"] - rel["fullStrokeWorkDebitJ"] == rel["remainingStoredMechanicalJ"],
        "Stored energy debit",
    )
    require(
        rel["worstMovingEnergyAndFrictionJ"] < rel["ejectionStrokeWorkDebitJ"], "Force/energy upper bound"
    )
    require(rel["initialHullGapMetres"] - rel["hullMotionBoundMetres"] > 0.25, "Hull corridor")
    require(
        min(rel["loweredRackClearanceLowerBoundMetres"], rel["finalMechanismClearanceLowerBoundMetres"])
        > 0.05,
        "Mechanism corridor",
    )

    # Full positive-but-forged mass/COM/I examples exercise the numerical
    # admission tolerances expected of the separate live matcher.
    def matches(candidate, expected):
        return (
            abs(candidate["massKg"] - expected["massKg"]) <= 1e-8
            and np.max(np.abs(np.array(candidate["centreMetres"]) - expected["centreMetres"])) <= 1e-9
            and np.max(
                np.abs(
                    np.array(candidate["inertiaAboutCentreOfMassKgM2"])
                    - expected["inertiaAboutCentreOfMassKgM2"]
                )
            )
            <= 1e-6
        )

    forgery_cases = 0
    for phase in phases.values():
        require(matches(phase, phase), "Exact descriptor rejected")
        for field, index, delta in [
            ("massKg", None, 0.01),
            ("centreMetres", 0, 0.001),
            ("inertiaAboutCentreOfMassKgM2", 0, 0.1),
            ("inertiaAboutCentreOfMassKgM2", 1, 0.1),
        ]:
            wrong = deepcopy(phase)
            if index is None:
                wrong[field] += delta
            else:
                wrong[field][index] += delta
            require(not matches(wrong, phase), "Finite forged physical allocation accepted")
            forgery_cases += 1
    return dict(
        status="PASS_SOURCE_ONLY_NATIVE_AND_OCCUPIED_ADMISSION_UNRUN",
        resourceBytes=len(raw),
        resourceSHA256=sha256(raw).hexdigest(),
        unchangedPinnedInputs=len(pins),
        phaseConservationCases=len(phase_cases),
        independentTetrahedralWedges=tetra_cases,
        independentBoxAndHollowBeamQuadratures=box_cases,
        actualSweptRailPoses=sampled,
        unloweredRackNegativeDetected=True,
        finiteForgedPhysicalAllocationsRejected=forgery_cases,
        release=rel,
        runtime=False,
        native=False,
        renderer=False,
        actorAdmission=False,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--producer", type=Path, required=True)
    parser.add_argument("--verifier", type=Path, required=True)
    parser.add_argument("--resource", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = verify(args.root, args.producer, args.verifier, args.resource)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
