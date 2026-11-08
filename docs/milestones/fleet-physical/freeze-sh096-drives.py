"""Remove inward drive facets without changing Wisent source vertices or budget."""

import argparse
from fractions import Fraction
from hashlib import sha256
from pathlib import Path
import runpy

import numpy as np


PINS = {
    "SH096": {
        "candidate.json": "dd216fb3898a7e1eb508edd27c37dcba9d86de987d062629cdb094576f10ae0b",
        "reference.json": "16452ff84cbd0de559dd372fc479c6a9ec91de8ef803b3c17b6aae70025e25ee",
        "criteria.json": "ad373622680378031bb644b1a7b6dff85979ceb37bb79d6cf62e98f730cc0441",
        "witness.json": "e820d9edafe80b3d8131bd8bd22cd49b63886d6e56c5c13855a60715f926ccec",
        "source.toml": "3ed7051c06c65f78d7f58e7fdfc875b61aa54c616d8907aa9e37cf470ec69072",
        "SH096.json": "0d601ef336eb83046e5823ae43c70c78fa9197b19513a608549f8d046302390e",
        "SH096.toml": "c688f7050eb12abb2a2eb5f1351cb260d04d0e767ca63d58ca47b1831b92c2f7"
    },
    "SH097": {
        "candidate.json": "4b3ea04966b5dabbf2f6d6a439594bca4b499804f6e4dee5e8dbe403564a4527",
        "reference.json": "6bf8e743d1e7ae1b0a7758606c8883bc7f85b437c234a6d8a270ea494268acdf",
        "criteria.json": "8ffa220192ca8cce320e8cb7f74de373a69315ccae9aeb644cf1f2499448610a",
        "witness.json": "d5dfccfd0d5b21d6907d957824894f29e912c40e3433da41a8c3e071a379169f",
        "source.toml": "c5bff7a81f87ad4b6ad0a05ba8e689fc1114f1812e6e85461b09a4c15aac2b0a",
        "SH097.json": "7e9c862d8cd1da17b3c3244ee93350a5aeea701bf7a0374223a3d63e1520d024",
        "SH097.toml": "6275b430223584d94ca9d151669acc1d16cad5fd7c9e29065fdfa256daa78536"
    }
}
PATCHES = {'SH096': {21: {5: ([1, 2, 6], [1, 7, 6]), 6: ([2, 7, 6], [7, 1, 2])},
           22: {7: ([1, 2, 8], [1, 9, 8]),
                8: ([2, 9, 8], [9, 1, 2]),
                10: ([3, 4, 9], [3, 10, 9]),
                11: ([4, 10, 9], [10, 3, 4]),
                13: ([5, 6, 10], [5, 11, 10]),
                14: ([6, 11, 10], [11, 5, 6]),
                16: ([7, 0, 11], [7, 8, 11]),
                17: ([0, 8, 11], [8, 7, 0])},
           24: {12: ([5, 0, 9], [5, 6, 9]), 13: ([0, 6, 9], [6, 5, 0])},
           25: {7: ([1, 2, 8], [1, 9, 8]),
                8: ([2, 9, 8], [9, 1, 2]),
                10: ([3, 4, 9], [3, 10, 9]),
                11: ([4, 10, 9], [10, 3, 4]),
                16: ([7, 0, 11], [7, 8, 11]),
                17: ([0, 8, 11], [8, 7, 0])}},
 'SH097': {21: {5: ([1, 2, 6], [1, 7, 6]), 6: ([2, 7, 6], [7, 1, 2])},
           22: {7: ([1, 2, 8], [1, 9, 8]),
                8: ([2, 9, 8], [9, 1, 2]),
                10: ([3, 4, 9], [3, 10, 9]),
                11: ([4, 10, 9], [10, 3, 4]),
                13: ([5, 6, 10], [5, 11, 10]),
                14: ([6, 11, 10], [11, 5, 6]),
                16: ([7, 0, 11], [7, 8, 11]),
                17: ([0, 8, 11], [8, 7, 0])},
           24: {12: ([5, 0, 9], [5, 6, 9]), 13: ([0, 6, 9], [6, 5, 0])},
           25: {7: ([1, 2, 8], [1, 9, 8]),
                8: ([2, 9, 8], [9, 1, 2]),
                10: ([3, 4, 9], [3, 10, 9]),
                11: ([4, 10, 9], [10, 3, 4]),
                16: ([7, 0, 11], [7, 8, 11]),
                17: ([0, 8, 11], [8, 7, 0])}}}
HERE = Path(__file__).resolve().parent


def plane_distances(points, faces, queries):
    a, b, c = points[np.asarray(faces)].transpose(1, 0, 2)
    normals = np.cross(b - a, c - a)
    normals /= np.linalg.norm(normals, axis=1)[:, None]
    return np.einsum("ftj,fj->ft", queries[None, :, :] - a[:, None, :], normals)


def drive_proof(original, before, after, part, source_part, scale):
    v, f = part["vertexStart"], part["faceStart"]
    sv, sf = source_part["vertexStart"], source_part["faceStart"]
    points = np.asarray(before["vertices"][v:v + part["vertexCount"]])
    source_points = np.asarray(original["vertices"][sv:sv + source_part["vertexCount"]])
    if not set(map(tuple, points)) <= set(map(tuple, source_points)):
        raise ValueError("A drive vertex is not an exact original source sample")
    old_faces = [[i - v for i in face] for face in before["faces"][f:f + part["faceCount"]]]
    faces = [[i - v for i in face] for face in after["faces"][f:f + part["faceCount"]]]
    source_faces = [[i - sv for i in face] for face in original["faces"][sf:sf + source_part["faceCount"]]]
    points, source_points = points * scale, source_points * scale
    old_distances = plane_distances(points, old_faces, points)
    current_distances = plane_distances(points, faces, points)
    source_distances = plane_distances(source_points, source_faces, source_points)
    supported = source_distances.max(axis=1) <= 1e-8
    source_query = plane_distances(source_points, source_faces, points)
    old_bad = int((old_distances.max(axis=1) > 1e-8).sum())
    current_bad = int((current_distances.max(axis=1) > 1e-8).sum())
    if (current_bad >= old_bad or current_distances.max() > old_distances.max() + 1e-8
            or source_query[supported].max() > 1e-8):
        raise ValueError("Partial convexity improvement or supporting source-plane containment failed")
    return dict(part=part["index"], sourceVertexSubset=True,
                priorNonSupportingFacets=old_bad, currentNonSupportingFacets=current_bad,
                priorMaxVertexPlaneDeviationMetres=float(old_distances.max()),
                currentMaxVertexPlaneDeviationMetres=float(current_distances.max()),
                sourceSupportingFacets=int(supported.sum()),
                sourceNonSupportingFacets=int((~supported).sum()),
                sourceMaxVertexPlaneDeviationMetres=float(source_distances.max()),
                maxOutsideSupportingSourcePlanesMetres=float(source_query[supported].max()))


def retained_contacts(witness, triangles, owners, scale, ray_hit):
    by_name = {ray["name"]: ray for ray in witness["rays"]}
    cases = [(ray, ray["hits"], True) for ray in witness["rays"]]
    cases += [(by_name[ray["name"]], ray["hits"], False) for ray in witness["isolated"]]
    results = []
    for ray, expected, assembled in cases:
        before, source = expected["candidate"], expected["reference"]
        indices = np.arange(len(triangles)) if assembled else np.flatnonzero(owners == before["part"])
        hit = ray_hit(triangles[indices], np.asarray(ray["origin"]) * scale,
                      np.asarray(ray["direction"]), ray["limit"] * scale)
        after = None if hit is None else hit[1]
        after_part = None if hit is None else int(owners[indices[hit[0]]])
        if before is None:
            if hit is not None:
                raise ValueError("A retained clear path acquired a contact")
        elif (hit is None or after_part != before["part"]
              or abs(after - before["distance"] * scale) > 1e-8):
            raise ValueError(f"Changed retained part or depth at {ray['name']}")
        results.append(dict(name=ray["name"], assembled=assembled,
                            originMetres=(np.asarray(ray["origin"]) * scale).tolist(),
                            direction=ray["direction"],
                            parts=[None if source is None else source["part"],
                                   None if before is None else before["part"], after_part],
                            depthsMetres=[None if source is None else source["distance"] * scale,
                                          None if before is None else before["distance"] * scale, after]))
    if len(results) != 75:
        raise ValueError("Expected all 75 retained contact obligations")
    return results


def side_probes(original, before, after, source_parts, parts, scale, ray_hit, no_regression):
    meshes = (original, before, after)
    all_points = np.concatenate([np.asarray(mesh["vertices"]) for mesh in meshes])
    triangles = [(np.asarray(mesh["vertices"]) * scale)[mesh["faces"]] for mesh in meshes]
    full_owners = [np.repeat([p["index"] for p in ranges], [p["faceCount"] for p in ranges])
                   for ranges in (source_parts, parts, parts)]
    results = []
    for index in (21, 22, 24, 25):
        part, source_part = parts[index], source_parts[index]
        start = source_part["vertexStart"]
        rings = np.asarray(original["vertices"][start:start + 24]).reshape(2, 12, 3)
        cases = []
        for fraction in (.05, .125, .25, .375, .5, .625, .75, .875, .95):
            center = ((1 - fraction) * rings[0] + fraction * rings[1]).mean(axis=0)
            distance = np.linalg.norm(all_points[:, :2] - center[:2], axis=1).max() + .1
            for degrees in range(0, 360, 15):
                angle = np.deg2rad(degrees)
                direction = -np.array([np.cos(angle), np.sin(angle), 0])
                cases.append(dict(kind="radial", fraction=fraction, degrees=degrees,
                                  origin=center - distance * direction, direction=direction, limit=2 * distance))
        for face_index in range(part["faceStart"], part["faceStart"] + part["faceCount"]):
            if before["faces"][face_index] == after["faces"][face_index]:
                continue
            triangle = np.asarray(after["vertices"])[after["faces"][face_index]]
            center = triangle.mean(axis=0)
            normal = np.cross(triangle[1] - triangle[0], triangle[2] - triangle[0])
            normal /= np.linalg.norm(normal)
            distance = np.linalg.norm(all_points - center, axis=1).max() + .1
            cases.append(dict(kind="face-centroid", face=face_index,
                              origin=center + distance * normal, direction=-normal, limit=2 * distance))
        for case in cases:
            for assembled in (False, True):
                hits = []
                for mesh, owners, scope in zip(triangles, full_owners, (source_part, part, part), strict=True):
                    indices = (np.arange(len(mesh)) if assembled else
                               np.arange(scope["faceStart"], scope["faceStart"] + scope["faceCount"]))
                    hit = ray_hit(mesh[indices], case["origin"] * scale, case["direction"], case["limit"] * scale)
                    hits.append((None, None) if hit is None else (int(owners[indices[hit[0]]]), hit[1]))
                depths = [hit[1] for hit in hits]
                if hits[2][0] not in (hits[0][0], hits[1][0]):
                    raise ValueError("A side probe changed away from both prior and source ownership")
                if not no_regression(depths):
                    raise ValueError(f"A {case['kind']} source-depth probe regressed on drive {index}")
                results.append(dict(part=index, kind=case["kind"], assembled=assembled,
                                    fraction=case.get("fraction"), degrees=case.get("degrees"), face=case.get("face"),
                                    originMetres=(case["origin"] * scale).tolist(),
                                    direction=case["direction"].tolist(), limitMetres=case["limit"] * scale,
                                    parts=[hit[0] for hit in hits], depthsMetres=depths))
    return results


def main(root, ship):
    helper = runpy.run_path(str(HERE / "freeze-sh071-profiles.py"))
    verify = runpy.run_path(str(HERE / "freeze-sh169-crest.py"))
    no_regression = runpy.run_path(str(HERE / "freeze-sh128-rim.py"))["no_depth_regression"]
    chart = runpy.run_path(str(HERE.parents[2] / "Tools/authoring/sh023_native_topology.py"))["uv_for_face"]
    pins = PINS[ship]
    records = {name: helper["load"](root, name, digest) for name, digest in pins.items()}
    baseline, reference, physical = records["candidate.json"], records["reference.json"], records[f"{ship}.json"]
    source, packaged = records["source.toml"], records[f"{ship}.toml"]
    original, old = reference["nativeDesign"], baseline["nativeDesign"]
    if (baseline["id"], reference["id"], physical["id"], source["proposal"]["id"], packaged["id"]) != (ship,) * 5:
        raise ValueError("Expected this Wisent's original source inputs")
    if (source["design"] != packaged["design"] or source["nativeDesign"] != original
            or baseline["originalSourceSHA256"] != pins["source.toml"]
            or physical["detailedSourceSHA256"] != pins["source.toml"]):
        raise ValueError("Source, renderer and physical calibration differ")
    for key in ("appearanceLicense", "appearanceSource", "materials", "textures", "paletteName"):
        if old[key] != original[key]:
            raise ValueError(f"Changed source appearance metadata {key}")
    scale = float(Fraction(physical["metresPerSourceUnitExact"]))
    faces, textures = list(old["faces"]), list(old["faceTextures"])
    for part_index, patch in PATCHES[ship].items():
        part = baseline["parts"][part_index]
        for offset, (before, after) in patch.items():
            index = part["faceStart"] + offset
            if [i - part["vertexStart"] for i in faces[index]] != before:
                raise ValueError("Unexpected source drive patch topology")
            faces[index] = [part["vertexStart"] + i for i in after]
            textures[index] = chart([old["vertices"][i] for i in faces[index]], old["faceMaterials"][index])
    mesh = {**old, "faces": faces, "faceTextures": textures}
    vertices = np.asarray(old["vertices"]) * scale
    triangles = vertices[faces]
    if len(triangles) != 512 or len(baseline["parts"]) != 26:
        raise ValueError("Expected the complete 512-triangle Wisent")
    owners = verify["verify_parts"](faces, triangles, baseline["parts"])
    source_parts = records["criteria.json"]["parts"]["originalPartRanges"]
    proofs = [drive_proof(original, old, mesh, baseline["parts"][index], source_parts[index], scale)
              for index in (21, 22, 24, 25)]
    contacts = retained_contacts(records["witness.json"], triangles, owners, scale, verify["RAY_HIT"])
    probes = side_probes(original, old, mesh, source_parts, baseline["parts"], scale, verify["RAY_HIT"], no_regression)
    helper["emit"](root, f"{ship}-collision-candidate.json", dict(
        schemaVersion=1, status="SOURCE_GEOMETRY_ONLY", catalogueID=ship, coordinateUnits="metres",
        forwardAxis="+Z", upAxis="+Y", calibration=physical["metresPerSourceUnitExact"],
        originalSourceSHA256=pins["source.toml"], parts=baseline["parts"],
        nativeDesign={**mesh, "vertices": vertices.tolist()}))
    helper["emit"](root, f"{ship}-drive-witness.json", dict(
        inputSHA256=pins, convexity=proofs, retainedContacts=contacts, sideProbes=probes,
        collisionSHA256=sha256((root / f"{ship}-collision-candidate.json").read_bytes()).hexdigest()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--ship", choices=tuple(PINS), default="SH096")
    args = parser.parse_args()
    main(args.directory, args.ship)
