"""Refine Magpie body/pod/glazing facets while preserving exact wells, fins and dry authority."""

import argparse
from fractions import Fraction
from hashlib import sha256
from pathlib import Path
import runpy

import numpy as np


PINS = {'SH107': {'candidate.json': 'f98d6007125fa3ff5c0c242fb9ca8ee40fd2fd0d62ffc96a9c995f78a79cf72c',
           'reference.json': 'e93b17740a02d207526881ecedf85c880e8bd0511fbc3c14d500c0d3a5c9d859',
           'criteria.json': 'f4ca61037f19bfca749e90847f0a35c41d6d7c60151f4783aa78b4d6c10ecfd2',
           'owner.json': 'c2450de4882a60d21d9c9738721485f71a3e4025a26f50b0d8d2943428f6a0ce',
           'witness.json': '4d5851305aedbf6d93a69bc0b7fa2aacd55654596c33f4723330619bf1d2f6cc',
           'physical.json': '1fd44d49f828657f63e32c777bd0d11c10e90f5f189b2b1624eb62bd84f767e4',
           'source.toml': '9f8ba7417e607a8ce5c16433e673249754853ef57312ff2b5a1ce6bbeecd73e6',
           'resource.toml': 'a19e2b044bc08313afb3c6157c7cbb919f8c1579148f98d09a1289208fefe446',
           'prior-candidate.json': 'b472158ac318bc9edd55182f88dc1bb96cda4e6c04c4304a61d1c08f88f72989',
           'prior-witness.json': '1d70b9369e187d1d579ac6c8f09da054962d2ab0fe89c880d7bd1034e4f1c1ad'}}
PATCHES = {0: {18: ([8, 3, 12], [8, 9, 12]),
     19: ([3, 9, 12], [9, 8, 3]),
     11: ([4, 5, 9], [4, 10, 9]),
     12: ([5, 10, 9], [10, 4, 5]),
     25: ([12, 9, 15], [12, 13, 15]),
     26: ([9, 13, 15], [13, 12, 9]),
     13: ([5, 6, 10], [5, 11, 10]),
     14: ([6, 11, 10], [11, 5, 6]),
     31: ([15, 13, 18], [15, 16, 18]),
     32: ([13, 16, 18], [16, 15, 13]),
     2: ([0, 5, 4], [4, 1, 5]),
     3: ([0, 1, 5], [1, 4, 0])},
 7: {18: ([8, 3, 12], [8, 9, 12]),
     19: ([3, 9, 12], [9, 8, 3]),
     11: ([4, 5, 9], [4, 10, 9]),
     12: ([5, 10, 9], [10, 4, 5]),
     23: ([11, 15, 14], [11, 18, 14]),
     30: ([14, 15, 18], [18, 11, 15]),
     13: ([5, 6, 10], [5, 11, 10]),
     14: ([6, 11, 10], [11, 5, 6]),
     21: ([10, 14, 13], [10, 17, 13]),
     28: ([13, 14, 17], [17, 10, 14]),
     7: ([2, 8, 7], [7, 0, 8]),
     8: ([2, 0, 8], [0, 7, 2])},
 12: {18: ([8, 3, 12], [8, 9, 12]),
      19: ([3, 9, 12], [9, 8, 3]),
      11: ([4, 5, 9], [4, 10, 9]),
      12: ([5, 10, 9], [10, 4, 5]),
      23: ([11, 15, 14], [11, 18, 14]),
      30: ([14, 15, 18], [18, 11, 15]),
      13: ([5, 6, 10], [5, 11, 10]),
      14: ([6, 11, 10], [11, 5, 6]),
      21: ([10, 14, 13], [10, 17, 13]),
      28: ([13, 14, 17], [17, 10, 14]),
      7: ([2, 8, 7], [7, 0, 8]),
      8: ([2, 0, 8], [0, 7, 2])},
 19: {27: ([13, 11, 16], [13, 14, 16]), 28: ([11, 14, 16], [14, 13, 11])}}
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
    for index in (0, 7, 12, 19):
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
    source, packaged, physical = inputs["source.toml"], inputs["resource.toml"], inputs["physical.json"]
    original = inputs["reference.json"]["nativeDesign"]
    original_pins = {name: digest for name, digest in pins.items() if not name.startswith("prior-")}
    if (initial["id"], prior["catalogueID"], physical["id"], source["proposal"]["id"], packaged["id"]) != (ship,) * 5:
        raise ValueError("Expected this Magpie's original and current source lineage")
    if (source["nativeDesign"] != original or source["design"] != packaged["design"]
            or initial["originalSourceSHA256"] != pins["source.toml"]
            or physical["detailedSourceSHA256"] != pins["source.toml"]
            or inputs["prior-witness.json"]["collisionSHA256"] != pins["prior-candidate.json"]
            or inputs["prior-witness.json"]["inputSHA256"] != original_pins
            or prior["calibration"] != physical["metresPerSourceUnitExact"]):
        raise ValueError("Original, renderer, current mesh and physical authority do not bind")
    owner = inputs["owner.json"]
    if (owner["id"] != ship or inputs["reference.json"]["id"] != ship or inputs["criteria.json"]["id"] != ship
            or owner["geometrySHA256"] != pins["source.toml"]
            or initial["ownershipSHA256"] != pins["owner.json"]
            or physical["contractSHA256"] != inputs["criteria.json"]["r3SHA256"]
            or Fraction(physical["metresPerSourceUnitExact"]) != Fraction(1875, 152)):
        raise ValueError("Magpie ownership, engineering contract or adopted calibration differs")
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
    local = runpy.run_path(str(HERE / "freeze-sh063-recesses.py"))["local"]
    source_parts = inputs["criteria.json"]["parts"]["originalPartRanges"]
    fixed = [p for p in prior["parts"] if "/service-well-" in p["name"] or p["name"] == "stepped vertical fin"]
    for part in fixed:
        if local(before_mesh, part) != local(original, source_parts[part["index"]]):
            raise ValueError("An exact original well or copper fin changed")
    after_mesh = {**before_mesh, "faces": faces, "faceTextures": textures}
    before = {**initial, "nativeDesign": before_mesh}
    after = {**initial, "nativeDesign": after_mesh}
    vertices = np.asarray(before_mesh["vertices"]) * scale
    triangles = vertices[faces]
    if len(triangles) != 512 or len(prior["parts"]) != 27:
        raise ValueError("Expected the complete 512-triangle Magpie")
    verify["verify_parts"](faces, triangles, prior["parts"])
    source_parts = inputs["criteria.json"]["parts"]["originalPartRanges"]
    proofs = [plane_proof(original, before_mesh, after_mesh, prior["parts"][i], source_parts[i], scale)
              for i in (0, 7, 12, 19)]
    if any(proof["currentNonSupportingFacets"] >= proof["priorNonSupportingFacets"]
           or proof["currentMaxVertexPlaneDeviationMetres"] > proof["priorMaxVertexPlaneDeviationMetres"] + 1e-8
           for proof in proofs):
        raise ValueError("The partial profile patch did not improve its own facet support")
    records = measure(original, before, after, prior["parts"], source_parts,
                      inputs["prior-witness.json"], inputs["witness.json"], scale, verify["RAY_HIT"])
    mass = physical["dryMassKilograms"]
    centre = np.asarray(physical["centreOfMassMetres"])
    inertia = np.asarray(physical["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3)
    radius = max(float(np.linalg.norm(vertex)) for vertex in vertices)
    prior_witness = inputs["prior-witness.json"]
    if (mass <= 0 or not np.isfinite(centre).all() or not np.isfinite(inertia).all()
            or not np.allclose(inertia, inertia.T) or np.linalg.eigvalsh(inertia).min() <= 0
            or mass != prior_witness["dryMassKilograms"] or centre.tolist() != prior_witness["centreOfMassMetres"]
            or inertia.flatten().tolist() != prior_witness["dryInertiaKgM2"]
            or abs(radius - prior_witness["bareHullRadiusMetres"]) > 1e-8
            or any(prior_witness[key] is not None for key in ("fittedRadiusMetres", "installedMount", "roleBinding"))):
        raise ValueError("The dry authority or unissued fit/role boundary changed")
    engineering = dict(dryMassKilograms=mass, centreOfMassMetres=centre.tolist(),
                       dryInertiaKgM2=inertia.flatten().tolist(), bareHullRadiusMetres=radius,
                       fittedRadiusMetres=None, installedMount=None, roleBinding=None)
    for record in records:
        if (not no_regression(record["depthsMetres"])
                or record["parts"][2] not in (record["parts"][0], record["parts"][1])):
            raise ValueError("A profile or coupled control regressed in source depth or ownership")
        if record["kind"] == "retained":
            _, previous, current = record["depthsMetres"]
            if (record["parts"][1] != record["parts"][2] or (previous is None) != (current is None)
                    or current is not None and abs(current - previous) > 1e-8):
                raise ValueError("A retained contact changed its exact current outcome")
    if len(records) != 1888 or sum(p["geometryUnchanged"] for p in records) != 36:
        raise ValueError("Incomplete coupled profile obligations or unchanged-scope proof")
    helper["emit"](root, f"{ship}-collision-candidate.json", dict(
        schemaVersion=1, status="SOURCE_GEOMETRY_ONLY", catalogueID=ship, coordinateUnits="metres",
        forwardAxis="+Z", upAxis="+Y", calibration=physical["metresPerSourceUnitExact"],
        originalSourceSHA256=pins["source.toml"], parts=prior["parts"],
        nativeDesign={**after_mesh, "vertices": vertices.tolist()}))
    helper["emit"](root, f"{ship}-profile-witness.json", dict(
        inputSHA256=pins, convexity=proofs, checks=records, engineering=engineering,
        collisionSHA256=sha256((root / f"{ship}-collision-candidate.json").read_bytes()).hexdigest()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--ship", choices=tuple(PINS), default="SH107")
    args = parser.parse_args()
    main(args.directory, args.ship)
