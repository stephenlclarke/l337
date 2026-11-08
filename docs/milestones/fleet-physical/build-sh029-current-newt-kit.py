"""Author one explicit occupied kit from immutable current inputs, on MBA only.

This producer creates source engineering, never stock, a person, or actor authority.
All additional geometry, material ratings and service ratings are new design inputs.
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

ID = "SH029-current-newt-escape-kit-v1"
RESOURCE = "Sources/L337Core/Resources/OriginalFleetPhysical/" + ID + ".json"
POSE = np.array([12.5, -3.0, -1.0])


def box_corners(centre, dimensions):
    return np.asarray(centre) + np.asarray(list(itertools.product((-0.5, 0.5), repeat=3))) * dimensions


def box_inertia(mass, dimensions):
    squares = np.asarray(dimensions) ** 2
    return np.diag(mass * (squares.sum() - squares) / 12)


def parallel(mass, displacement):
    d = np.asarray(displacement)
    return mass * (np.dot(d, d) * np.eye(3) - np.outer(d, d))


def component(name, mass, centre, inertia, **extra):
    return dict(
        id=name,
        massKg=float(mass),
        centreMetres=np.asarray(centre).tolist(),
        inertiaAboutCentreOfMassKgM2=np.asarray(inertia).reshape(-1).tolist(),
        **extra,
    )


def solid(name, dimensions, centre, density=None, mass=None, **extra):
    dimensions = np.asarray(dimensions)
    if mass is None:
        mass = float(np.prod(dimensions) * density)
    return component(
        name,
        mass,
        centre,
        box_inertia(mass, dimensions),
        shape="solidBox" if density else "effectiveUniformBoxMassModel",
        dimensionsMetres=dimensions.tolist(),
        densityKgM3=density,
        **extra,
    )


def combine(name, rows):
    mass = sum(p["massKg"] for p in rows)
    centre = sum(p["massKg"] * np.asarray(p["centreMetres"]) for p in rows) / mass
    inertia = sum(
        np.asarray(p["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3)
        + parallel(p["massKg"], np.asarray(p["centreMetres"]) - centre)
        for p in rows
    )
    if np.linalg.eigvalsh(inertia).min() <= 0:
        raise ValueError("Nonpositive full physical tensor: " + name)
    return component(name, mass, centre, inertia)


def translate(row, offset):
    result = deepcopy(row)
    result["centreMetres"] = (np.asarray(row["centreMetres"]) + offset).tolist()
    for key in ("verticesMetres", "subtractedVerticesMetres"):
        if key in row:
            result[key] = (np.asarray(row[key]) + offset).tolist()
    return result


def wedge(name, x0, x1, y0, top0, top1, z0, z1, density):
    # Analytic integration of an affine-height rectangular extrusion. Gauss
    # integration is exact here (degree <= 3); controls use tetrahedral volume.
    points, weights = np.polynomial.legendre.leggauss(3)
    mass, first, second = 0.0, np.zeros(3), np.zeros((3, 3))
    for t, w in zip((points + 1) / 2, weights / 2, strict=True):
        x = x0 + t * (x1 - x0)
        top = top0 + t * (top1 - top0)
        h = top - y0
        if h <= 0:
            raise ValueError("Nonpositive conformal saddle thickness")
        dm = density * (x1 - x0) * (z1 - z0) * h * w
        c = np.array([x, (y0 + top) / 2, (z0 + z1) / 2])
        mass += dm
        first += dm * c
        second += dm * (np.outer(c, c) + np.diag([0, h * h / 12, (z1 - z0) ** 2 / 12]))
    centre = first / mass
    covariance = second - mass * np.outer(centre, centre)
    inertia = np.trace(covariance) * np.eye(3) - covariance
    vertices = [
        [x0, y0, z0],
        [x1, y0, z0],
        [x1, top1, z0],
        [x0, top0, z0],
        [x0, y0, z1],
        [x1, y0, z1],
        [x1, top1, z1],
        [x0, top0, z1],
    ]
    return component(
        name, mass, centre, inertia, shape="affineHeightWedge", verticesMetres=vertices, densityKgM3=density
    )


def source_row(name, record):
    return component(
        name,
        record["dryMassKilograms"],
        record["centreOfMassMetres"],
        record["inertiaAboutCentreOfMassKgM2"],
        shape="unchangedPinnedSource",
    )


def load_inputs(root, verifier):
    spec = importlib.util.spec_from_file_location("current_newt_audit", verifier)
    audit = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(audit)
    data = audit.authenticate(root)
    pins = deepcopy(audit.PINS)
    manifest = json.loads((root / "current-parent-manifest.json").read_text())
    for pin in manifest["files"]:
        raw = (root / pin["path"]).read_bytes()
        if len(raw) != pin["bytes"] or sha256(raw).hexdigest() != pin["sha256"]:
            raise ValueError("Changed exact bare parent: " + pin["path"])
        pins[pin["path"]] = dict(bytes=len(raw), sha256=sha256(raw).hexdigest())
        data[pin["path"]] = tomllib.loads(raw.decode()) if pin["path"].endswith(".toml") else json.loads(raw)
    return audit, data, pins


def build(root, verifier):
    audit, data, pins = load_inputs(root, verifier)
    cryo = audit.audit(root)
    pod_record = data[audit.PHYSICAL]
    parent_record = data["Sources/L337Core/Resources/OriginalFleetPhysical/SH029.json"]
    native = data[audit.RESOURCE]["nativeDesign"]
    pv = np.asarray(native["vertices"]) * (60 / 19)
    pt = pv[np.asarray(native["faces"])]
    parent_native = data["Sources/L337Core/Resources/Ships/SH029.toml"]["nativeDesign"]
    hv = np.asarray(parent_native["vertices"])
    person = solid(
        "actual-identified-person",
        [0.56, 0.38, 1.72],
        [0, 0.12, -0.02],
        mass=100,
        modelID="SH029-newt-single-identified-person-100kg-authored-v1",
    )
    portable = solid("portable-isolating-coupler", [0.16, 0.06, 0.05], [0, -0.29, -0.975], mass=1)
    # Gas has a declared point-mass approximation at the pressure-cell origin.
    # It is charged stock; its 2.5 kg is not part of the unchanged 248 kg dry pod.
    gas = component(
        "charged-free-atmosphere",
        2.5,
        [0, 0, 0],
        np.zeros((3, 3)),
        shape="pressureCellPointMassApproximation",
        newlyChargedConsumable=True,
    )
    for item in (person, portable):
        centre, half = np.asarray(item["centreMetres"]), np.asarray(item["dimensionsMetres"]) / 2
        certs = [audit.point_certificate(c, pt) for c in box_corners(centre, half * 2)]
        if any(abs(w - 1) > 1e-8 or d <= 1e-10 for w, d in certs):
            raise ValueError("New occupied bound leaves current closed pod")
        if any(audit.triangle_box_contact(t, centre, half) for t in pt):
            raise ValueError("New occupied bound crosses current closed pod")
        for fixed in pod_record["intrinsicHardware"]:
            h = np.asarray(fixed["halfExtentsMetres"])
            if np.any(h) and np.all(half + h - np.abs(centre - fixed["centreMetres"]) > 1e-10):
                raise ValueError("New occupied bound overlaps fixed hardware: " + fixed["id"])
    display = data[audit.RESOURCE]["design"]
    dv = np.asarray(display["vertices"]) * (60 / 19)
    # The existing couch and lid rails are geometry clearance bounds, not new
    # material mass inferred from a decorative mesh or a modification of dry I.
    for face in display["faces"][91:179]:
        for i in range(1, len(face) - 1):
            if audit.triangle_box_contact(
                dv[[face[0], face[i], face[i + 1]]],
                np.asarray(person["centreMetres"]),
                np.array([0.28, 0.19, 0.86]),
            ):
                raise ValueError("Actual person envelope crosses current couch/lid support")
    # NEW flat thrust faces avoid pretending that a flat rod can load a curved
    # shell at its mass centre. The 2 kg portable allowance is one 1 kg isolator
    # and two 0.5 kg conformal shoes bonded to the unchanged barrel facets.
    shoes = []
    for z in (-0.75, 0.75):
        y0, y1 = -0.055, -0.005
        shoe = wedge(
            "portable-thrust-shoe-" + str(z),
            y0,
            y1,
            -0.60,
            -108 / 190 - y0 * 0.3,
            -108 / 190 - y1 * 0.3,
            z - 0.04,
            z + 0.04,
            1,
        )
        order = [1, 0, 2]
        shoe["centreMetres"] = np.asarray(shoe["centreMetres"])[order].tolist()
        shoe["verticesMetres"] = np.asarray(shoe["verticesMetres"])[:, order].tolist()
        scale = 0.5 / shoe["massKg"]
        shoe["densityKgM3"] = scale
        shoe["massKg"] = 0.5
        si = np.asarray(shoe["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3)
        shoe["inertiaAboutCentreOfMassKgM2"] = (si[np.ix_(order, order)] * scale).reshape(-1).tolist()
        shoe["basis"] = "NEW conformal interface, authored 0.5 kg complete bonded shoe allowance"
        shoes.append(shoe)
    pod = source_row("unchanged-current-newt-dry", pod_record)
    release_parts = [pod, portable, gas, person, *shoes]
    release_local = combine("released-occupied-cell", release_parts)
    retained = []
    # A new backplate ties the four flush feet, arms and actuator housings.
    # Feet end at x=10.012; plate begins there; arms/housings begin at 10.032.
    retained.append(solid("new-backplate", [0.02, 1.4, 2.0], [10.022, -3.5, -1], density=2700))
    for z in (-1.75, -0.25):
        retained.append(
            solid(
                "rack-drop-guide-" + str(z),
                [0.12, 0.8, 0.16],
                [10.092, -3.8, z],
                mass=16,
                includedSpringSteelKg=6,
                usableStoredMechanicalJ=1500,
                operation="NEW sealed vertical sliding bearing; arm retracts .40m before ejection",
            )
        )
        outer, inner = np.array([2.748, 0.24, 0.12]), np.array([2.748, 0.216, 0.096])
        mo, mi = np.prod(outer) * 2700, np.prod(inner) * 2700
        retained.append(
            component(
                "crossarm-" + str(z),
                mo - mi,
                [11.526, -3.64, z],
                box_inertia(mo, outer) - box_inertia(mi, inner),
                shape="hollowRectangularPrism",
                outerDimensionsMetres=outer.tolist(),
                innerDimensionsMetres=inner.tolist(),
                densityKgM3=2700,
            )
        )
        for y in (-3.72, -3.48):
            if not (-4.25 <= y - 0.1 and y + 0.1 <= -1.75 and -15.5 <= z - 0.08 and z + 0.08 <= 13.5):
                raise ValueError("Foot leaves actual starboard parent pallet")
            retained.append(
                solid(
                    "attachment-foot-" + str((y, z)),
                    [0.012, 0.20, 0.16],
                    [10.006, y, z],
                    density=7800,
                    parentFaces=[6, 7],
                )
            )
    for x in (12.18, 12.82):
        retained.append(solid("longitudinal-rail-" + str(x), [0.06, 0.06, 2.6], [x, -3.49, -1], density=2700))

    # Lower shell facet is read from actual calibrated current vertices. Both
    # pads stay wholly on its central barrel and touch the shell without overlap.
    def lower_y(x):
        return -3 + np.interp(abs(x), [pv[22, 0], pv[23, 0]], [pv[22, 1], pv[23, 1]])

    for x, z in itertools.product((-0.32, 0.32), (-0.75, 0.75)):
        a, b = x - 0.02, x + 0.02
        ya, yb = lower_y(a), lower_y(b)
        metal = wedge(
            "saddle-metal-" + str((x, z)),
            12.5 + a,
            12.5 + b,
            -3.46,
            ya - 0.001,
            yb - 0.001,
            -1 + z - 0.09,
            -1 + z + 0.09,
            2700,
        )
        full = wedge("saddle-full", 12.5 + a, 12.5 + b, -3.46, ya, yb, -1 + z - 0.09, -1 + z + 0.09, 1200)
        base = wedge(
            "saddle-base",
            12.5 + a,
            12.5 + b,
            -3.46,
            ya - 0.001,
            yb - 0.001,
            -1 + z - 0.09,
            -1 + z + 0.09,
            1200,
        )
        # Thin conformal coating is a signed-volume material difference.
        coating = deepcopy(full)
        coating["id"] = "saddle-coating-" + str((x, z))
        coating["massKg"] = full["massKg"] - base["massKg"]
        cf, cb = np.asarray(full["centreMetres"]), np.asarray(base["centreMetres"])
        cc = (full["massKg"] * cf - base["massKg"] * cb) / coating["massKg"]
        origin = (
            np.array(full["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3)
            + parallel(full["massKg"], cf)
            - np.array(base["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3)
            - parallel(base["massKg"], cb)
        )
        coating["centreMetres"] = cc.tolist()
        coating["inertiaAboutCentreOfMassKgM2"] = (
            (origin - parallel(coating["massKg"], cc)).reshape(-1).tolist()
        )
        coating["shape"] = "affineHeightWedgeDifference"
        coating["subtractedVerticesMetres"] = base["verticesMetres"]
        retained.extend([metal, coating])
    occupied_com = POSE + release_local["centreMetres"]
    rod_mass = float(1.8 * 0.028**2 * 2700)
    tip_x = float(POSE[0] - 0.60)
    for z in (occupied_com[2] - 0.75, occupied_com[2] + 0.75):
        retained.append(
            solid(
                "actuator-housing-" + str(z),
                [1.2, 0.12, 0.12],
                [10.632, occupied_com[1], z],
                mass=14 - rod_mass,
                includedSpringSteelKg=6,
                usableStoredMechanicalJ=1500,
            )
        )
        retained.append(
            solid(
                "moving-rod-" + str(z),
                [1.8, 0.028, 0.028],
                [tip_x - 0.9, occupied_com[1], z],
                density=2700,
                finalTranslationMetres=[0.6, 0, 0],
            )
        )
        retained.append(
            solid(
                "new-release-latch-" + str(z),
                [0.08, 0.08, 0.12],
                [10.10, occupied_com[1] + 0.10, z],
                mass=3,
                operation="NEW internal retracting catch within housing/rod; unlock before stroke",
            )
        )
    retained.append(solid("carrier-isolating-coupler", [0.16, 0.06, 0.05], [10.112, -3.25, -1], mass=2))
    frame = combine("retained-kit-stowed", retained)

    def is_drop_part(p):
        return p["id"].startswith(("crossarm-", "longitudinal-rail-", "saddle-"))

    drop_parts = [p for p in retained if is_drop_part(p)]
    lowered_parts = [translate(p, [0, -0.4, 0]) if is_drop_part(p) else p for p in retained]
    final_parts = [
        translate(p, [0.6, 0, 0]) if p["id"].startswith("moving-rod-") else p for p in lowered_parts
    ]
    final_frame = combine("retained-kit-rods-extended", final_parts)
    parent = source_row("bare-parent", parent_record)
    carrier_before = combine("carrier-with-frame-before", [parent, frame])
    carrier_after = combine("carrier-with-frame-after", [parent, final_frame])
    released_start = translate(release_local, POSE)
    released_end = translate(release_local, POSE + [0.9, 0, 0])
    installed = combine("occupied-installed", [parent, frame, released_start])
    final_composite = combine("post-stroke-separated-composite", [carrier_after, released_end])
    # A source-controlled continuous time bound: accelerate at >=3500 N / the
    # rated moving mass, govern to 3 m/s, complete stroke, then coast 0.30 m.
    maximum_pod_mass = release_local["massKg"] + 20
    moving_rods = 2 * rod_mass
    amin = 3500 / (maximum_pod_mass + moving_rods)
    acceleration_time = 3 / amin
    acceleration_distance = 4.5 / amin
    drop_mass = sum(p["massKg"] for p in drop_parts)
    drop_duration = 2 * np.sqrt(0.4 * drop_mass / 3500)
    ejection_duration = acceleration_time + (0.6 - acceleration_distance) / 3 + 0.30 / 3
    total_time = drop_duration + ejection_duration
    if acceleration_distance > 0.6 or total_time > 0.8:
        raise ValueError("Insufficient force/stroke/time")
    # Shared initial rotation cancels first-order relative position: exp(Wt)r
    # versus r + Wrt. Include the residual, independent acceleration, pod
    # orientation bound and maximum new recoil drift separately.
    radius = float(np.linalg.norm(occupied_com - carrier_after["centreMetres"]))
    outer_pod_vertices = np.concatenate([pv, *[np.asarray(s["verticesMetres"]) for s in shoes]])
    pod_radius = float(np.linalg.norm(outer_pod_vertices, axis=1).max())
    omega, horizon = 0.05, 0.8
    spin_residual = 0.5 * radius * (omega * horizon) ** 2 * np.exp(omega * horizon)
    orientation_drift = pod_radius * omega * horizon
    acceleration_drift = 0.5 * 0.5 * horizon**2
    reduced_mass = (
        release_local["massKg"]
        * carrier_after["massKg"]
        / (release_local["massKg"] + carrier_after["massKg"])
    )
    impulse = reduced_mass * 3
    r = occupied_com - carrier_after["centreMetres"]
    recoil = np.linalg.solve(
        np.asarray(carrier_after["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3), np.cross(r, [-impulse, 0, 0])
    )
    recoil_drift = float(np.linalg.norm(recoil)) * radius * horizon
    mechanism_error = spin_residual + orientation_drift + acceleration_drift + recoil_drift
    hull_gap = float((outer_pod_vertices + POSE)[:, 0].min() - hv[:, 0].max())
    hull_error = (
        float(np.linalg.norm(hv, axis=1).max()) + radius + pod_radius
    ) * omega * horizon + acceleration_drift
    lowered_rack_top = max(
        (
            float(np.asarray(p["verticesMetres"])[:, 1].max())
            if "verticesMetres" in p
            else float(
                p["centreMetres"][1]
                + np.asarray(p.get("dimensionsMetres", p.get("outerDimensionsMetres")))[1] / 2
            )
        )
        for p in lowered_parts
        if is_drop_part(p)
    )
    rack_gap = float((outer_pod_vertices + POSE)[:, 1].min() - lowered_rack_top)
    if min(0.30, rack_gap) - mechanism_error < 0.05 or hull_gap - hull_error < 0.25:
        raise ValueError("Conservative timed release corridor fails")
    spring_capacity = 6 * 1e9**2 / (2 * 2e11 * 7800)
    unsupported = tip_x + 0.6 - (10.632 + 0.6)
    buckling = np.pi**2 * 70e9 * 0.028**4 / 12 / (2 * unsupported) ** 2
    if spring_capacity < 1500 or buckling < 4000:
        raise ValueError("Spring capacity / rod column bound fails")
    # Root bending bound deliberately places ALL external mass at the far tip.
    maximum_outboard_mass = frame["massKg"] + maximum_pod_mass
    root_moment = maximum_outboard_mass * 25 * 1.25 * 2.9 / 2
    section = (0.12 * 0.24**3 - 0.096 * 0.216**3) / 12 / 0.12
    stress = root_moment / section
    if stress > 120e6:
        raise ValueError("Conservative transverse root bending bound fails")
    # Spring work includes stopped-rod KE, all guide friction and recoil KE.
    worst_energy = (
        0.5 * (maximum_pod_mass + moving_rods) * 9
        + 500 * 0.6
        + 0.5 * float(np.cross(r, [-impulse, 0, 0]) @ recoil)
    )
    if worst_energy > 2400:
        raise ValueError("Stored work cannot pay release")
    all_vertices = [hv, outer_pod_vertices + POSE]
    for p in retained:
        if "dimensionsMetres" in p:
            all_vertices.append(box_corners(p["centreMetres"], p["dimensionsMetres"]))
        elif "outerDimensionsMetres" in p:
            all_vertices.append(box_corners(p["centreMetres"], p["outerDimensionsMetres"]))
        elif "verticesMetres" in p:
            all_vertices.append(np.asarray(p["verticesMetres"]))
    envelope = np.concatenate(all_vertices)
    return dict(
        schemaVersion=1,
        id=ID,
        status="NEW_AUTHORED_EQUIPPED_SOURCE_REQUIRES_LIVE_ADMISSION",
        parameterBasis="All kit geometry/material/service/person values are newly authored, not recovered or previously approved. Parent and current Newt bytes remain unchanged.",
        coordinateUnits="metres",
        sourcePins=pins,
        parentCatalogueID="SH029",
        podCatalogueID="SH040",
        podCount=1,
        fitting=dict(slot="utility.escapePod", nodeKey="Escape Pod", equipmentUnits=1, utilityMounts=1),
        personProfile=person,
        maximumDesignPersonKg=120,
        podCentreInCarrierMetres=POSE.tolist(),
        releasedPartsLocal=release_parts,
        retainedPartsCarrier=retained,
        retainedPartsLoweredCarrier=lowered_parts,
        retainedPartsAfterStrokeCarrier=final_parts,
        physicalExpectations=dict(
            bareParent=parent,
            dryPod=pod,
            occupiedPod=release_local,
            retainedStowed=frame,
            retainedExtended=final_frame,
            carrierBefore=carrier_before,
            carrierAfter=carrier_after,
            installedOccupied=installed,
            separatedComposite=final_composite,
        ),
        fittedBounds=dict(
            minimumMetres=envelope.min(axis=0).tolist(),
            maximumMetres=envelope.max(axis=0).tolist(),
            radiusAboutSourceOriginMetres=float(np.linalg.norm(envelope, axis=1).max()),
            geometry="Pinned parent + pinned hull-only pod + declared new component bounds; internal person/coupler/gas do not inflate outer collision",
        ),
        release=dict(
            directionCarrier=[1, 0, 0],
            strokeMetres=0.6,
            postStrokeFreeTravelMetres=0.30,
            relativeSpeedIncrementMetresPerSecond=3,
            rackLoweringMetres=0.40,
            rackMovingMassKg=float(drop_mass),
            rackLoweringDurationSeconds=float(drop_duration),
            ejectionDurationSeconds=float(ejection_duration),
            maximumDurationSeconds=0.8,
            conservativeDurationSeconds=float(total_time),
            guaranteedNetForceN=3500,
            governedForceN=4000,
            maximumGuideFrictionN=500,
            initialStoredMechanicalJ=6000,
            rackLoweringWorkDebitJ=2000,
            ejectionStrokeWorkDebitJ=2400,
            fullStrokeWorkDebitJ=4400,
            remainingStoredMechanicalJ=1600,
            worstMovingEnergyAndFrictionJ=float(worst_energy),
            maximumRatedReleasedMassKg=maximum_pod_mass,
            movingRodMassKg=moving_rods,
            nominalImpulseNs=float(impulse),
            nominalCarrierRecoilAngularVelocityIncrement=recoil.tolist(),
            maximumInitialCarrierAngularSpeed=0.04,
            maximumIncludingRecoilAngularSpeed=0.05,
            maximumCarrierAcceleration=0.5,
            minimumHullClearanceMetres=0.25,
            minimumMechanismClearanceMetres=0.05,
            initialHullGapMetres=hull_gap,
            hullMotionBoundMetres=float(hull_error),
            mechanismMotionBoundMetres=float(mechanism_error),
            finalMechanismClearanceLowerBoundMetres=float(0.30 - mechanism_error),
            loweredRackGapMetres=rack_gap,
            loweredRackClearanceLowerBoundMetres=float(rack_gap - mechanism_error),
            carrierSourceOriginRecoilTranslationMetres=(
                np.asarray(installed["centreMetres"]) - final_composite["centreMetres"]
            ).tolist(),
            sharedRotationSecondOrderBoundMetres=float(spin_residual),
            springElasticCapacityPerUnitJ=float(spring_capacity),
            rodEulerBucklingBoundN=float(buckling),
            rootBendingStressBoundPa=float(stress),
            newAssumedAllowableBendingPa=120e6,
            motionRule="Use actual native elapsed time and inherited V + omega cross offset. Apply equal/opposite impulse at occupied pod COM; conserve full angular momentum with extended-rod retained tensor. No pose/velocity reset, teleport, default 80m/s, or radius24 clearance.",
            energyRule="Shared initial rigid rotation cancels first-order actuator work. Lower the rack first and debit2000J including braking/friction. Then debit2400J ejection work including governor dissipation/rod stop. Validate actual full kinetic-energy deltas and charges. No recharge from disabled carrier. Both stages and latches need native elapsed time; no instantaneous lowering.",
        ),
        service=dict(
            id="current-newt-equipped-service-authored-v1",
            ratedSupportSeconds=21600,
            initialFreeAtmosphereKg=2.5,
            existingDryCartridgeCount=2,
            dryCartridgeMassEachKg=5,
            oxygenKg=1,
            sorbentKg=1.5,
            sorbentCapacityKgCO2=0.75,
            cartridgeHousingAndRegulatorKg=7.5,
            oxygenConsumptionKgPerMinute=0.001,
            carbonDioxideProductionKgPerMinute=0.0014,
            sixHourOxygenUsedKg=0.36,
            sixHourCO2ProducedKg=0.504,
            existingDryBatteryCount=2,
            dryBatteryMassEachKg=12,
            newlyRatedUsableElectricalJ=1500000,
            startupElectricalJ=120000,
            latchUnlockElectricalJ=20,
            continuousPowerW=42,
            sixHourElectricalUsedJ=1027200,
            remainingElectricalJ=472800,
            minimumReserveFraction=0.25,
            basis="NEW commissioned finite stock charge/specification in existing dry pack/cartridge masses; no service capacity conferred on bare or previously born Newt. Requires actual pressure/temperature/charge/person compatibility at admission.",
        ),
        admission=dict(
            actualPersonIdentityRequired=True,
            actualPhysicalProfileRequired=True,
            finiteStockIssueAndDebitRequired=True,
            retainedFrameMustRemain=True,
            ordinaryRoleOrCrewGrant=False,
            existingActorRetrofit=False,
            physicalTolerance=dict(
                massKg=1e-8,
                centreMetres=1e-9,
                inertiaKgM2=1e-6,
                motionMetres=1e-6,
                timeSeconds=1e-9,
                energyJ=1e-6,
            ),
            compare="Authenticate resource then compare every phase mass/COM/full tensor, actual person and stock IDs, native times, posed corridor, momentum/energy and life-support charges. Finite or positive alone is not admission.",
        ),
        evidence=dict(
            currentNewtEmptyAuditPassed=cryo["status"] if "status" in cryo else True,
            personAndPortableCouplerWholeBoundsInsideCurrentShell=True,
            personDisjointFiniteHardwareAndCurrentCouchLidGeometry=True,
            currentCradleAndHingeMassModels="Inherited dry point allocations; couch/lid source triangles supply clearance bounds, not new inferred mass",
            runtime=False,
            native=False,
            renderer=False,
            occupiedActor=False,
        ),
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--verifier", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = build(args.root, args.verifier)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(
        json.dumps(
            dict(
                path=str(args.output),
                bytes=args.output.stat().st_size,
                sha256=sha256(args.output.read_bytes()).hexdigest(),
                physical=result["physicalExpectations"],
                release=result["release"],
            ),
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
