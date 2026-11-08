"""Refine Caracara body and glazing facets with both current collars as controls."""

import argparse
from fractions import Fraction
from hashlib import sha256
from pathlib import Path
import runpy

import numpy as np


PINS = {'SH169': {'candidate.json': '1ecb59c22eae9915a896ce65bf5513d74dea9ab68c08080e6b90bd3ec8389b40',
           'reference.json': '7dfb960a6b09d36e2425269bda78af408982799de17a1f717e7e8095d90d1003',
           'criteria.json': '748d06a56ac156a9213da3d5806db867f5baae23d040c57bc5a0dee8097c04bc',
           'witness.json': 'ffaf5c88cc8f11517db666657de30a1023d7ae21738dccb7fc6b7effebd3b042',
           'source.toml': '6257767fbb2cd35db071004b197f8f5655251f87ca3398e176343d12c0fb7b1c',
           'SH169.json': '206b709130bbe749f089e84127abaf79218ecadcef3cb5ca5821b0d60d55821c',
           'SH169.toml': '1ffb117ac1f05b759d9e06c52fdd0fdb4d7d4b7aa3cae3d1fdbe6998111f195d',
           'prior-candidate.json': '1976670089bd9d34cee29b6d3d8e659b1fbec516a7e69c2ce5143df3b0fa2f05',
           'prior-witness.json': '5cd021f05368001db79fecea16c7076c76ca1bee814b5c46068243dbf91688ad'},
 'SH170': {'candidate.json': '70d853e46220a6d8d2f2f566341838df53d1beea2f9d9699cedb2b57bbeeb3e1',
           'reference.json': '645aa307abf266ae850b0664d1ee6e10c19756c9a0bdd5c8ece0a9bf098b9b47',
           'criteria.json': 'cd2929ae0957ec9c1a68887f183890b2f73ca2afd1b3b8242dcce12d13940ae9',
           'witness.json': '8a1171f765ccbb982cdec9f5c4c8ac47748c4a9e524f813d7df155e3a942fbbb',
           'source.toml': 'db011887f67e1ae1c5f235fe2b7c4db4a65b29b37906a830433d69d9c8a5527b',
           'SH170.json': '28d71e5541b55d9749d9a441d1b78a4feaefa6dcc864ded9421710d616f0e19c',
           'SH170.toml': 'e8412b14817fbf9035dcbc9be730f0626455fb8f66fe2655419bcfac2fef5de1',
           'prior-candidate.json': 'd144c8d581170f897fb2830dbfed97a37200ca87222962a704317f5eefc0a0e4',
           'prior-witness.json': 'b4be459dbcde14bb27fd6cd02403f40ae3d877b1385a08214b892b0ef2946223'}}
PATCHES = {'SH169': {0: {20: ([8, 9, 15], [9, 14, 8]),
               21: ([8, 15, 14], [14, 9, 15]),
               26: ([11, 6, 12], [6, 17, 11]),
               27: ([11, 12, 17], [17, 6, 12]),
               32: ([14, 15, 21], [15, 20, 14]),
               33: ([14, 21, 20], [20, 15, 21]),
               38: ([17, 12, 18], [12, 23, 17]),
               39: ([17, 18, 23], [23, 12, 18]),
               44: ([20, 21, 27], [21, 26, 20]),
               45: ([20, 27, 26], [26, 21, 27]),
               50: ([23, 18, 24], [18, 29, 23]),
               51: ([23, 24, 29], [29, 18, 24]),
               8: ([2, 3, 9], [3, 8, 2]),
               9: ([2, 9, 8], [8, 3, 9]),
               14: ([5, 0, 6], [0, 11, 5]),
               15: ([5, 6, 11], [11, 0, 6])},
           9: {26: ([11, 6, 12], [6, 17, 11]),
               27: ([11, 12, 17], [17, 6, 12]),
               20: ([8, 9, 15], [9, 14, 8]),
               21: ([8, 15, 14], [14, 9, 15]),
               32: ([14, 15, 21], [15, 20, 14]),
               33: ([14, 21, 20], [20, 15, 21]),
               38: ([17, 12, 18], [12, 23, 17]),
               39: ([17, 18, 23], [23, 12, 18]),
               44: ([20, 21, 27], [21, 26, 20]),
               45: ([20, 27, 26], [26, 21, 27]),
               50: ([23, 18, 24], [18, 29, 23]),
               51: ([23, 24, 29], [29, 18, 24]),
               8: ([2, 3, 9], [3, 8, 2]),
               9: ([2, 9, 8], [8, 3, 9]),
               14: ([5, 0, 6], [0, 11, 5]),
               15: ([5, 6, 11], [11, 0, 6])}},
 'SH170': {0: {20: ([8, 9, 15], [9, 14, 8]),
               21: ([8, 15, 14], [14, 9, 15]),
               26: ([11, 6, 12], [6, 17, 11]),
               27: ([11, 12, 17], [17, 6, 12]),
               32: ([14, 15, 21], [15, 20, 14]),
               33: ([14, 21, 20], [20, 15, 21]),
               38: ([17, 12, 18], [12, 23, 17]),
               39: ([17, 18, 23], [23, 12, 18]),
               44: ([20, 21, 27], [21, 26, 20]),
               45: ([20, 27, 26], [26, 21, 27]),
               50: ([23, 18, 24], [18, 29, 23]),
               51: ([23, 24, 29], [29, 18, 24]),
               8: ([2, 3, 9], [3, 8, 2]),
               9: ([2, 9, 8], [8, 3, 9]),
               14: ([5, 0, 6], [0, 11, 5]),
               15: ([5, 6, 11], [11, 0, 6])},
           9: {26: ([11, 6, 12], [6, 17, 11]),
               27: ([11, 12, 17], [17, 6, 12]),
               20: ([8, 9, 15], [9, 14, 8]),
               21: ([8, 15, 14], [14, 9, 15]),
               32: ([14, 15, 21], [15, 20, 14]),
               33: ([14, 21, 20], [20, 15, 21]),
               38: ([17, 12, 18], [12, 23, 17]),
               39: ([17, 18, 23], [23, 12, 18]),
               44: ([20, 21, 27], [21, 26, 20]),
               45: ([20, 27, 26], [26, 21, 27]),
               50: ([23, 18, 24], [18, 29, 23]),
               51: ([23, 24, 29], [29, 18, 24]),
               8: ([2, 3, 9], [3, 8, 2]),
               9: ([2, 9, 8], [8, 3, 9]),
               14: ([5, 0, 6], [0, 11, 5]),
               15: ([5, 6, 11], [11, 0, 6])}}}
HERE = Path(__file__).resolve().parent


def same_geometry(before, after, part):
    v, n, f, count = part["vertexStart"], part["vertexCount"], part["faceStart"], part["faceCount"]
    return (before["vertices"][v:v + n] == after["vertices"][v:v + n]
            and all(before[key][f:f + count] == after[key][f:f + count]
                    for key in ("faces", "faceMaterials", "faceTextures")))


def hit_result(triangles, owners, indices, origin, direction, limit, ray_hit):
    hit = ray_hit(triangles[indices], origin, direction, limit)
    return (None, None) if hit is None else (int(owners[indices[hit[0]]]), hit[1])


def prior_record(record, hit, kind, unchanged):
    return dict(record, kind=kind, geometryUnchanged=unchanged,
                parts=[record["parts"][0], record["parts"][2], hit[0]],
                depthsMetres=[record["depthsMetres"][0], record["depthsMetres"][2], hit[1]])


def profile_cases(original, before, after, parts, source_parts, all_points):
    cases = []
    for index in (0, 9):
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


def measure(original, before, after, parts, source_parts, prior, oldw, scale, ray_hit):
    before, after = before["nativeDesign"], after["nativeDesign"]
    meshes = (original, before, after)
    surfaces = [(np.asarray(mesh["vertices"]) * scale)[mesh["faces"]] for mesh in meshes]
    owners = [np.repeat([p["index"] for p in ranges], [p["faceCount"] for p in ranges])
              for ranges in (source_parts, parts, parts)]
    all_points = np.concatenate([np.asarray(mesh["vertices"]) for mesh in meshes])
    records = []
    ray_scopes = [(ray, assembled) for ray in oldw["rays"]
                  for assembled in ([False, True] if "assembled" in ray else [True])]
    for record, (ray, assembled) in zip(prior["retainedContacts"], ray_scopes, strict=True):
        if (record["name"], record["assembled"]) != (ray["name"], assembled):
            raise ValueError("The retained contact sequence differs")
        unchanged = not assembled and same_geometry(before, after, parts[record["parts"][2]])
        if unchanged:
            hit = record["parts"][2], record["depthsMetres"][2]
        else:
            hit = hit_result(surfaces[2], owners[2], np.arange(512), np.asarray(record["originMetres"]),
                             np.asarray(record["direction"]), ray["limit"] * scale, ray_hit)
        records.append(prior_record(record, hit, "retained", unchanged))
    for kind, controls, index in (("negative-collar", prior["negativeCollarProof"]["probes"], 5),
                                  ("positive-collar", prior["positiveCollarProbes"], 6)):
        for record in controls:
            origin, direction = np.asarray(record["originMetres"]), np.asarray(record["direction"])
            limit = .5 * scale
            unchanged = not record["assembled"] and same_geometry(before, after, parts[index])
            if kind == "negative-collar":
                if unchanged:
                    source, _, current = record["depthsMetres"]
                    current_parts = [None if source is None else index, None if current is None else index]
                else:
                    old_hits = [hit_result(triangles, model_owners, np.arange(len(triangles)), origin,
                                          direction, limit, ray_hit)
                                for triangles, model_owners in zip(surfaces[:2], owners[:2], strict=True)]
                    for old_hit, expected in zip(old_hits, (record["depthsMetres"][0],
                                                           record["depthsMetres"][2]), strict=True):
                        depth = old_hit[1]
                        if (depth is None) != (expected is None) or depth is not None and abs(depth - expected) > 1e-8:
                            raise ValueError("The negative-collar prior depths do not bind")
                    current_parts = [hit[0] for hit in old_hits]
                record = dict(record, parts=[current_parts[0], current_parts[1], current_parts[1]])
            if unchanged:
                hit = record["parts"][2], record["depthsMetres"][2]
            else:
                hit = hit_result(surfaces[2], owners[2], np.arange(512), origin, direction, limit, ray_hit)
            records.append(prior_record(record, hit, kind, unchanged))
    for case in profile_cases(original, before, after, parts, source_parts, all_points):
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


def main(root, ship):
    helper = runpy.run_path(str(HERE / "freeze-sh071-profiles.py"))
    verify = runpy.run_path(str(HERE / "freeze-sh169-crest.py"))
    no_regression = runpy.run_path(str(HERE / "freeze-sh128-rim.py"))["no_depth_regression"]
    plane_proof = runpy.run_path(str(HERE / "freeze-sh096-drives.py"))["drive_proof"]
    chart = runpy.run_path(str(HERE.parents[2] / "Tools/authoring/sh023_native_topology.py"))["uv_for_face"]
    pins = PINS[ship]
    inputs = {name: helper["load"](root, name, digest) for name, digest in pins.items()}
    initial, prior = inputs["candidate.json"], inputs["prior-candidate.json"]
    source, packaged, physical = inputs["source.toml"], inputs[f"{ship}.toml"], inputs[f"{ship}.json"]
    original = inputs["reference.json"]["nativeDesign"]
    if (initial["id"], prior["catalogueID"], physical["id"], source["proposal"]["id"], packaged["id"]) != (ship,) * 5:
        raise ValueError("Expected this Caracara's original and current source lineage")
    if (source["nativeDesign"] != original or source["design"] != packaged["design"]
            or initial["originalSourceSHA256"] != pins["source.toml"]
            or prior["originalSourceSHA256"] != pins["source.toml"]
            or physical["detailedSourceSHA256"] != pins["source.toml"]
            or inputs["prior-witness.json"]["collisionSHA256"] != pins["prior-candidate.json"]
            or initial["parts"] != prior["parts"] or prior["calibration"] != physical["metresPerSourceUnitExact"]):
        raise ValueError("Original, renderer, current mesh and physical authority do not bind")
    scale = float(Fraction(physical["metresPerSourceUnitExact"]))
    if not np.array_equal(np.asarray(initial["nativeDesign"]["vertices"]) * scale,
                          np.asarray(prior["nativeDesign"]["vertices"])):
        raise ValueError("The source frame cannot reproduce the pinned world vertices exactly")
    before_mesh = {**prior["nativeDesign"], "vertices": initial["nativeDesign"]["vertices"]}
    for key in ("appearanceLicense", "appearanceSource", "materials", "textures", "paletteName"):
        if before_mesh[key] != original[key]:
            raise ValueError(f"Changed original appearance metadata {key}")
    faces, textures = list(before_mesh["faces"]), list(before_mesh["faceTextures"])
    for index, patch in PATCHES[ship].items():
        part = prior["parts"][index]
        for offset, (old, new) in patch.items():
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
    if len(triangles) != 512 or len(prior["parts"]) != 21:
        raise ValueError("Expected the complete 512-triangle Caracara")
    verify["verify_parts"](faces, triangles, prior["parts"])
    source_parts = inputs["criteria.json"]["parts"]["originalPartRanges"]
    proofs = [plane_proof(original, before_mesh, after_mesh, prior["parts"][i], source_parts[i], scale)
              for i in (0, 9)]
    if any(proof["currentNonSupportingFacets"] != 0 for proof in proofs):
        raise ValueError("The profile patch did not reach its fixed-vertex convex hull")
    records = measure(original, before, after, prior["parts"], source_parts,
                      inputs["prior-witness.json"], inputs["witness.json"], scale, verify["RAY_HIT"])
    for record in records:
        if (not no_regression(record["depthsMetres"])
                or record["parts"][2] not in (record["parts"][0], record["parts"][1])):
            raise ValueError("A profile or coupled control regressed in source depth or ownership")
        if record["kind"] == "retained":
            _, previous, current = record["depthsMetres"]
            if (record["parts"][1] != record["parts"][2] or (previous is None) != (current is None)
                    or current is not None and abs(current - previous) > 1e-8):
                raise ValueError("A retained contact changed its exact current outcome")
    if len(records) != 2880 or sum(p["geometryUnchanged"] for p in records) != 972:
        raise ValueError("Incomplete coupled profile obligations or unchanged-scope proof")
    helper["emit"](root, f"{ship}-collision-candidate.json", dict(
        schemaVersion=1, status="SOURCE_GEOMETRY_ONLY", catalogueID=ship, coordinateUnits="metres",
        forwardAxis="+Z", upAxis="+Y", calibration=physical["metresPerSourceUnitExact"],
        originalSourceSHA256=pins["source.toml"], parts=prior["parts"],
        nativeDesign={**after_mesh, "vertices": vertices.tolist()}))
    helper["emit"](root, f"{ship}-profile-witness.json", dict(
        inputSHA256=pins, convexity=proofs, checks=records,
        collisionSHA256=sha256((root / f"{ship}-collision-candidate.json").read_bytes()).hexdigest()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--ship", choices=tuple(PINS), default="SH169")
    args = parser.parse_args()
    main(args.directory, args.ship)
