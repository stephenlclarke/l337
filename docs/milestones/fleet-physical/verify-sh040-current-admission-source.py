"""Audit only the immutable current human cryopod source and empty budget on MBA.

No runtime/cache change, occupied admission, actuation, life support or escape grant.
"""

import argparse
from collections import Counter
from fractions import Fraction
from hashlib import sha256
import json
import math
from pathlib import Path
import tomllib

import numpy as np

PINS = {
    "Sources/L337Core/OriginalCryostasisCapsule.swift": {
        "bytes": 2839,
        "sha256": "441d2d3f0c8ffd1a7d452c70777dd53e255df305f18940e2a5a28be1680d2fd1",
    },
    "Sources/L337Core/Resources/OriginalFleetPhysical/SH040.json": {
        "bytes": 8132,
        "sha256": "0d7cd491b77b6e14016daa8a3c5e622416963870f669f80d63ad3b4d74aaee17",
    },
    "Sources/L337Core/Resources/OriginalFleetShowroomModels/SH040.json": {
        "bytes": 3131,
        "sha256": "d8bdfba7e35120cd6b020b4ca5878da6e3f3e9278bbfc5ee2c65e86280510e1d",
    },
    "Sources/L337Core/Resources/Ships/SH040.toml": {
        "bytes": 27799,
        "sha256": "510a2059ce49a7d902c11ca65303264afa8ee103cd1a9e9ad823dbe05fee816c",
    },
    "Tests/L337CoreTests/OriginalNewtCapsuleSourceTests.swift": {
        "bytes": 11102,
        "sha256": "34ea722ad93b4dcf03f862f5c766e5cc79f3a86267941d8fd90b644e0307cb95",
    },
    "docs/fleet-design-v2/successors/SH040-CRYOSTASIS.md": {
        "bytes": 3752,
        "sha256": "04f59d35d5b46d0c209f7a611a9609a96dbc81b5f25e4818a01edf450005c1a6",
    },
    "docs/fleet-design-v2/successors/SH040-cryostasis-engineering.json": {
        "bytes": 6881,
        "sha256": "3c40451f7c6690059636e1d2baf654e47ea6f4b5ffab6699eee8668f378d2ee4",
    },
    "docs/fleet-design-v2/successors/SH040-cryostasis-r3.toml": {
        "bytes": 2812,
        "sha256": "6dd8182abf9a00406132db7926c962d470ea7f6c112bb29fad8646aef9aec0ed",
    },
    "docs/fleet-design-v2/successors/SH040-cryostasis.toml": {
        "bytes": 24060,
        "sha256": "5b52208ecf64228a843dc792ff4614af3ff9109034de4bedb6ddb0b7918072d9",
    },
}

RESOURCE = "Sources/L337Core/Resources/Ships/SH040.toml"
PHYSICAL = "Sources/L337Core/Resources/OriginalFleetPhysical/SH040.json"
SHOWROOM = "Sources/L337Core/Resources/OriginalFleetShowroomModels/SH040.json"
ASSET = "docs/fleet-design-v2/successors/SH040-cryostasis.toml"
R3 = "docs/fleet-design-v2/successors/SH040-cryostasis-r3.toml"
ENGINEERING = "docs/fleet-design-v2/successors/SH040-cryostasis-engineering.json"


def authenticate(root: Path) -> dict:
    result = {}
    for name, pin in PINS.items():
        raw = (root / name).read_bytes()
        if len(raw) != pin["bytes"] or sha256(raw).hexdigest() != pin["sha256"]:
            raise ValueError("Changed exact current cryopod input: " + name)
        if name.endswith(".toml"):
            result[name] = tomllib.loads(raw.decode())
        elif name.endswith(".json"):
            result[name] = json.loads(raw)
        else:
            result[name] = raw.decode()
    return result


def area_moments(triangles: np.ndarray, density: np.ndarray) -> tuple:
    areas = (
        np.linalg.norm(np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0]), axis=1)
        / 2
    )
    if np.min(areas) <= 0 or not np.isfinite(triangles).all():
        raise ValueError("Nonfinite or degenerate current shell triangle")
    mass = areas * density
    sums = triangles.sum(axis=1)
    first = np.einsum("f,fi->i", mass / 3, sums)
    second = np.einsum("f,fi,fj->ij", mass / 12, sums, sums)
    second += np.einsum("f,fki,fkj->ij", mass / 12, triangles, triangles)
    weights = np.asarray([[2 / 3, 1 / 6, 1 / 6], [1 / 6, 2 / 3, 1 / 6], [1 / 6, 1 / 6, 2 / 3]])
    samples = np.einsum("pk,fki->fpi", weights, triangles)
    check = np.einsum("f,fpi,fpj->ij", mass / 3, samples, samples)
    if not np.allclose(second, check, rtol=1e-12, atol=1e-10):
        raise ValueError("Independent exact triangle quadrature differs")
    return areas, float(mass.sum()), first, second


def point_certificate(point: np.ndarray, triangles: np.ndarray) -> tuple[float, float]:
    vectors = triangles - point
    lengths = np.linalg.norm(vectors, axis=2)
    numerator = np.einsum("ij,ij->i", vectors[:, 0], np.cross(vectors[:, 1], vectors[:, 2]))
    denominator = np.prod(lengths, axis=1)
    denominator += np.einsum("ij,ij->i", vectors[:, 0], vectors[:, 1]) * lengths[:, 2]
    denominator += np.einsum("ij,ij->i", vectors[:, 1], vectors[:, 2]) * lengths[:, 0]
    denominator += np.einsum("ij,ij->i", vectors[:, 2], vectors[:, 0]) * lengths[:, 1]
    winding = float(np.sum(2 * np.arctan2(numerator, denominator)) / (4 * np.pi))
    a, b, c = triangles.transpose(1, 0, 2)
    ab, ac = b - a, c - a
    normal = np.cross(ab, ac)
    normal /= np.linalg.norm(normal, axis=1)[:, None]
    signed = np.einsum("ij,ij->i", point - a, normal)
    projection = point - signed[:, None] * normal - a
    aa, bb, cc = np.einsum("ij,ij->i", ab, ab), np.einsum("ij,ij->i", ab, ac), np.einsum("ij,ij->i", ac, ac)
    x, y = np.einsum("ij,ij->i", projection, ab), np.einsum("ij,ij->i", projection, ac)
    determinant = aa * cc - bb * bb
    u, v = (cc * x - bb * y) / determinant, (aa * y - bb * x) / determinant
    distances = np.where((u >= 0) & (v >= 0) & (u + v <= 1), np.abs(signed), np.inf)
    for start, end in ((a, b), (b, c), (c, a)):
        edge = end - start
        t = np.clip(np.einsum("ij,ij->i", point - start, edge) / np.einsum("ij,ij->i", edge, edge), 0, 1)
        distances = np.minimum(distances, np.linalg.norm(point - start - t[:, None] * edge, axis=1))
    return winding, float(distances.min())


def triangle_box_contact(triangle: np.ndarray, centre: np.ndarray, half: np.ndarray) -> bool:
    local = triangle - centre
    edges = np.roll(local, -1, axis=0) - local
    axes = list(np.eye(3)) + [np.cross(edges[0], edges[1])]
    axes += [np.cross(edge, axis) for edge in edges for axis in np.eye(3)]
    for axis in axes:
        length = np.linalg.norm(axis)
        if length <= 1e-12:
            continue
        direction = axis / length
        projection = local @ direction
        radius = float(half @ np.abs(direction))
        if projection.min() > radius + 1e-10 or projection.max() < -radius - 1e-10:
            return False
    return True


def audit(root: Path) -> dict:
    data = authenticate(root)
    ship, asset, physical, engineering, r3, model = (
        data[n] for n in (RESOURCE, ASSET, PHYSICAL, ENGINEERING, R3, SHOWROOM)
    )
    native, display = asset["nativeDesign"], asset["design"]
    if (
        ship["id"] != "SH040"
        or physical["id"] != "SH040"
        or r3["id"] != "SH040"
        or ship["catalogue"]["objectKind"] != "capsule"
        or ship["catalogue"]["origin"] != "human"
        or ship["nativeDesign"] != native
        or ship["design"] != display
        or model["nativeDesign"] != native
        or model["sourceSHA256"] != PINS[ASSET]["sha256"]
        or physical["detailedSourceSHA256"] != PINS[ASSET]["sha256"]
        or physical["componentSourceSHA256"] != PINS[ENGINEERING]["sha256"]
        or physical["contractSHA256"] != PINS[R3]["sha256"]
        or physical["roleMapSHA256"] != PINS[ENGINEERING]["sha256"]
    ):
        raise ValueError("Current capsule source/display/native/empty-budget joins differ")
    if (
        len(native["vertices"]) != 48
        or len(native["faces"]) != 92
        or len(display["vertices"]) != 256
        or len(display["faces"]) != 415
        or sum(len(f) - 2 for f in display["faces"]) != 416
        or display["vertices"][:48] != native["vertices"]
        or display["faces"][38] != [14, 15, 27, 26]
        or display["faceMaterials"][38] != 3
        or display["materials"][3]["opticalOpacity"] != 0.25
        or any("opticalOpacity" in m for m in native["materials"])
        or [i for i, m in enumerate(display["faceMaterials"]) if "opticalOpacity" in display["materials"][m]]
        != [38]
    ):
        raise ValueError("Current hull-only collision or one-pane decorative display changed")
    absence = engineering["absence"]
    if (
        absence["dryOccupants"] != 0
        or absence["decorativePersonMassKg"] != 0
        or physical["decorativePersonMassKg"] != 0
        or absence["cargoKg"] != 0
        or absence["hyperspaceFuelKg"] != 0
        or absence["weapons"]
        or absence["paidFittings"]
    ):
        raise ValueError("The current empty budget cannot acquire decorative occupants, loads or fittings")
    calibration = Fraction(physical["metresPerSourceUnitExact"])
    if calibration != Fraction(60, 19) or physical["metresPerSourceUnit"] != float(calibration):
        raise ValueError("Current exact cryopod calibration changed")
    vertices = np.asarray(native["vertices"]) * float(calibration)
    faces = np.asarray(native["faces"])
    if faces.shape != (92, 3) or np.any(faces < 0) or np.any(faces >= 48):
        raise ValueError("Collision uses missing or decorative vertices")
    triangles = vertices[faces]
    edges = Counter((int(a), int(b)) for f in faces for a, b in zip(f, np.roll(f, -1)))
    normals = np.cross(triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0])
    lengths = np.linalg.norm(normals, axis=1)
    volume = float(np.einsum("ij,ij->", triangles[:, 0], normals)) / 6
    if (
        any(n != 1 or edges[b, a] != 1 for (a, b), n in edges.items())
        or np.min(lengths) <= 1e-10
        or volume <= 0
    ):
        raise ValueError("The current closed shell is invalid")
    normals /= lengths[:, None]
    signed = np.einsum("fvi,fi->fv", vertices[None, :, :] - triangles[:, 0, None, :], normals)
    convex_certificate = bool(signed.max() <= 1e-10)
    dimensions = np.ptp(vertices, axis=0)
    if not np.allclose(dimensions, [108 / 95, 183 / 190, 12 / 5], rtol=0, atol=1e-12):
        raise ValueError("Human person-sized cylinder envelope changed or was rescaled twice")
    density = np.zeros(92)
    for component in engineering["stockComponents"]:
        for owned in component["faceRanges"]:
            start, count = owned["start"], owned["count"]
            if np.any(density[start : start + count] != 0):
                raise ValueError("Stock ownership overlaps")
            density[start : start + count] = component["stockKgPerSquareMetre"]
    if np.any(density <= 0):
        raise ValueError("A pressure/lid stock surface is omitted")
    areas, stock, first, second = area_moments(triangles, density)
    hardware_rows = []
    hardware_mass = 0.0
    boxes = []
    for component, record in zip(
        engineering["intrinsicHardware"], physical["intrinsicHardware"], strict=True
    ):
        centre = np.asarray(component["centreSource"]) * float(calibration)
        half = np.asarray(component.get("halfExtentsSource", [0.0, 0, 0])) * float(calibration)
        mass = component["massKg"]
        if (
            component["id"] != record["id"]
            or mass != record["massKg"]
            or not np.allclose(centre, record["centreMetres"], rtol=0, atol=1e-12)
            or not np.allclose(half, record["halfExtentsMetres"], rtol=0, atol=1e-12)
        ):
            raise ValueError("Own fixed hardware placement/mass differs")
        corners = (
            np.asarray(
                [
                    centre + half * np.asarray([sx, sy, sz])
                    for sx in (-1, 1)
                    for sy in (-1, 1)
                    for sz in (-1, 1)
                ]
            )
            if np.any(half)
            else centre[None, :]
        )
        samples = np.concatenate([centre[None, :], corners]) if np.any(half) else corners
        certificates = [point_certificate(point, triangles) for point in samples]
        if any(abs(winding - 1) > 1e-8 or distance <= 1e-10 for winding, distance in certificates):
            raise ValueError("Declared current hardware samples leave or touch the closed shell")
        crossing = [
            i
            for i, triangle in enumerate(triangles)
            if np.any(half) and triangle_box_contact(triangle, centre, half)
        ]
        if crossing:
            raise ValueError("The shell crosses a declared current finite hardware box: " + repr(crossing))
        margin = min(distance for _, distance in certificates)
        if np.any(half):
            boxes.append((component["id"], centre, half))
        hardware_rows.append(
            dict(
                id=component["id"],
                massKg=mass,
                bound=record["bounds"],
                minimumSampleDistanceToClosedShellMetres=margin,
                wholeFiniteBoundInsideByWindingAndNoShellTriangleContact=bool(np.any(half)),
                centreOnlyHasNoVolumeQualification=not np.any(half),
            )
        )
        hardware_mass += mass
        first += mass * centre
        second += mass * np.outer(centre, centre)
    overlaps = []
    for i, (name, centre, half) in enumerate(boxes):
        for other, c, h in boxes[i + 1 :]:
            penetration = half + h - np.abs(centre - c)
            if np.all(penetration > 1e-10):
                overlaps.append([name, other])
    if overlaps:
        raise ValueError("Declared finite hardware boxes overlap: " + repr(overlaps))
    unrounded = stock + hardware_mass
    dry = math.ceil(unrounded)
    centre = first / unrounded
    reserve = dry - unrounded
    origin_inertia = np.trace(second) * np.eye(3) - second
    central_second = second - unrounded * np.outer(centre, centre)
    inertia = np.trace(central_second) * np.eye(3) - central_second
    if (
        dry != 248
        or abs(stock - physical["stockMassKg"]) > 1e-9
        or hardware_mass != 120
        or abs(unrounded - physical["unroundedMassKg"]) > 1e-9
        or abs(reserve - physical["roundingReserveKg"]) > 1e-9
        or not np.allclose(centre, physical["centreOfMassMetres"], rtol=0, atol=1e-10)
        or not np.allclose(inertia.reshape(-1), physical["inertiaAboutCentreOfMassKgM2"], rtol=0, atol=1e-8)
        or not np.allclose(
            origin_inertia.reshape(-1), physical["sourceOriginInertiaBeforeReserveKgM2"], rtol=0, atol=1e-8
        )
        or np.linalg.eigvalsh(inertia).min() <= 0
    ):
        raise ValueError("Recomputed current dry stock/hardware/COM/full tensor differs")
    decorative = np.asarray(display["vertices"][48:]) * float(calibration)
    decorative_certificates = [point_certificate(point, triangles) for point in decorative]
    if any(abs(winding - 1) > 1e-8 and distance > 1e-10 for winding, distance in decorative_certificates):
        raise ValueError("A current decorative vertex is outside the closed shell")
    axis_contacts = []
    for axis in range(3):
        for sign in (-1, 1):
            origin = np.eye(3)[axis] * sign * 4
            direction = -np.eye(3)[axis] * sign
            a, b, c = triangles.transpose(1, 0, 2)
            ab, ac = b - a, c - a
            cross = np.cross(direction, ac)
            det = np.einsum("ij,ij->i", ab, cross)
            inv = np.divide(1, det, out=np.zeros_like(det), where=np.abs(det) > 1e-10)
            delta = origin - a
            u = np.einsum("ij,ij->i", delta, cross) * inv
            perp = np.cross(delta, ab)
            v = (perp @ direction) * inv
            depth = np.einsum("ij,ij->i", ac, perp) * inv
            valid = (
                (inv != 0) & (u >= -1e-9) & (v >= -1e-9) & (u + v <= 1 + 1e-9) & (depth > 1e-8) & (depth <= 8)
            )
            indices = np.flatnonzero(valid)
            if not len(indices):
                raise ValueError("A bounded principal ray misses the current closed pressure shell")
            face = int(indices[np.argmin(depth[indices])])
            axis_contacts.append(
                dict(
                    axis=axis,
                    sign=sign,
                    originMetres=origin.tolist(),
                    direction=direction.tolist(),
                    firstFace=face,
                    distanceMetres=float(depth[face]),
                )
            )
    return dict(
        status="CURRENT_SNAPSHOT_SOURCE_EMPTY_BUDGET_AUDIT_NOT_OCCUPIED_ADMISSION",
        id="SH040",
        inputPins=PINS,
        currentHumanRedesignProtected=True,
        sourceAssetChangeNeeded=False,
        topology=dict(
            collisionVertices=48,
            collisionTriangles=92,
            displayVertices=256,
            displayFaces=415,
            displayFanTriangles=416,
            closedPositiveShell=True,
            convexHalfspaceCertificateAvailable=convex_certificate,
            signedVolumeCubicMetres=volume,
            decorativeInteriorExcludedFromCollision=True,
            oneTransparentFace=38,
            opacity=0.25,
        ),
        principalClosedShellContacts=axis_contacts,
        calibration="60/19",
        dimensionsWHLMetres=dimensions.tolist(),
        bareClosedShellRadiusMetres=float(np.linalg.norm(vertices, axis=1).max()),
        emptyBudget=dict(
            stockMassKg=stock,
            fixedHardwareMassKg=hardware_mass,
            unroundedMassKg=unrounded,
            dryMassKilograms=dry,
            roundingReserveKg=reserve,
            centreOfMassMetres=centre.tolist(),
            centroidalInertiaKgM2=inertia.reshape(-1).tolist(),
            decorativePersonMassKg=0,
            realOccupiedPersonMassGranted=False,
        ),
        fixedHardware=hardware_rows,
        pairwiseFiniteHardwareBoxesDisjoint=True,
        decorativeVerticesInsideOrOnShell=True,
        decorativeInteriorVolumeIsNotActualOccupancyQualification=True,
        decorativeGeometryIsNotActualPersonEnvelope=True,
        qualificationBoundary=dict(
            rawMeshNilExpectedByPinnedTests=True,
            globalRuntimeUnblockGranted=False,
            dedicatedCurrentSourceExistsInPinnedSwift=True,
            expectedCanonicalCollisionSHA256FromPinnedTests="be0d091a6bbf5f1af265eae4b94381fe0f049b8c4593005378b45b791f1b7461",
            canonicalSwiftDigestExecutedByG4=False,
            runtimeFirstCauseAttribution="Root/MC1 report, not executed by G4; rawMesh nil precedes downstream gates",
            occupiedMassAndCustodyMustUseActualPerson=True,
            lifeSupportDurationPowerActuatedLidEscapeClearanceGranted=False,
            ordinaryShipCrewFitOrNaturalRolesGranted=False,
        ),
        nativeCompilerRendererGame="UNRUN_BY_G4",
        acceptedHullIncrement=0,
    )


def main(root: Path) -> None:
    report = audit(root)
    with (root / "SH040-current-admission-source-audit.json").open("x") as stream:
        json.dump(report, stream, sort_keys=True, indent=2, allow_nan=False)
        stream.write("\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    main(parser.parse_args().directory)
