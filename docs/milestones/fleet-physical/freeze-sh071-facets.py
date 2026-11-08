"""Refine Griffon body and glazing facets while preserving restored vertical profiles."""

import argparse
from fractions import Fraction
from hashlib import sha256
from pathlib import Path
import runpy

import numpy as np


PINS = {'SH071': {'candidate.json': 'b955640999b813290147c72fcdf1856cff5474aab1663e256a3ce34a2fb09397',
           'reference.json': 'd098411e4ded08d59a6ba55ef86c958e2f6d66a7ea2f03f383fb71aaa4654e7f',
           'criteria.json': '437b427c2e4b7fa6420da014ce497ded6e078effb6ec6453db823617850db5a2',
           'witness.json': 'b648f445c6ef502b114d6cc4c09763cbccd590b8b45bdeb080f7c6933d12fe73',
           'source.toml': '3f1d908400f032a2a90b8a4ee486c58e93368e4c49a1fa8a742ba52b7c9a80cc',
           'SH071.json': '4cf43c8db53f2e00177709bbd2761ef7360be2520a3576cb78a158bead2f31f7',
           'SH071.toml': '911a47c6e0044e0fc103951432f11b34bf3e2dcba83509f28c620d25e097e5c6',
           'prior-candidate.json': 'd9739329e2db08c5fc06cd3c06792d34216ee4dac2915fc1c81cbb9319180184',
           'prior-witness.json': '47821bcbdff3a92fd9c0318e5a3f2d20e4435c40977b79f92ac1473d332fd866'},
 'SH072': {'candidate.json': '92c4b7a0535b9ba8be6ca3f119ff4d710c7d589dcc869ab4958289314bc98f24',
           'reference.json': '484dc62f693a95584220a8f6b55a48052d657e9e4bce6784acf801fae2012e9e',
           'criteria.json': 'f019ba840a18493a97031b56333006f3a5cee2a699f998c227f76bbd2d15b0d4',
           'witness.json': '404021b9c860e7638271ac662307682ffffff37d2b543aef820d8065a601df33',
           'source.toml': '8ea9b1346142ef4c31e71b802258b859d54be0cdc12ac05bf3f6a02d55733d70',
           'SH072.json': '276171fa798535cc68af1bbce174f3defda19659c4a386113159557f73b91273',
           'SH072.toml': '376f8ee997f911c34ebd068636d9d37b9ee2c55131c38f3b3ae48fa308578ba0',
           'prior-candidate.json': 'e9c937575f77773529a887e86f0d2e90ec564998b62a1d8582ee4b4f4dc6c34d',
           'prior-witness.json': 'd4f71260dd852bc591eafeb4efa1c503d7e0150848a507f00676e8e863ed6126'},
 'SH073': {'candidate.json': '50082370ba60f98ddf49622fd2f87033dc8be84e0d9e24209dbfc96ebcc1af42',
           'reference.json': '0ceb33774f174b5cdd0b59a8b55c8f6e5c30edf94edca46937a3427bcd715a15',
           'criteria.json': '14e9252300b93490973338f16b40d8d9cef1dd3d021002827ad3ca79256466bb',
           'witness.json': '744bd86d447b8eeff041725c3867a353fd393c799ad9ba71283fd33f4b482e47',
           'source.toml': 'f132d3229d67b58a29dfda4707dcbc17537163ab31da7d20a77645c8fcc3268e',
           'SH073.json': '023d8539a45e25169613eb7899d98d8d34264c81c3b75d9ae6c6fce5037acdbb',
           'SH073.toml': 'd386ff366bf2ea46931b4f6ed503f46b80d2457718dff64729465df9bac4b62f',
           'prior-candidate.json': 'f8949ed87dac8e8a49dc8a7b98ba441a032000a93c3b0ac2c98ffd175889168d',
           'prior-witness.json': '12bf0d91e7eff2e3b9ed92582d1662ce99876465c17eeb5f1e28e5c79f5cf2d4'}}
PATCHES = {6: {28: ([8, 9, 15], [9, 14, 8]),
     29: ([8, 15, 14], [14, 9, 15]),
     36: ([11, 6, 12], [6, 17, 11]),
     37: ([11, 12, 17], [17, 6, 12]),
     44: ([14, 15, 21], [15, 20, 14]),
     45: ([14, 21, 20], [20, 15, 21]),
     52: ([17, 12, 18], [12, 23, 17]),
     53: ([17, 18, 23], [23, 12, 18]),
     68: ([23, 18, 24], [18, 29, 23]),
     69: ([23, 24, 29], [29, 18, 24]),
     60: ([20, 21, 27], [21, 26, 20]),
     61: ([20, 27, 26], [26, 21, 27]),
     14: ([3, 4, 10], [4, 9, 3]),
     15: ([3, 10, 9], [9, 4, 10]),
     6: ([0, 1, 7], [1, 6, 0]),
     7: ([0, 7, 6], [6, 1, 7])},
 11: {15: ([4, 5, 11], [5, 32, 4]),
      16: ([11, 32, 4], [32, 5, 11]),
      26: ([8, 9, 15], [9, 14, 8]),
      27: ([8, 15, 14], [14, 9, 15]),
      34: ([11, 6, 12], [6, 17, 11]),
      35: ([11, 12, 17], [17, 6, 12]),
      50: ([17, 12, 18], [12, 23, 17]),
      51: ([17, 18, 23], [23, 12, 18]),
      42: ([14, 15, 21], [15, 20, 14]),
      43: ([14, 21, 20], [20, 15, 21]),
      62: ([22, 36, 29], [36, 28, 22]),
      64: ([22, 29, 28], [28, 36, 29]),
      65: ([23, 18, 24], [18, 29, 23]),
      66: ([23, 24, 29], [29, 18, 24]),
      58: ([20, 21, 27], [21, 26, 20]),
      59: ([20, 27, 26], [26, 21, 27]),
      11: ([2, 3, 9], [3, 8, 2]),
      12: ([2, 9, 8], [8, 3, 9]),
      18: ([5, 0, 6], [0, 11, 5]),
      19: ([5, 6, 11], [11, 0, 6])}}
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
    for index in (6, 11):
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
    by_name = {ray["name"]: ray for ray in oldw["rays"]}
    records = []
    retained_cases = [(ray, ray["hits"]["reference"], True) for ray in oldw["rays"]]
    retained_cases += [(by_name[ray["name"]], ray["hits"]["reference"], False) for ray in oldw["isolated"]]
    for ray, expected, assembled in retained_cases:
        prior_part = None if expected is None else expected["part"]
        prior_depth = None if expected is None else expected["distance"] * scale
        unchanged = not assembled and same_geometry(before, after, parts[prior_part])
        if unchanged:
            hit = prior_part, prior_depth
        else:
            hit = hit_result(surfaces[2], owners[2], np.arange(512), np.asarray(ray["origin"]) * scale,
                             np.asarray(ray["direction"]), ray["limit"] * scale, ray_hit)
        records.append(dict(kind="retained", name=ray["name"], assembled=assembled,
                            originMetres=(np.asarray(ray["origin"]) * scale).tolist(), direction=ray["direction"],
                            limitMetres=ray["limit"] * scale, parts=[prior_part, prior_part, hit[0]],
                            depthsMetres=[prior_depth, prior_depth, hit[1]], geometryUnchanged=unchanged))
    assembled_controls = prior.get("assembledProfileRays")
    if assembled_controls is not None and len(assembled_controls) != len(prior["profileRays"]):
        raise ValueError("Incomplete prior assembled profile set")
    for index, control in enumerate(prior["profileRays"]):
        for assembled in (False, True):
            hits = []
            for triangles, ranges, model_owners in zip(surfaces, (source_parts, parts, parts), owners, strict=True):
                part = ranges[control["part"]]
                selected = (np.arange(len(triangles)) if assembled else
                            np.arange(part["faceStart"], part["faceStart"] + part["faceCount"]))
                hits.append(hit_result(triangles, model_owners, selected, np.asarray(control["origin"]),
                                       np.asarray(control["direction"]), 30, ray_hit))
            expected = None
            if not assembled:
                expected = control["source"], control["hits"][1]
            elif assembled_controls is not None:
                previous = assembled_controls[index]
                if any(previous[key] != control[key] for key in ("part", "origin", "direction")):
                    raise ValueError("A prior assembled control changed its source ray")
                expected = previous["depthsMetres"][0], previous["depthsMetres"][2]
            if expected is not None:
                for actual, target in zip((hits[0][1], hits[1][1]), expected, strict=True):
                    if ((actual is None) != (target is None)
                            or actual is not None and abs(actual - target) > 1e-8):
                        raise ValueError("A pinned profile depth does not bind its reconstructed owner")
            records.append(dict(kind="prior-profile", part=control["part"], assembled=assembled,
                                originMetres=control["origin"], direction=control["direction"], limitMetres=30,
                                parts=[hit[0] for hit in hits], depthsMetres=[hit[1] for hit in hits],
                                geometryUnchanged=False))
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
    original_pins = {name: digest for name, digest in pins.items() if not name.startswith("prior-")}
    if (initial["id"], prior["catalogueID"], physical["id"], source["proposal"]["id"], packaged["id"]) != (ship,) * 5:
        raise ValueError("Expected this Griffon's original and current source lineage")
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
    for index, patch in PATCHES.items():
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
    if len(triangles) != 512 or len(prior["parts"]) != 19:
        raise ValueError("Expected the complete 512-triangle Griffon")
    verify["verify_parts"](faces, triangles, prior["parts"])
    source_parts = inputs["criteria.json"]["parts"]["originalPartRanges"]
    proofs = [plane_proof(original, before_mesh, after_mesh, prior["parts"][i], source_parts[i], scale)
              for i in (6, 11)]
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
    if len(records) != 1398 or sum(p["geometryUnchanged"] for p in records) != 12:
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
    parser.add_argument("--ship", choices=tuple(PINS), default="SH071")
    args = parser.parse_args()
    main(args.directory, args.ship)
