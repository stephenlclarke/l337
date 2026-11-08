"""Derive actual unlock-phase references and contacts; numeric execution on MBA.

This does not change frozen source bytes or admit an actor. Native motion/force,
receipt/custody and persistence remain MC1/G3/G1 work.
"""

import argparse
from hashlib import sha256
import importlib.util
import json
from pathlib import Path

import numpy as np


def derive(root, resource):
    spec = importlib.util.spec_from_file_location(
        "physical_math", root / "author-reference/build-sh029-current-newt-kit.py"
    )
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    raw = resource.read_bytes()
    if sha256(raw).hexdigest() != "7ba94c62149a2f0b7b882367c946a41516f49c6c58861d5e85eec255ba9d4b4a":
        raise ValueError("Changed actual completed load-source input")
    d = json.loads(raw)
    rel = d["release"]
    lowered = m.combine("retained-kit-at-unlock", d["retainedPartsLoweredCarrier"])
    carrier = m.combine("reference-carrier-at-unlock", [d["physicalExpectations"]["bareParent"], lowered])
    pod = m.translate(d["physicalExpectations"]["occupiedPod"], d["podCentreInCarrierMetres"])
    installed = m.combine("reference-installed-at-unlock", [carrier, pod])

    def check_split(parent, child, whole, orientation, velocity, omega):
        cc = orientation @ np.array(parent["centreMetres"])
        cp = orientation @ np.array(child["centreMetres"])
        cw = orientation @ np.array(whole["centreMetres"])
        mc, mp = parent["massKg"], child["massKg"]
        vc = velocity + np.cross(omega, cc - cw)
        vp = velocity + np.cross(omega, cp - cw)
        ic = orientation @ np.array(parent["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3) @ orientation.T
        ip = orientation @ np.array(child["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3) @ orientation.T
        iw = orientation @ np.array(whole["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3) @ orientation.T
        p = mc * vc + mp * vp
        angular = (
            ic @ omega
            + ip @ omega
            + np.cross(cc - cw, mc * (vc - velocity))
            + np.cross(cp - cw, mp * (vp - velocity))
        )
        kinetic = (
            0.5 * mc * (vc @ vc) + 0.5 * mp * (vp @ vp) + 0.5 * omega @ ic @ omega + 0.5 * omega @ ip @ omega
        )
        before = 0.5 * (mc + mp) * (velocity @ velocity) + 0.5 * omega @ iw @ omega
        if (
            np.linalg.norm(p - (mc + mp) * velocity) > 1e-8
            or np.linalg.norm(angular - iw @ omega) > 1e-7
            or abs(kinetic - before) > 1e-7
        ):
            raise ValueError("Actual rigid material-velocity split does not conserve P/L/energy")
        return dict(
            linearMomentumErrorNs=float(np.linalg.norm(p - (mc + mp) * velocity)),
            angularMomentumErrorKgM2PerSecond=float(np.linalg.norm(angular - iw @ omega)),
            kineticEnergyErrorJ=float(abs(kinetic - before)),
        )

    checks = []
    angle = 0.37
    c, s = np.cos(angle), np.sin(angle)
    for case in d["ordinaryLoadExamples"].values():
        loaded_carrier = m.combine("loaded-carrier-at-unlock", [carrier, *case["loadComponents"]])
        loaded_installed = m.combine("loaded-installed-at-unlock", [installed, *case["loadComponents"]])
        for rotation in (np.eye(3), np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])):
            checks.append(
                check_split(
                    loaded_carrier,
                    pod,
                    loaded_installed,
                    rotation,
                    np.array([2.0, -3.0, 4.0]),
                    np.array([0.01, 0.02, 0.03]),
                )
            )
    rods = sorted(
        [p for p in d["retainedPartsLoweredCarrier"] if p["id"].startswith("moving-rod-")],
        key=lambda p: p["centreMetres"][2],
    )
    shoes = sorted(
        [p for p in d["releasedPartsLocal"] if p["id"].startswith("portable-thrust-shoe-")],
        key=lambda p: p["centreMetres"][2],
    )
    contacts = []
    pose = np.array(d["podCentreInCarrierMetres"])
    for rod, shoe in zip(rods, shoes, strict=True):
        centre = np.array(rod["centreMetres"])
        half = np.array(rod["dimensionsMetres"]) / 2
        verts = np.array(shoe["verticesMetres"]) + pose
        face = verts[np.abs(verts[:, 0] - verts[:, 0].min()) < 1e-10]
        x = centre[0] + half[0]
        gap = face[0, 0] - x
        margins = []
        for sy in (-1, 1):
            for sz in (-1, 1):
                point = centre + [half[0], sy * half[1], sz * half[2]]
                margins.extend(
                    [
                        point[1] - face[:, 1].min(),
                        face[:, 1].max() - point[1],
                        point[2] - face[:, 2].min(),
                        face[:, 2].max() - point[2],
                    ]
                )
        if abs(gap) > 1e-9 or min(margins) < -1e-9:
            raise ValueError("Actual rod end is not tangent inside the portable shoe face")
        contacts.append(
            dict(
                rod=rod["id"],
                shoe=shoe["id"],
                normalCarrier=[1, 0, 0],
                signedFaceGapMetres=float(gap),
                minimumFootprintMarginMetres=float(min(margins)),
                initialRelativeAxialVelocity=0,
                physics="Ordinary unilateral contact. Paid rod acceleration initially pushes; actual pod is independent from unlock. No general collision exemption.",
            )
        )
    unlock = rel["rackLoweringDurationSeconds"]
    powered = (
        rel["ejectionDurationSeconds"]
        - rel["postStrokeFreeTravelMetres"] / rel["relativeSpeedIncrementMetresPerSecond"]
    )
    return dict(
        schema=1,
        id="SH029-unlock-physical-reference-v1",
        inputSHA256=sha256(raw).hexdigest(),
        status="SOURCE_REFERENCE_ONLY_NATIVE_CONTACT_CUSTODY_EXECUTION_PENDING",
        exactBoundary="existing source unlock BEFORE powered stroke",
        sampledDelayMeansMechanismStart=True,
        offsetsSeconds=dict(
            unlockAfterStart=unlock,
            poweredStrokeCompleteAfterStart=unlock + powered,
            coastValidationAfterStart=unlock + rel["ejectionDurationSeconds"],
        ),
        actualCompletionRequired="Offsets are the source controlled-motion profile. Native actuator completion and actual observed elapsed time must agree; clocks alone do not create movement.",
        referenceMasses=dict(
            retainedAtUnlock=lowered, carrierAtUnlock=carrier, installedAtUnlock=installed, podAtUnlock=pod
        ),
        referenceMassesFrame="Carrier source coordinates, including podAtUnlock COM; pod body-local properties are separate below.",
        podBodyLocal=d["physicalExpectations"]["occupiedPod"],
        podSourceOriginInCarrierMetres=d["podCentreInCarrierMetres"],
        actualLoads="Add every actual sealed inventory component to installed/retained references, never the pod. Actual original person0/profile is already in the occupied pod reference.",
        inheritedVelocityRule="Split actual whole-body COM velocity into V+omega cross(componentCOM-wholeCOM); preserve actual world poses/orientations/spins and P/L/kinetic energy. No new ejection impulse or3m/s assignment at unlock.",
        independentRigidSplitChecks=checks,
        rodShoeContacts=contacts,
        mechanicalAtUnlock=dict(
            guideStoredJ=1000,
            ejectionStoredJ=3000,
            spentGuideJ=2000,
            spentEjectionJ=0,
            ejectionWorkReservedJ=2400,
            storeOwner="actual retained carrier/kitID",
        ),
        mechanicalAtPoweredStrokeComplete=dict(
            guideStoredJ=1000, ejectionStoredJ=600, totalRemainingJ=1600, spentEjectionJ=2400
        ),
        electricalAccounting="Source120000J startup includes20J latch unlock; do not add20J again. Actual continuous42W/oxygen/CO2 clocks continue from real observation.",
        refusalBeforeUnlock="Existing latch staysclosed; actual lowered/spent state stays. No free restoration to stowed or recharging.",
        afterUnlock="Independent native pod/person/custody and retained mechanism continue even on placement/writer refusal. No reattachment/refund/rollback-to-aboard. Coast completion validates real native motion only.",
        native=False,
        compiler=False,
        actorAdmission=False,
    )


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("root", "resource", "output"):
        p.add_argument("--" + name, type=Path, required=True)
    args = p.parse_args()
    d = derive(args.root, args.resource)
    args.output.write_text(json.dumps(d, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(
        json.dumps(
            dict(
                bytes=args.output.stat().st_size,
                sha256=sha256(args.output.read_bytes()).hexdigest(),
                offsets=d["offsetsSeconds"],
                contacts=d["rodShoeContacts"],
                checks=d["independentRigidSplitChecks"],
            ),
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
