"""Refine Goshawk profile facets while retaining complete wells, bridges and upper rims."""

import argparse
from collections import Counter
from fractions import Fraction
from hashlib import sha256
from pathlib import Path
import runpy

import numpy as np


PINS = {'SH010': {'candidate.json': '4f3dad625a966050db0a3491e9be75901d7402d4a1bace0a964cabbbff7cd679',
           'reference.json': '6b2fcf012eaf7cea3bede3f95679c80dd74517f39cffc8a6356ea173070cfced',
           'criteria.json': '504ed3797d582da2847b0e111405a47414a0b860d7d2119621b65099c6e65f5a',
           'witness.json': '60bf04125150e7a07501c291d93755bd8d2c64c5d4f5e222482f9c76a1fa33de',
           'physical.json': '30aba17c31f65a5d1bcb9a29455f45bb876628ce5906d4af5cf16f249d2a79a6',
           'source.toml': '3e131707177a4b934ad969dc62da49963adf9aa6a71985e6dcf21c8ba9dd179c',
           'resource.toml': '66f8a18a52854fad92f8c0b1cb76ef3d0b6f7405d6e8e66e944b1b9e63bb89d3',
           'owner.json': '5b3b4ff988a01b91e592fd73b048b2af8712c40b071406402def30b62f312bf9'},
 'SH011': {'candidate.json': '5a52c8688659ebd6e0f50a6152254fd69e8bf61645dfbe6a982bea58dd4c6bd9',
           'reference.json': '0e118107ca6417817cfcda6c44ca22e57b5d5ae630e8ef03e37513d6fcd05a4a',
           'criteria.json': '573ed9b4e7293591c3b974561a19ba398c5797b1197361d6a6ff74f36a585cf6',
           'witness.json': '1db8c4172f9cf60535e4e51dd78867dcd0afd00ef956a178d664ea24c0a8f766',
           'physical.json': '8b7526bcbbc93a6665cf3a288b7ebb5ce60ecc411e387626b2f602b39b88df51',
           'source.toml': 'f0e1bf789ccad1f445f9d576c03affc853b7beb41b6820c03739b7e45a5e6884',
           'resource.toml': 'dec7c21964fd5e4521cde5c07fae024eb8c926607fc9223b2a3667830600729e',
           'owner.json': '7bd154d96c015d233a4689a00aeceb75d72f7bada29b0980fe290f706b102bc4'}}
OUTER_PATCH = {5: ([2, 0, 3], [0, 5, 2]),
 6: ([2, 3, 5], [5, 0, 3]),
 11: ([5, 3, 6], [3, 8, 5]),
 12: ([5, 6, 8], [8, 3, 6]),
 17: ([8, 6, 9], [6, 11, 8]),
 18: ([8, 9, 11], [11, 6, 9]),
 23: ([11, 9, 12], [9, 14, 11]),
 24: ([11, 12, 14], [14, 9, 12])}
BODY_PATCH = {1: ([0, 1, 4], [1, 3, 0]),
 2: ([0, 4, 3], [3, 1, 4]),
 11: ([5, 3, 6], [3, 8, 5]),
 12: ([5, 6, 8], [8, 3, 6]),
 17: ([8, 6, 9], [6, 11, 8]),
 18: ([8, 9, 11], [11, 6, 9]),
 23: ([11, 9, 12], [9, 14, 11]),
 24: ([11, 12, 14], [14, 9, 12])}
PATCHES = {1: OUTER_PATCH, 7: OUTER_PATCH, 14: BODY_PATCH, 19: OUTER_PATCH}
TARGETS = tuple(PATCHES)
CALIBRATIONS = {"SH010": Fraction(15000000, 1644589), "SH011": Fraction(30000000, 3391379)}
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
    for index in TARGETS:
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


def control_cases(original, source_parts, oldw):
    cases = []
    for sample, ray in enumerate(oldw["rays"]):
        well = ray["name"] == "well-floor"
        for assembled in ((False, True) if well else (True,)):
            expected = ray["assembled"] if well and assembled else ray["hits"]
            cases.append(dict(kind="retained", name=ray["name"], sample=sample, part=ray["part"],
                              assembled=assembled, origin=np.asarray(ray["origin"]),
                              direction=np.asarray(ray.get("direction", [0, 0, 1])),
                              limit=.105 if well else .055, expected=expected))
    points = np.asarray(original["vertices"])
    for part in source_parts:
        if "bridge" not in part["name"] and "service-well" not in part["name"]:
            continue
        kind = "bridge-normal" if "bridge" in part["name"] else "well-normal"
        distance = 4 if kind == "bridge-normal" else 3
        for face in range(part["faceStart"], part["faceStart"] + part["faceCount"]):
            triangle = points[original["faces"][face]]
            normal = np.cross(triangle[1] - triangle[0], triangle[2] - triangle[0])
            normal /= np.linalg.norm(normal)
            for sample, weights in enumerate(((.6, .2, .2), (.2, .6, .2), (.2, .2, .6))):
                center = np.asarray(weights) @ triangle
                cases.append(dict(kind=kind, part=part["index"], assembled=True, face=face, sample=sample,
                                  origin=center + distance * normal, direction=-normal, limit=distance + .00001))
    return cases


def verify_retained(case, hits, scale):
    # Samples share names. Bind by sequential case identity, never a name lookup.
    for index, key in enumerate(("reference", "candidate")):
        expected = case["expected"][key]
        owner = None if expected is None else expected["part"]
        depth = None if expected is None else expected["distance"] * scale
        actual_owner, actual_depth = hits[index]
        if (actual_owner != owner or (actual_depth is None) != (depth is None)
                or depth is not None and abs(actual_depth - depth) > 1e-8):
            raise ValueError("A pinned well/rim contact differs from its historical outcome")


def measure(original, before, after, parts, source_parts, oldw, scale, ray_hit):
    before, after = before["nativeDesign"], after["nativeDesign"]
    meshes = (original, before, after)
    surfaces = [(np.asarray(mesh["vertices"]) * scale)[mesh["faces"]] for mesh in meshes]
    owners = [np.repeat([p["index"] for p in ranges], [p["faceCount"] for p in ranges])
              for ranges in (source_parts, parts, parts)]
    all_points = np.concatenate([np.asarray(mesh["vertices"]) for mesh in meshes])
    controls = control_cases(original, source_parts, oldw)
    profiles = profile_cases(original, before, after, parts, source_parts, all_points)
    cases = controls + [dict(case, assembled=assembled) for case in profiles for assembled in (False, True)]
    records = []
    for case in cases:
        unchanged = not case["assembled"] and same_geometry(before, after, parts[case["part"]])
        hits = []
        for index, (triangles, model_owners) in enumerate(zip(surfaces, owners, strict=True)):
            if index == 2 and unchanged:
                hits.append(hits[1])
                continue
            indices = (np.arange(len(triangles)) if case["assembled"] else
                       np.flatnonzero(model_owners == case["part"]))
            hits.append(hit_result(triangles, model_owners, indices, case["origin"] * scale,
                                   case["direction"], case["limit"] * scale, ray_hit))
        if case["kind"] == "retained":
            verify_retained(case, hits, scale)
        record = {key: value for key, value in case.items()
                  if key not in ("origin", "direction", "limit", "expected")}
        record.update(originMetres=(case["origin"] * scale).tolist(), direction=case["direction"].tolist(),
                      limitMetres=case["limit"] * scale, parts=[hit[0] for hit in hits],
                      depthsMetres=[hit[1] for hit in hits], geometryUnchanged=unchanged)
        if case["kind"] == "well-normal":
            record["sourceVisible"] = (hits[0][0] == case["part"] and abs(hits[0][1] / scale - 3) <= 1e-8)
        records.append(record)
    return records


def main(root, ship):
    helper = runpy.run_path(str(HERE / "freeze-sh071-profiles.py"))
    verify = runpy.run_path(str(HERE / "freeze-sh169-crest.py"))
    no_regression = runpy.run_path(str(HERE / "freeze-sh128-rim.py"))["no_depth_regression"]
    plane_proof = runpy.run_path(str(HERE / "freeze-sh096-drives.py"))["drive_proof"]
    chart = runpy.run_path(str(HERE.parents[2] / "Tools/authoring/sh023_native_topology.py"))["uv_for_face"]
    pins = PINS[ship]
    inputs = {name: helper["load"](root, name, digest) for name, digest in pins.items()}
    initial = inputs["candidate.json"]
    source, packaged, physical = inputs["source.toml"], inputs["resource.toml"], inputs["physical.json"]
    original = inputs["reference.json"]["nativeDesign"]
    owner = inputs["owner.json"]
    ids = (initial["id"], physical["id"], source["proposal"]["id"], packaged["id"], owner["id"],
           inputs["reference.json"]["id"], inputs["criteria.json"]["id"])
    if ids != (ship,) * 7:
        raise ValueError("Expected the exact Goshawk sources")
    if (source["nativeDesign"] != original or source["design"] != packaged["design"]
            or initial["originalSourceSHA256"] != pins["source.toml"]
            or physical["detailedSourceSHA256"] != pins["source.toml"]
            or physical["componentSourceSHA256"] != pins["owner.json"]
            or owner["geometrySHA256"] != pins["source.toml"]
            or physical["contractSHA256"] != inputs["criteria.json"]["r3SHA256"]
            or Fraction(physical["metresPerSourceUnitExact"]) != CALIBRATIONS[ship]):
        raise ValueError("Original, renderer, ownership and existing engineering authority differ")
    scale = float(Fraction(physical["metresPerSourceUnitExact"]))
    before_mesh = initial["nativeDesign"]
    parts = initial["parts"]
    for key in ("appearanceLicense", "appearanceSource", "materials", "textures", "paletteName"):
        if before_mesh[key] != original[key]:
            raise ValueError(f"Changed original appearance metadata {key}")
    faces, textures = list(before_mesh["faces"]), list(before_mesh["faceTextures"])
    for index, patch in PATCHES.items():
        part = parts[index]
        for offset, (old, new) in patch.items():
            face_index = part["faceStart"] + offset
            if [i - part["vertexStart"] for i in faces[face_index]] != old:
                raise ValueError("Unexpected current profile patch topology")
            faces[face_index] = [i + part["vertexStart"] for i in new]
            textures[face_index] = chart([before_mesh["vertices"][i] for i in faces[face_index]],
                                         before_mesh["faceMaterials"][face_index])
    local = runpy.run_path(str(HERE / "freeze-sh063-recesses.py"))["local"]
    source_parts = inputs["criteria.json"]["parts"]["originalPartRanges"]
    fixed = [p for p in parts if p["index"] not in (*TARGETS, 22, 23, 25, 26)]
    for part in fixed:
        if local(before_mesh, part) != local(original, source_parts[part["index"]]):
            raise ValueError("An exact original well, bridge, mount or support changed")
    after_mesh = {**before_mesh, "faces": faces, "faceTextures": textures}
    before = {**initial, "nativeDesign": before_mesh}
    after = {**initial, "nativeDesign": after_mesh}
    vertices = np.asarray(before_mesh["vertices"]) * scale
    triangles = vertices[faces]
    if len(triangles) != 512 or len(parts) != 31:
        raise ValueError("Expected the complete 512-triangle Goshawk")
    verify["verify_parts"](faces, triangles, parts)
    proofs = [plane_proof(original, before_mesh, after_mesh, parts[i], source_parts[i], scale)
              for i in TARGETS]
    if any(proof["currentNonSupportingFacets"] >= proof["priorNonSupportingFacets"]
           or proof["currentMaxVertexPlaneDeviationMetres"] > proof["priorMaxVertexPlaneDeviationMetres"] + 1e-8
           for proof in proofs):
        raise ValueError("The partial profile patch did not improve its own facet support")
    records = measure(original, before, after, parts, source_parts,
                      inputs["witness.json"], scale, verify["RAY_HIT"])
    mass = physical["dryMassKilograms"]
    centre = np.asarray(physical["centreOfMassMetres"])
    inertia = np.asarray(physical["inertiaAboutCentreOfMassKgM2"]).reshape(3, 3)
    radius = max(float(np.linalg.norm(vertex)) for vertex in vertices)
    if (mass <= 0 or not np.isfinite(centre).all() or not np.isfinite(inertia).all()
            or not np.allclose(inertia, inertia.T) or np.linalg.eigvalsh(inertia).min() <= 0
            or physical["occupiedPeopleCabinsPaidEquipmentGranted"]
            or physical["actualPortsProvidersOrServiceRightsGranted"]):
        raise ValueError("The dry authority or unissued occupancy/service boundary changed")
    engineering = dict(dryMassKilograms=mass, centreOfMassMetres=centre.tolist(),
                       dryInertiaKgM2=inertia.flatten().tolist(), bareHullRadiusMetres=radius,
                       fittedRadiusMetres=None, installedMount=None, roleBinding=None,
                       occupiedPeopleCabinsPaidEquipmentGranted=False, actualPortsProvidersOrServiceRightsGranted=False)
    for record in records:
        if (not no_regression(record["depthsMetres"])
                or record["parts"][2] not in (record["parts"][0], record["parts"][1])):
            raise ValueError("A profile or coupled control regressed in source depth or ownership")
        if record["kind"] == "retained":
            _, previous, current = record["depthsMetres"]
            if (record["parts"][1] != record["parts"][2] or (previous is None) != (current is None)
                    or current is not None and abs(current - previous) > 1e-8):
                raise ValueError("A retained contact changed its exact current outcome")
    if (Counter(p["kind"] for p in records) != {"retained": 78, "bridge-normal": 72,
                                               "well-normal": 720, "profile-radial": 1728,
                                               "facet-centroid": 64}
            or sum(p["geometryUnchanged"] for p in records) != 36):
        raise ValueError("Incomplete coupled profile obligations or unchanged-scope proof")
    helper["emit"](root, f"{ship}-collision-candidate.json", dict(
        schemaVersion=1, status="SOURCE_GEOMETRY_ONLY", catalogueID=ship, coordinateUnits="metres",
        forwardAxis="+Z", upAxis="+Y", calibration=physical["metresPerSourceUnitExact"],
        originalSourceSHA256=pins["source.toml"], parts=parts,
        nativeDesign={**after_mesh, "vertices": vertices.tolist()}))
    helper["emit"](root, f"{ship}-profile-witness.json", dict(
        inputSHA256=pins, convexity=proofs, checks=records, engineering=engineering,
        collisionSHA256=sha256((root / f"{ship}-collision-candidate.json").read_bytes()).hexdigest()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--ship", choices=tuple(PINS), default="SH010")
    args = parser.parse_args()
    main(args.directory, args.ship)
