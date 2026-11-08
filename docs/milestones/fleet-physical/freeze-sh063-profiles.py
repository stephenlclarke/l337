"""Refine Seriema profiles while retaining exposed caps and authored rail clearance."""

import argparse
from fractions import Fraction
from hashlib import sha256
from pathlib import Path
import runpy

import numpy as np


PINS = {'SH063': {'candidate.json': 'daf9326c6b2ebc0f09e134f3a8ababc5a8c2442e5189b87897eed789f719ad9e',
           'reference.json': '5965142a4526b4db6eaff87acdb62ecc83082e9f6eea34be99a5745bae546a12',
           'criteria.json': '108153a6bc689ae0e0cf49452a05c677fc995f49eb933c4f28728cbbddb560f8',
           'witness.json': 'f7866428e138643c4f91d41a6f4f72994061a95f45f307ffab7c667d55d81581',
           'physical.json': 'eba997ff8fcb3cca2040d7237778fe29e19553383aee330c0155e2f5e44806dd',
           'source.toml': '557e9ad9e2a496ee0f29ae34b5db40a05ceddd7e8f8ed5ddf9a7ee0b78edc722',
           'resource.toml': '296b86cff9f25fbe83e60f6efaddb2b3f59474d7d9ff53df83eb054bc1ea0efa',
           'prior-candidate.json': '741705250d6d69d4cd5094baed01624a5425b45bf959339ffb8039f5e3eeaf79',
           'prior-witness.json': 'de78de361b20743b0503053b4d214574c4fa3ac858047ad94019fc181d3a3545'}}
FULL_PATCHES = {0: {26: ([10, 11, 19], [11, 18, 10]),
     27: ([10, 19, 18], [18, 11, 19]),
     34: ([14, 15, 23], [15, 22, 14]),
     35: ([14, 23, 22], [22, 15, 23]),
     28: ([11, 12, 20], [12, 19, 11]),
     29: ([11, 20, 19], [19, 12, 20]),
     36: ([15, 8, 16], [8, 23, 15]),
     37: ([15, 16, 23], [23, 8, 16]),
     44: ([19, 20, 28], [20, 27, 19]),
     45: ([19, 28, 27], [27, 20, 28]),
     52: ([23, 16, 24], [16, 31, 23]),
     53: ([23, 24, 31], [31, 16, 24]),
     42: ([18, 19, 27], [19, 26, 18]),
     43: ([18, 27, 26], [26, 19, 27]),
     50: ([22, 23, 31], [23, 30, 22]),
     51: ([22, 31, 30], [30, 23, 31]),
     58: ([26, 27, 35], [27, 34, 26]),
     59: ([26, 35, 34], [34, 27, 35]),
     66: ([30, 31, 39], [31, 38, 30]),
     67: ([30, 39, 38], [38, 31, 39]),
     60: ([27, 28, 36], [28, 35, 27]),
     61: ([27, 36, 35], [35, 28, 36]),
     68: ([31, 24, 32], [24, 39, 31]),
     69: ([31, 32, 39], [39, 24, 32]),
     8: ([1, 2, 10], [2, 9, 1]),
     9: ([1, 10, 9], [9, 2, 10]),
     12: ([3, 4, 12], [4, 11, 3]),
     13: ([3, 12, 11], [11, 4, 12]),
     16: ([5, 6, 14], [6, 13, 5]),
     17: ([5, 14, 13], [13, 6, 14]),
     20: ([7, 0, 8], [0, 15, 7]),
     21: ([7, 8, 15], [15, 0, 8])},
 6: {26: ([10, 11, 19], [11, 18, 10]),
     27: ([10, 19, 18], [18, 11, 19]),
     34: ([14, 15, 23], [15, 22, 14]),
     35: ([14, 23, 22], [22, 15, 23]),
     36: ([15, 8, 16], [8, 23, 15]),
     37: ([15, 16, 23], [23, 8, 16]),
     28: ([11, 12, 20], [12, 19, 11]),
     29: ([11, 20, 19], [19, 12, 20]),
     52: ([23, 16, 24], [16, 31, 23]),
     53: ([23, 24, 31], [31, 16, 24]),
     44: ([19, 20, 28], [20, 27, 19]),
     45: ([19, 28, 27], [27, 20, 28]),
     42: ([18, 19, 27], [19, 26, 18]),
     43: ([18, 27, 26], [26, 19, 27]),
     50: ([22, 23, 31], [23, 30, 22]),
     51: ([22, 31, 30], [30, 23, 31]),
     60: ([27, 28, 36], [28, 35, 27]),
     61: ([27, 36, 35], [35, 28, 36]),
     68: ([31, 24, 32], [24, 39, 31]),
     69: ([31, 32, 39], [39, 24, 32]),
     58: ([26, 27, 35], [27, 34, 26]),
     59: ([26, 35, 34], [34, 27, 35]),
     66: ([30, 31, 39], [31, 38, 30]),
     67: ([30, 39, 38], [38, 31, 39]),
     16: ([5, 6, 14], [6, 13, 5]),
     17: ([5, 14, 13], [13, 6, 14]),
     8: ([1, 2, 10], [2, 9, 1]),
     9: ([1, 10, 9], [9, 2, 10]),
     6: ([0, 1, 9], [1, 8, 0]),
     7: ([0, 9, 8], [8, 1, 9]),
     14: ([4, 5, 13], [5, 12, 4]),
     15: ([4, 13, 12], [12, 5, 13])}}
SELECTED_FACES = {0: [8, 9, 12, 13, 16, 17, 20, 21, 26, 27, 28, 29, 34, 35, 36, 37, 42, 43, 52, 53, 60, 61, 68, 69],
 6: [6, 7, 8, 9, 14, 15, 16, 17, 26, 27, 28, 29, 34, 35, 36, 37, 44, 45, 52, 53, 60, 61, 68, 69]}
HERE = Path(__file__).resolve().parent


def same_geometry(before, after, part):
    v, n, f, count = part["vertexStart"], part["vertexCount"], part["faceStart"], part["faceCount"]
    return (before["vertices"][v:v + n] == after["vertices"][v:v + n]
            and all(before[key][f:f + count] == after[key][f:f + count]
                    for key in ("faces", "faceMaterials", "faceTextures")))


def hit_result(triangles, owners, indices, origin, direction, limit, ray_hit):
    hit = ray_hit(triangles[indices], origin, direction, limit)
    return (None, None) if hit is None else (int(owners[indices[hit[0]]]), hit[1])


def profile_cases(original, before, after, parts, source_parts, all_points):
    cases = []
    for index in (0, 6):
        part = source_parts[index]
        start = part["vertexStart"]
        points = np.asarray(original["vertices"][start:start + part["vertexCount"]])
        sections = [points[points[:, 2] == z] for z in np.unique(points[:, 2])]
        if len(sections) != 5 or any(len(section) != 12 for section in sections):
            raise ValueError("Unexpected original profile station layout")
        stations = sections + [(a + b) / 2 for a, b in zip(sections[:-1], sections[1:], strict=True)]
        for station, section in enumerate(stations):
            center = section.mean(axis=0)
            samples = list(section) + list((section + np.roll(section, -1, axis=0)) / 2)
            distance = np.linalg.norm(all_points[:, :2] - center[:2], axis=1).max() + .1
            for sample_index, sample in enumerate(samples):
                direction = sample - center
                direction[2] = 0
                direction /= np.linalg.norm(direction)
                cases.append(dict(part=index, kind="profile-radial", station=station, sample=sample_index,
                                  origin=center + distance * direction, direction=-direction, limit=2 * distance))
    for part in parts:
        start, count = part["faceStart"], part["faceCount"]
        for face_index in range(start, start + count):
            if before["faces"][face_index] == after["faces"][face_index]:
                continue
            triangle = np.asarray(after["vertices"])[after["faces"][face_index]]
            center = triangle.mean(axis=0)
            normal = np.cross(triangle[1] - triangle[0], triangle[2] - triangle[0])
            normal /= np.linalg.norm(normal)
            distance = np.linalg.norm(all_points - center, axis=1).max() + .1
            cases.append(dict(part=part["index"], kind="facet-centroid", face=face_index,
                              origin=center + distance * normal, direction=-normal, limit=2 * distance))
    return cases


def measure(original, before, after, parts, source_parts, prior, oldw, scale, ray_hit, criterion_mesh):
    before, after = before["nativeDesign"], after["nativeDesign"]
    meshes = (original, before, after)
    surfaces = [(np.asarray(mesh["vertices"]) * scale)[mesh["faces"]] for mesh in meshes]
    owners = [np.repeat([p["index"] for p in ranges], [p["faceCount"] for p in ranges])
              for ranges in (source_parts, parts, parts)]
    all_points = np.concatenate([np.asarray(mesh["vertices"]) for mesh in meshes])
    by_name = {ray["name"]: ray for ray in oldw["rays"]}
    records = []
    retained_cases = [(ray, ray["hits"], True) for ray in oldw["rays"]]
    retained_cases += [(by_name[ray["name"]], ray["hits"], False) for ray in oldw["isolated"]]
    for ray, expected, assembled in retained_cases:
        source_hit, current_hit = expected["reference"], expected["candidate"]
        prior_part = None if current_hit is None else current_hit["part"]
        prior_depth = None if current_hit is None else current_hit["distance"] * scale
        source_part = None if source_hit is None else source_hit["part"]
        source_depth = None if source_hit is None else source_hit["distance"] * scale
        unchanged = not assembled and same_geometry(before, after, parts[prior_part])
        if unchanged:
            hit = prior_part, prior_depth
        else:
            hit = hit_result(surfaces[2], owners[2], np.arange(512), np.asarray(ray["origin"]) * scale,
                             np.asarray(ray["direction"]), ray["limit"] * scale, ray_hit)
        records.append(dict(kind="retained", name=ray["name"], assembled=assembled,
                            originMetres=(np.asarray(ray["origin"]) * scale).tolist(), direction=ray["direction"],
                            limitMetres=ray["limit"] * scale, parts=[source_part, prior_part, hit[0]],
                            depthsMetres=[source_depth, prior_depth, hit[1]], geometryUnchanged=unchanged))
    for control in prior["driveProbes"]:
        hits = [hit_result(triangles, model_owners, np.arange(len(triangles)),
                           np.asarray(control["originMetres"]), np.asarray(control["direction"]), control["limitMetres"], ray_hit)
                for triangles, model_owners in zip(surfaces, owners, strict=True)]
        for actual, expected in zip((hits[0][1], hits[1][1]),
                                    (control["depthsMetres"][0], control["depthsMetres"][2]), strict=True):
            if ((actual is None) != (expected is None)
                    or actual is not None and abs(actual - expected) > 1e-8):
                raise ValueError("A pinned shoulder depth does not bind its reconstructed owner")
        records.append(dict(kind="prior-cap", assembled=True,
                            originMetres=control["originMetres"], direction=control["direction"], limitMetres=control["limitMetres"],
                            parts=[hit[0] for hit in hits], depthsMetres=[hit[1] for hit in hits],
                            geometryUnchanged=False))
    for case in profile_cases(original, before, criterion_mesh, parts, source_parts, all_points):
        for assembled in (False, True):
            hits = []
            for triangles, ranges, model_owners in zip(surfaces, (source_parts, parts, parts), owners, strict=True):
                part = ranges[case["part"]]
                indices = (np.arange(len(triangles)) if assembled else
                           np.arange(part["faceStart"], part["faceStart"] + part["faceCount"]))
                hits.append(hit_result(triangles, model_owners, indices, case["origin"] * scale,
                                       case["direction"], case["limit"] * scale, ray_hit))
            records.append(dict(part=case["part"], kind=case["kind"], station=case.get("station"),
                                sample=case.get("sample"), face=case.get("face"), assembled=assembled,
                                originMetres=(case["origin"] * scale).tolist(), direction=case["direction"].tolist(),
                                limitMetres=case["limit"] * scale, parts=[hit[0] for hit in hits],
                                depthsMetres=[hit[1] for hit in hits], geometryUnchanged=False))
    return records


def profile_proof(original, before, after, part, source_part, scale):
    distances = runpy.run_path(str(HERE / "freeze-sh096-drives.py"))["plane_distances"]
    v, f = part["vertexStart"], part["faceStart"]
    sv, sf = source_part["vertexStart"], source_part["faceStart"]
    points = np.asarray(before["vertices"][v:v + part["vertexCount"]])
    source_points = np.asarray(original["vertices"][sv:sv + source_part["vertexCount"]])
    exact = sum(tuple(point) in set(map(tuple, source_points)) for point in points)
    old_faces = [[i - v for i in face] for face in before["faces"][f:f + part["faceCount"]]]
    faces = [[i - v for i in face] for face in after["faces"][f:f + part["faceCount"]]]
    source_faces = [[i - sv for i in face] for face in original["faces"][sf:sf + source_part["faceCount"]]]
    points, source_points = points * scale, source_points * scale
    old_planes = distances(points, old_faces, points)
    current_planes = distances(points, faces, points)
    source_planes = distances(source_points, source_faces, source_points)
    supported = source_planes.max(axis=1) <= 1e-8
    query = distances(source_points, source_faces, points)
    if before["vertices"][v:v + part["vertexCount"]] != after["vertices"][v:v + part["vertexCount"]]:
        raise ValueError("A retained profile coordinate changed")
    return dict(part=part["index"], retainedVertexCount=len(points), exactSourceVertexCount=exact,
                sourceVertexSubset=exact == len(points),
                priorNonSupportingFacets=int((old_planes.max(axis=1) > 1e-8).sum()),
                currentNonSupportingFacets=int((current_planes.max(axis=1) > 1e-8).sum()),
                priorMaxVertexPlaneDeviationMetres=float(old_planes.max()),
                currentMaxVertexPlaneDeviationMetres=float(current_planes.max()),
                sourceSupportingFacets=int(supported.sum()),
                sourceNonSupportingFacets=int((~supported).sum()),
                sourceMaxVertexPlaneDeviationMetres=float(source_planes.max()),
                unchangedMaxOutsideSupportingSourcePlanesMetres=float(query[supported].max()))


def rail_checks(prior, triangles, owners, ray_hit):
    clearance = runpy.run_path(str(HERE / "naval-plans/measure-initial-pair-muzzles.py"))
    if clearance["CLEARANCE"] != .1 or len(prior["mounts"]) != 2:
        raise ValueError("The authored rail clearance contract changed")
    records = []
    for mount in prior["mounts"]:
        muzzle, backing = np.asarray(mount["muzzleMetres"]), np.asarray(mount["backingMetres"])
        if (mount["axis"] != [0, 0, 1] or mount["forwardClearanceLowerBoundMetres"] != .1
                or np.linalg.norm(muzzle - backing - np.array([0, 0, .2])) > 1e-8):
            raise ValueError("The authored rail frame changed")
        clearance["prove_clearance"](triangles, muzzle)
        hit = ray_hit(triangles, muzzle, np.array([0, 0, -1]), .3)
        if hit is None or owners[hit[0]] != mount["backingPart"] or abs(hit[1] - .2) > 1e-8:
            raise ValueError("A retained rail backing contact changed")
        records.append(dict(mount, measuredBackingPart=int(owners[hit[0]]), measuredBackingDepthMetres=hit[1]))
    return records

def main(root, ship):
    helper = runpy.run_path(str(HERE / "freeze-sh071-profiles.py"))
    verify = runpy.run_path(str(HERE / "freeze-sh169-crest.py"))
    no_regression = runpy.run_path(str(HERE / "freeze-sh128-rim.py"))["no_depth_regression"]
    plane_proof = profile_proof
    chart = runpy.run_path(str(HERE.parents[2] / "Tools/authoring/sh023_native_topology.py"))["uv_for_face"]
    pins = PINS[ship]
    inputs = {name: helper["load"](root, name, digest) for name, digest in pins.items()}
    initial, prior = inputs["candidate.json"], inputs["prior-candidate.json"]
    source, packaged, physical = inputs["source.toml"], inputs["resource.toml"], inputs["physical.json"]
    original = inputs["reference.json"]["nativeDesign"]
    original_pins = {name: digest for name, digest in pins.items() if not name.startswith("prior-")}
    if (initial["id"], prior["catalogueID"], physical["id"], source["proposal"]["id"], packaged["id"]) != (ship,) * 5:
        raise ValueError("Expected this Seriema's original and current source lineage")
    if (source["nativeDesign"] != original or source["design"] != packaged["design"]
            or initial["originalSourceSHA256"] != pins["source.toml"]
            or physical["detailedSourceSHA256"] != pins["source.toml"]
            or inputs["prior-witness.json"]["collisionSHA256"] != pins["prior-candidate.json"]
            or inputs["prior-witness.json"]["inputSHA256"] != original_pins
            or prior["calibration"] != physical["metresPerSourceUnitExact"]):
        raise ValueError("Original, renderer, current mesh and physical authority do not bind")
    scale = float(Fraction(physical["metresPerSourceUnitExact"]))
    source_points = initial["nativeDesign"]["vertices"] + original["vertices"]
    lookup = {tuple(np.asarray(point) * scale): point for point in source_points}
    source_vertices = [lookup[tuple(point)] for point in prior["nativeDesign"]["vertices"]]
    if not np.array_equal(np.asarray(source_vertices) * scale, np.asarray(prior["nativeDesign"]["vertices"])):
        raise ValueError("The exact current source frame cannot be reconstructed")
    before_mesh = {**prior["nativeDesign"], "vertices": source_vertices}
    for key in ("appearanceLicense", "appearanceSource", "materials", "textures", "paletteName"):
        if before_mesh[key] != original[key]:
            raise ValueError(f"Changed original appearance metadata {key}")
    faces, textures = list(before_mesh["faces"]), list(before_mesh["faceTextures"])
    for index, offsets in SELECTED_FACES.items():
        part = prior["parts"][index]
        for offset in offsets:
            old, new = FULL_PATCHES[index][offset]
            face_index = part["faceStart"] + offset
            if [i - part["vertexStart"] for i in faces[face_index]] != old:
                raise ValueError("Unexpected current profile patch topology")
            faces[face_index] = [i + part["vertexStart"] for i in new]
            textures[face_index] = chart([before_mesh["vertices"][i] for i in faces[face_index]],
                                         before_mesh["faceMaterials"][face_index])
    after_mesh = {**before_mesh, "faces": faces, "faceTextures": textures}
    before = {**initial, "nativeDesign": before_mesh}
    after = {**initial, "nativeDesign": after_mesh}
    vertices = np.asarray(before_mesh["vertices"]) * scale
    triangles = vertices[faces]
    if len(triangles) != 512 or len(prior["parts"]) != 20:
        raise ValueError("Expected the complete 512-triangle Seriema")
    owners = verify["verify_parts"](faces, triangles, prior["parts"])
    mounts = rail_checks(inputs["prior-witness.json"], triangles, owners, verify["RAY_HIT"])
    source_parts = inputs["criteria.json"]["parts"]["originalPartRanges"]
    proofs = [plane_proof(original, before_mesh, after_mesh, prior["parts"][i], source_parts[i], scale)
              for i in (0, 6)]
    if any(proof["currentNonSupportingFacets"] >= proof["priorNonSupportingFacets"]
           or proof["currentMaxVertexPlaneDeviationMetres"] > proof["priorMaxVertexPlaneDeviationMetres"] + 1e-8
           for proof in proofs):
        raise ValueError("The partial profile patch did not improve its own facet support")
    criterion_faces = list(before_mesh["faces"])
    for index, patch in FULL_PATCHES.items():
        part = prior["parts"][index]
        for offset, (old, new) in patch.items():
            face_index = part["faceStart"] + offset
            if [i - part["vertexStart"] for i in criterion_faces[face_index]] != old:
                raise ValueError("Unexpected full-trial criterion facet")
            criterion_faces[face_index] = [i + part["vertexStart"] for i in new]
    criterion_mesh = {**before_mesh, "faces": criterion_faces}
    records = measure(original, before, after, prior["parts"], source_parts,
                      inputs["prior-witness.json"], inputs["witness.json"], scale, verify["RAY_HIT"], criterion_mesh)
    for record in records:
        if (not no_regression(record["depthsMetres"])
                or record["parts"][2] not in (record["parts"][0], record["parts"][1])):
            raise ValueError("A profile or coupled control regressed in source depth or ownership")
        if record["kind"] == "retained":
            _, previous, current = record["depthsMetres"]
            if (record["parts"][1] != record["parts"][2] or (previous is None) != (current is None)
                    or current is not None and abs(current - previous) > 1e-8):
                raise ValueError("A retained contact changed its exact current outcome")
    if len(records) != 1038 or sum(p["geometryUnchanged"] for p in records) != 12:
        raise ValueError("Incomplete coupled profile obligations or unchanged-scope proof")
    helper["emit"](root, f"{ship}-collision-candidate.json", dict(
        schemaVersion=1, status="SOURCE_GEOMETRY_ONLY", catalogueID=ship, coordinateUnits="metres",
        forwardAxis="+Z", upAxis="+Y", calibration=physical["metresPerSourceUnitExact"],
        originalSourceSHA256=pins["source.toml"], parts=prior["parts"],
        nativeDesign={**after_mesh, "vertices": vertices.tolist()}))
    helper["emit"](root, f"{ship}-profile-witness.json", dict(
        inputSHA256=pins, convexity=proofs, checks=records, mounts=mounts,
        collisionSHA256=sha256((root / f"{ship}-collision-candidate.json").read_bytes()).hexdigest()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--ship", choices=tuple(PINS), default="SH063")
    args = parser.parse_args()
    main(args.directory, args.ship)
