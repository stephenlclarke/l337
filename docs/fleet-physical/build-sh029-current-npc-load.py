"""Author SH029-specific ordinary inventory physics without changing its bare source.

Run on MBA. Frozen08f core proof remains unchanged; ordinaryLoadModel is a new
same-slice extension. Homogenized cargo fractions share two finite storage beds.
"""

import argparse
from copy import deepcopy
from hashlib import sha256
import importlib.util
import itertools
import json
from pathlib import Path
import tomllib

import numpy as np


def build(root):
    spec = importlib.util.spec_from_file_location(
        "source_math", root / "author-reference/build-sh029-current-newt-kit.py"
    )
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    raw = (root / "SH029-current-newt-escape-kit-v1.json").read_bytes()
    if sha256(raw).hexdigest() != "7168e39583ea2ab39e4b93b0e9f6ac4e14d48b3a693d7a7bcec33b212cb4bdea":
        raise ValueError("Wrong frozen08f kit beforeimage")
    source = json.loads(raw)
    manifest = json.loads((root / "current-okapi-manifest.json").read_text())
    for row in manifest["files"]:
        b = (root / row["path"]).read_bytes()
        if len(b) != row["bytes"] or sha256(b).hexdigest() != row["sha256"]:
            raise ValueError("Changed actual current Okapi input")
    ship = tomllib.loads((root / "Sources/L337Core/Resources/Ships/SH029.toml").read_text())
    parent = json.loads((root / "Sources/L337Core/Resources/OriginalFleetPhysical/SH029.json").read_text())
    v = np.array(ship["nativeDesign"]["vertices"])
    triangles = v[np.array(ship["nativeDesign"]["faces"])[:12]]
    # Native first12 triangles are the authenticated closed pallet stock. New
    # bounds stay inside it and leave a reserved core around the existing six
    # co-centred intrinsic assemblies. Existing point-mass inertias stay intact.
    audit_spec = importlib.util.spec_from_file_location(
        "newt_geometry", root / "author-reference/verify-sh040-current-admission-source.py"
    )
    a = importlib.util.module_from_spec(audit_spec)
    audit_spec.loader.exec_module(a)

    def inside(centre, dims):
        for p in m.box_corners(centre, dims):
            winding, distance = a.point_certificate(p, triangles)
            if abs(winding - 1) > 1e-8 or distance < 1e-9:
                raise ValueError("New SH029 load bound leaves actual pallet")
        if any(a.triangle_box_contact(t, np.array(centre), np.array(dims) / 2) for t in triangles):
            raise ValueError("New SH029 load bound crosses actual pallet")

    bays = [[-5, -3, -5], [5, -3, -5]]
    bay_dims = [6, 1.2, 14]
    for c in bays:
        inside(c, [6.2, 1.4, 14.2])
    fixed = [
        m.solid("new-source-front-emitter-mass", [0.4, 0.4, 0.8], [0, -3, 12], mass=40),
        m.solid("new-source-rear-emitter-mass", [0.4, 0.4, 0.8], [0, -3, -14], mass=40),
        m.solid(
            "new-metered-fuel-liner-and-isolation",
            [0.8, 0.8, 0.8],
            [0, -3, 8],
            mass=15,
            basis="NEW finite liner/plumbing allocation; no added game fuel capacity or fuel-storage permission",
        ),
        m.solid(
            "new-five-slot-missile-magazine",
            [2, 1, 1.6],
            [5, -3, 8],
            mass=25,
            cavityDimensionsMetres=[1.8, 0.8, 1.4],
            basis="NEW complete hollow magazine allowance; no ammunition included",
        ),
    ]
    for index, c in enumerate(bays):
        outer, inner = np.array([6.2, 1.4, 14.2]), np.array(bay_dims)
        rho = 20 / (np.prod(outer) - np.prod(inner))
        mo, mi = np.prod(outer) * rho, np.prod(inner) * rho
        fixed.append(
            m.component(
                "new-hold-restraints-" + str(index),
                20,
                c,
                m.box_inertia(mo, outer) - m.box_inertia(mi, inner),
                shape="hollowStorageAssembly",
                dimensionsMetres=outer.tolist(),
                cavityDimensionsMetres=inner.tolist(),
            )
        )
    ecm = m.solid(
        "new-installed-ECM-physical-assembly",
        [0.6, 0.5, 0.6],
        [-5, -3, 8],
        mass=20,
        basis="NEW installed hardware model in both enabled/disabled states; does not enable ECM or grant an owned module",
    )
    for p in fixed + [ecm]:
        inside(p["centreMetres"], p["dimensionsMetres"])
    # Homogenization is explicit. Each actual commodity fraction contributes
    # its native SI mass spread equally over the two defined storage beds;
    # this is a mixture model, not mutually intersecting solid freight boxes.
    world_raw = (root / "Sources/L337Core/Resources/OriginalWorlds/authoring.toml").read_bytes()
    if sha256(world_raw).hexdigest() != "47d83caae5a9b22a4a932f19c55f79c5cb5435b962826a0969ece096b11f80eb":
        raise ValueError("Changed actual commodity unit source")
    commodities = sorted(tomllib.loads(world_raw.decode())["commodities"], key=lambda x: x["index"])
    if [c["index"] for c in commodities] != list(range(17)):
        raise ValueError("Wrong source commodity indices")
    rules = []
    for c in commodities:
        unit_mass = {"t": 1000, "kg": 1, "g": 0.001}[c["unit"]]
        unit = m.combine(
            "source-native-commodity-unit-" + str(c["index"]),
            [m.solid("storage-mixture-fraction", bay_dims, p, mass=unit_mass / 2) for p in bays],
        )
        rules.append(
            dict(
                field="cargo",
                commodityIndex=c["index"],
                nativeUnit=c["unit"],
                unitMass=unit,
                unitEnvelopeMetres=[16, 1.2, 14],
                centresMetres=[[0, 0, 0]],
                distribution="uniformDensityFraction",
                sharedMixtureGroup="cargo",
                unitConstituents=[
                    m.solid("storage-bed-" + str(i), bay_dims, p, mass=unit_mass / 2)
                    for i, p in enumerate(bays)
                ],
            )
        )
    rules.append(
        dict(
            field="fuel",
            unitMass=m.solid("fuel-one-actual-tenthLY", [0.7, 0.7, 0.7], [0, 0, 0], mass=2),
            unitEnvelopeMetres=[0.7, 0.7, 0.7],
            centresMetres=[[0, -3, 8]],
            distribution="uniformDensityFraction",
            includesActualScoopRemainder=True,
        )
    )
    missile_positions = [[4.4 + 0.3 * i, -3, 8] for i in range(5)]
    rules.append(
        dict(
            field="missiles",
            unitMass=m.solid("one-actual-source-missile", [0.18, 0.18, 1.2], [0, 0, 0], mass=50),
            unitEnvelopeMetres=[0.18, 0.18, 1.2],
            centresMetres=missile_positions,
            distribution="discrete",
        )
    )
    rules.append(
        dict(
            field="ecm",
            unitMass=m.solid("installed-ECM-unit", [0.6, 0.5, 0.6], [0, 0, 0], mass=20),
            unitEnvelopeMetres=[0.6, 0.5, 0.6],
            centresMetres=[[-5, -3, 8]],
            distribution="discrete",
            presence="installedRegardlessOfEnable",
            actualEnableStateMustBeSealed=True,
        )
    )

    def inventory(cargo_kg, fuel, missiles):
        result = list(fixed) + [ecm]
        if cargo_kg:
            result += [m.solid("cargo-mixture", bay_dims, c, mass=cargo_kg / 2) for c in bays]
        if fuel:
            result.append(m.solid("actual-fuel", [0.7, 0.7, 0.7], [0, -3, 8], mass=2 * fuel))
        result += [
            m.solid("actual-missile", [0.18, 0.18, 1.2], p, mass=50) for p in missile_positions[:missiles]
        ]
        return result

    corners = []
    for cargo_kg, fuel, missiles in itertools.product((0, 60000), (0, 130), range(6)):
        added = inventory(cargo_kg, fuel, missiles)
        for key in ("carrierBefore", "carrierAfter"):
            corners.append(m.combine("retained-loaded-corner", [source["physicalExpectations"][key], *added]))
    centres = np.array([p["centreMetres"] for p in corners])
    pod_com = (
        np.array(source["podCentreInCarrierMetres"])
        + source["physicalExpectations"]["occupiedPod"]["centreMetres"]
    )
    offsets = pod_com - centres
    max_radius = float(np.linalg.norm(offsets, axis=1).max())
    max_cross = float(np.linalg.norm(offsets[:, 1:], axis=1).max())
    minimum_inertia = float(
        np.linalg.eigvalsh(np.array(parent["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3)).min()
    )
    omega, t, acc = 0.05, 0.8, 0.4
    max_impulse = 372.5 * 3
    recoil = max_impulse * max_cross / minimum_inertia
    mechanism = (
        0.5 * max_radius * (omega * t) ** 2 * np.exp(omega * t)
        + 1.4 * omega * t
        + 0.5 * acc * t * t
        + recoil * max_radius * t
    )
    hull = (float(np.linalg.norm(v, axis=1).max()) + max_radius + 1.4) * omega * t + 0.5 * acc * t * t
    gap = 1.9
    if 0.28612440191387556 - mechanism < 0.05 or gap - hull < 0.25 or 0.04 + recoil > 0.05:
        raise ValueError("New actual-load SH029 corridor fails")
    source["ordinaryLoadModel"] = dict(
        catalogueShipID="SH029",
        r3SHA256=parent["contractSHA256"],
        schema="l337.current-newt-actual-load/1",
        status="NEW_AUTHORED_LOAD_PHYSICS_HUMAN_REVIEW_PENDING",
        parameterBasis="NEW SH029-specific ordinary NPC inventory/finite volume model; neither Bison units nor bare mass authority is transferred. Source root/physicalExpectations remains frozen08f reference.",
        rules=rules,
        fixedComponents=fixed,
        maximumCargoMassKilograms=60000,
        maximumFuelIncludingScoopRemainderTenthsLY=130,
        maximumMissiles=5,
        cargoUnitSource=dict(
            path="Sources/L337Core/Resources/OriginalWorlds/authoring.toml",
            sha256=sha256(world_raw).hexdigest(),
            bytes=len(world_raw),
        ),
        sourceGameCapacityMatches=dict(
            cargo=ship["game"]["cargo"],
            fuel=ship["game"]["fuel"],
            missiles=ship["game"]["missiles"],
            facings=ship["game"]["facings"],
        ),
        cargoMixture=dict(
            sharedStorageBeds=[dict(centreMetres=c, dimensionsMetres=bay_dims) for c in bays],
            maximumHomogenizedBulkDensityKgM3=1000,
            meaning="Actual SI masses are homogenized fractions in the same two finite beds; sum density is bounded. No generated manifest is empty/massless or substituted by the example.",
        ),
        inheritedCore=dict(
            centreMetres=[0, -3, -1],
            newlyDeclaredConservativeEnvelopeMetres=[3, 1.8, 4],
            massModel="Retain all inherited source masses/COM/point-approximation inertias. This new finite aggregate envelope is proposed, not recovered individual hardware geometry.",
        ),
        requiredHasFuelScoops=False,
        unknownModules="REFUSE_UNMODELED_SOURCE_COMPONENTS",
        enableStateDoesNotRemoveInstalledECM=True,
        fixedMassKilograms=sum(p["massKg"] for p in fixed) + 20,
        lowerCarrierAccelerationForLoadedRelease=0.4,
        loadedReleaseBounds=dict(
            comCornerCases=len(corners),
            maximumRelativeRadiusMetres=max_radius,
            maximumLeverPerpendicularToEjectionMetres=max_cross,
            minimumCarrierInertiaEigenvalueKgM2=minimum_inertia,
            maximumLoadedRecoilAngularSpeed=recoil,
            maximumCarrierAcceleration=acc,
            mechanismMotionBoundMetres=mechanism,
            loweredRackClearanceLowerBoundMetres=0.28612440191387556 - mechanism,
            hullMotionBoundMetres=hull,
            hullClearanceLowerBoundMetres=gap - hull,
        ),
        liveJoin="Both actual issue.birthLoad and independent actuation.load must match native Commodity.all units, actual cargo/provenance, fuel+scoopRemainder, missile count, sealed ECM/fuel-scoop state and original person0/profile. Add every physical component to actual pre/post parent mass/COM/full tensor; root reference is not loaded NPC mass.",
    )
    source["ordinaryLoadExamples"] = {}
    for name, cargo_kg, fuel, missiles in [
        ("maximumOrdinary12Tonne", 12000, 130, 5),
        ("emptyInventory", 0, 0, 0),
        ("maximumHold", 60000, 130, 5),
    ]:
        added = inventory(cargo_kg, fuel, missiles)
        source["ordinaryLoadExamples"][name] = dict(
            status="EXAMPLE_NOT_STOCK_OR_ISSUE_AUTHORITY",
            loadComponents=added,
            installedOccupied=m.combine(
                "example-installed-loaded", [source["physicalExpectations"]["installedOccupied"], *added]
            ),
            carrierAfter=m.combine(
                "example-retained-loaded", [source["physicalExpectations"]["carrierAfter"], *added]
            ),
        )
    # The delta must preserve every byte-derived core value semantically.
    core = deepcopy(source)
    core.pop("ordinaryLoadModel")
    core.pop("ordinaryLoadExamples")
    if core != json.loads(raw):
        raise ValueError("Frozen08f core changed")
    return source


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    d = build(args.root)
    args.output.write_text(json.dumps(d, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(
        json.dumps(
            dict(
                bytes=args.output.stat().st_size,
                sha256=sha256(args.output.read_bytes()).hexdigest(),
                bounds=d["ordinaryLoadModel"]["loadedReleaseBounds"],
                examples={
                    k: {
                        "installed": v["installedOccupied"]["massKg"],
                        "retained": v["carrierAfter"]["massKg"],
                    }
                    for k, v in d["ordinaryLoadExamples"].items()
                },
            ),
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
