"""Independent source-only controls for the actual SH029 inventory extension."""

import argparse
from copy import deepcopy
from hashlib import sha256
import importlib.util
import json
from pathlib import Path

import numpy as np


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def moments(row):
    mass = row["massKg"]
    c = np.array(row["centreMetres"])
    i = np.array(row["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3)
    return mass, mass * c, np.trace(i) / 2 * np.eye(3) - i + mass * np.outer(c, c)


def verify(root, producer, resource):
    spec = importlib.util.spec_from_file_location("okapi_load_source", producer)
    p = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(p)
    raw = resource.read_bytes()
    d = json.loads(raw)
    require(p.build(root) == d, "Byte-derived source replay")
    before = json.loads((root / "SH029-current-newt-escape-kit-v1.json").read_text())
    core = deepcopy(d)
    core.pop("ordinaryLoadModel")
    core.pop("ordinaryLoadExamples")
    require(core == before, "Original08f core changed")
    model = d["ordinaryLoadModel"]
    require(
        model["sourceGameCapacityMatches"] == dict(cargo=60, fuel=130, missiles=5, facings=3),
        "Source capacities",
    )
    rules = model["rules"]
    cargo = [r for r in rules if r["field"] == "cargo"]
    require([r["commodityIndex"] for r in cargo] == list(range(17)), "Actual commodity index set")
    require(
        all(r["unitMass"]["massKg"] == ({"t": 1000, "kg": 1, "g": 0.001}[r["nativeUnit"]]) for r in cargo),
        "Native SI units",
    )
    # Independent second-moment sum for both finite storage beds, every unit.
    for rule in cargo:
        units = rule["unitConstituents"]
        for expected, index in zip(moments(rule["unitMass"]), range(3), strict=True):
            actual = sum(moments(row)[index] for row in units)
            require(np.max(abs(expected - actual)) < 1e-8, "Two-bed cargo mixture full moments")
    fuel = next(r for r in rules if r["field"] == "fuel")
    missile = next(r for r in rules if r["field"] == "missiles")
    ecm = next(r for r in rules if r["field"] == "ecm")
    require(
        fuel["includesActualScoopRemainder"] and fuel["unitMass"]["massKg"] == 2,
        "SH029 fuel-specific authority",
    )
    require(
        missile["unitMass"]["massKg"] == 50 and len(missile["centresMetres"]) == 5,
        "SH029 missile-specific authority",
    )
    require(ecm["presence"] == "installedRegardlessOfEnable", "Disabled ECM still has hardware")
    fixed = sum(r["massKg"] for r in model["fixedComponents"]) + ecm["unitMass"]["massKg"]
    require(fixed == 180, "All fixed hardware counted once")

    def actual_mass(manifest, fuel_value, remainder, count, enabled):
        require(
            type(fuel_value) is int
            and 0 <= fuel_value <= 130
            and np.isfinite(remainder)
            and 0 <= remainder < 1
            and fuel_value + remainder <= 130,
            "Actual fuel bounded including remainder",
        )
        require(type(count) is int and 0 <= count <= 5, "Actual missiles bounded")
        require(type(enabled) is bool, "Actual ECM state")
        mass = 0
        seen = set()
        for index, quantity in manifest:
            require(
                type(index) is int
                and 0 <= index < 17
                and index not in seen
                and type(quantity) is int
                and quantity > 0,
                "Actual cargo well-formed",
            )
            seen.add(index)
            mass += quantity * cargo[index]["unitMass"]["massKg"]
        require(mass <= 60000, "Physical cargo capacity includes kg/g")
        return fixed + mass + 2 * (fuel_value + remainder) + 50 * count

    require(
        actual_mass([], 0, 0, 0, False) == 180 == actual_mass([], 0, 0, 0, True),
        "ECM toggle cannot erase mass",
    )
    require(
        actual_mass([(0, 2), (13, 12), (15, 500)], 129, 0.25, 3, False) == 2601,
        "MixedSI/fractional fuel mass",
    )
    negatives = [
        ([(13, 60001)], 0, 0, 0, False),
        ([(15, 60000001)], 0, 0, 0, False),
        ([(0, 61)], 0, 0, 0, False),
        ([(0, 1), (0, 1)], 0, 0, 0, False),
        ([(17, 1)], 0, 0, 0, False),
        ([], None, 0, 0, False),
        ([], 130, 0.1, 0, False),
        ([], 129, float("nan"), 0, False),
        ([], 129, 0, 6, False),
    ]
    for args in negatives:
        try:
            actual_mass(*args)
        except (ValueError, TypeError):
            pass
        else:
            raise ValueError("Unsupported actual positive load accepted")
    for case in d["ordinaryLoadExamples"].values():
        added = case["loadComponents"]
        for name, base in [
            ("installedOccupied", d["physicalExpectations"]["installedOccupied"]),
            ("carrierAfter", d["physicalExpectations"]["carrierAfter"]),
        ]:
            for index, expected in enumerate(moments(case[name])):
                actual = sum(moments(row)[index] for row in [base, *added])
                require(np.max(abs(expected - actual)) < 2e-7, "Loaded phase independent raw moments")
        require(
            abs(case["installedOccupied"]["massKg"] - case["carrierAfter"]["massKg"] - 352.5) < 1e-8,
            "Exact occupied pod mass transfer",
        )
    bound = model["loadedReleaseBounds"]
    require(
        bound["comCornerCases"] == 48 and bound["maximumCarrierAcceleration"] == 0.4,
        "All-load stricter envelope",
    )
    require(
        bound["loweredRackClearanceLowerBoundMetres"] > 0.05
        and bound["hullClearanceLowerBoundMetres"] > 0.25,
        "All-load release corridor",
    )
    return dict(
        status="PASS_SOURCE_ONLY_ACTUAL_LOAD_AND_NATIVE_JOIN_PENDING",
        bytes=len(raw),
        sha256=sha256(raw).hexdigest(),
        original08fCoreUnchanged=True,
        nativeUnitRules=17,
        storageMomentCases=17,
        fixedHardwareKg=fixed,
        mixedSIFractionalFuelMassKg=2601,
        unsupportedActualLoadNegatives=len(negatives),
        loadedPhysicalMomentPhases=6,
        allLoadCornerCases=48,
        disabledECMStillInstalled=True,
        runtime=False,
        native=False,
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
