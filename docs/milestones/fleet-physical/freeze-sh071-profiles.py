"""Use the remaining Griffon triangles to restore original vertical profile samples."""

from fractions import Fraction
from hashlib import sha256
import json
from pathlib import Path
import runpy
import argparse
import tomllib

import numpy as np


PINS = {
    "candidate.json": "b955640999b813290147c72fcdf1856cff5474aab1663e256a3ce34a2fb09397",
    "reference.json": "d098411e4ded08d59a6ba55ef86c958e2f6d66a7ea2f03f383fb71aaa4654e7f",
    "criteria.json": "437b427c2e4b7fa6420da014ce497ded6e078effb6ec6453db823617850db5a2",
    "witness.json": "b648f445c6ef502b114d6cc4c09763cbccd590b8b45bdeb080f7c6933d12fe73",
    "source.toml": "3f1d908400f032a2a90b8a4ee486c58e93368e4c49a1fa8a742ba52b7c9a80cc",
    "SH071.json": "4cf43c8db53f2e00177709bbd2761ef7360be2520a3576cb78a158bead2f31f7",
    "SH071.toml": "911a47c6e0044e0fc103951432f11b34bf3e2dcba83509f28c620d25e097e5c6",
}
MK2_PINS = {
    "candidate.json": "92c4b7a0535b9ba8be6ca3f119ff4d710c7d589dcc869ab4958289314bc98f24",
    "reference.json": "484dc62f693a95584220a8f6b55a48052d657e9e4bce6784acf801fae2012e9e",
    "criteria.json": "f019ba840a18493a97031b56333006f3a5cee2a699f998c227f76bbd2d15b0d4",
    "witness.json": "404021b9c860e7638271ac662307682ffffff37d2b543aef820d8065a601df33",
    "source.toml": "8ea9b1346142ef4c31e71b802258b859d54be0cdc12ac05bf3f6a02d55733d70",
    "SH072.json": "276171fa798535cc68af1bbce174f3defda19659c4a386113159557f73b91273",
    "SH072.toml": "376f8ee997f911c34ebd068636d9d37b9ee2c55131c38f3b3ae48fa308578ba0",
}
SPECTRE_PINS = {
    "candidate.json": "50082370ba60f98ddf49622fd2f87033dc8be84e0d9e24209dbfc96ebcc1af42",
    "reference.json": "0ceb33774f174b5cdd0b59a8b55c8f6e5c30edf94edca46937a3427bcd715a15",
    "criteria.json": "14e9252300b93490973338f16b40d8d9cef1dd3d021002827ad3ca79256466bb",
    "witness.json": "744bd86d447b8eeff041725c3867a353fd393c799ad9ba71283fd33f4b482e47",
    "source.toml": "f132d3229d67b58a29dfda4707dcbc17537163ab31da7d20a77645c8fcc3268e",
    "SH073.json": "023d8539a45e25169613eb7899d98d8d34264c81c3b75d9ae6c6fce5037acdbb",
    "SH073.toml": "d386ff366bf2ea46931b4f6ed503f46b80d2457718dff64729465df9bac4b62f",
}
HERE = Path(__file__).resolve().parent
GEOMETRY = ("vertices", "faces", "faceMaterials", "faceTextures")


def load(root, name, digest):
    data = (root / name).read_bytes()
    if sha256(data).hexdigest() != digest:
        raise ValueError(f"Changed input {name}")
    return tomllib.loads(data.decode()) if name.endswith(".toml") else json.loads(data)


def emit(root, name, data):
    with (root / name).open("x") as stream:
        json.dump(data, stream, sort_keys=True, separators=(",", ":"), allow_nan=False)
        stream.write("\n")


def restore_profile(current, original, retain_end_lower_chords, uv_for_face):
    points, faces, materials, textures = current
    points = list(points)
    inserted = {}
    for station in range(5):
        additions = [(1, 2, 3)]
        if not retain_end_lower_chords or station not in (0, 4):
            additions.append((4, 5, 9))
        for left, right, source in additions:
            inserted[tuple(sorted((6 * station + left, 6 * station + right)))] = len(points)
            points.append(original[0][12 * station + source])
    revised = []
    for face, material, texture in zip(faces, materials, textures, strict=True):
        pending = [(face, texture)]
        for edge, middle in inserted.items():
            split = []
            for triangle, chart in pending:
                for offset, (a, b) in enumerate(zip(triangle, triangle[1:] + triangle[:1])):
                    if tuple(sorted((a, b))) == edge:
                        c = triangle[(offset + 2) % 3]
                        for child in ([a, middle, c], [middle, b, c]):
                            split.append((child, uv_for_face([points[i] for i in child], material)))
                        break
                else:
                    split.append((triangle, chart))
            pending = split
        revised.extend((triangle, material, chart) for triangle, chart in pending)
    return points, *map(list, zip(*revised))


def profile_witness(original, baseline, candidate, ray_hit):
    """Sample every original azimuth at each station and intervening midplane."""
    sections = np.asarray(original).reshape(5, 12, 3)
    stations = list(sections) + list((sections[:-1] + sections[1:]) / 2)
    result = []
    for section in stations:
        center = section.mean(axis=0)
        for sample in section:
            outward = sample - center
            outward[2] = 0
            outward /= np.linalg.norm(outward)
            origin = center + 30 * outward
            origin[2] = sample[2]
            depths = [ray_hit(mesh, origin, -outward, 30) for mesh in (baseline, candidate)]
            result.append(dict(origin=origin.tolist(), direction=(-outward).tolist(),
                               hits=[None if hit is None else hit[1] for hit in depths]))
    return result


def main(root, ship="SH071"):
    pins = {"SH071": PINS, "SH072": MK2_PINS, "SH073": SPECTRE_PINS}[ship]
    records = {name: load(root, name, digest) for name, digest in pins.items()}
    source, packaged = records["source.toml"], records[f"{ship}.toml"]
    baseline, physical = records["candidate.json"], records[f"{ship}.json"]
    if (source["proposal"]["id"], packaged["id"], baseline["id"], physical["id"]) != (ship,) * 4:
        raise ValueError("Wrong original Griffon variant")
    reference = records["reference.json"]["nativeDesign"]
    if (source["design"] != packaged["design"] or source["nativeDesign"] != reference
            or baseline["originalSourceSHA256"] != pins["source.toml"]
            or physical["detailedSourceSHA256"] != pins["source.toml"]):
        raise ValueError("Inconsistent original render, collision or calibration")
    loft = runpy.run_path(str(HERE.parents[2] / "Tools/authoring/sh023_native_topology.py"))
    local = runpy.run_path(str(HERE / "freeze-sh063-recesses.py"))["local"]
    verify = runpy.run_path(str(HERE / "freeze-sh169-crest.py"))
    ray_hit = verify["RAY_HIT"]
    scale = float(Fraction(physical["metresPerSourceUnitExact"]))
    old = baseline["nativeDesign"]
    mesh = {key: [] if key in GEOMETRY else value for key, value in old.items()}
    parts = []
    source_parts = records["criteria.json"]["parts"]["originalPartRanges"]
    profile_rays = []
    for part in baseline["parts"]:
        index = part["index"]
        points, faces, materials, textures = local(old, part)
        if ship == "SH073" and index in (14, 15, 17, 18):
            if (points, faces, materials, textures) != local(reference, source_parts[index]):
                raise ValueError("A complete original Spectre drive changed")
        if index in (6, 11):
            original = local(reference, source_parts[index])
            old_triangles = (np.asarray(points) * scale)[faces]
            points, faces, materials, textures = restore_profile(
                (points, faces, materials, textures), original, index == 11, loft["uv_for_face"])
            new_triangles = (np.asarray(points) * scale)[faces]
            original_points = np.asarray(original[0]) * scale
            original_triangles = original_points[original[1]]
            for ray in profile_witness(original_points, old_triangles, new_triangles, ray_hit):
                source_hit = ray_hit(original_triangles, np.asarray(ray["origin"]),
                                     np.asarray(ray["direction"]), 30)
                profile_rays.append(dict(ray, part=index,
                                         source=None if source_hit is None else source_hit[1]))
        v, f = len(mesh["vertices"]), len(mesh["faces"])
        parts.append(dict(part, vertexStart=v, vertexCount=len(points),
                          faceStart=f, faceCount=len(faces)))
        mesh["vertices"].extend(points)
        mesh["faces"].extend([[i + v for i in face] for face in faces])
        mesh["faceMaterials"].extend(materials)
        mesh["faceTextures"].extend(textures)
    vertices = np.asarray(mesh["vertices"]) * scale
    triangles = vertices[mesh["faces"]]
    if len(triangles) != 512:
        raise ValueError("Expected the complete 512-triangle geometry")
    owners = verify["verify_parts"](mesh["faces"], triangles, parts)
    retained = records["witness.json"]
    all_faces = np.arange(len(triangles))
    by_name = {ray["name"]: ray for ray in retained["rays"]}
    for ray in retained["rays"]:
        verify["verify_ray"](ray, ray["hits"]["reference"], all_faces, triangles, owners, scale)
    for ray in retained["isolated"]:
        expected = ray["hits"]["reference"]
        subset = np.flatnonzero(owners == expected["part"])
        verify["verify_ray"](by_name[ray["name"]], expected, subset, triangles, owners, scale)
    for part in (6, 11):
        improved = False
        for ray in (probe for probe in profile_rays if probe["part"] == part):
            old_hit, new_hit = ray["hits"]
            source_hit = ray["source"]
            if None in (old_hit, new_hit, source_hit):
                raise ValueError("Profile probe lost its expected surface")
            old_error, new_error = abs(old_hit - source_hit), abs(new_hit - source_hit)
            if new_error > old_error + 1e-8:
                raise ValueError("Profile depth regressed relative to the original")
            improved |= old_error > new_error + 1e-8
        if not improved:
            raise ValueError(f"No measured profile improvement for part {part}")
    emit(root, f"{ship}-collision-candidate.json", dict(
        schemaVersion=1, status="SOURCE_GEOMETRY_ONLY", catalogueID=ship, coordinateUnits="metres",
        forwardAxis="+Z", upAxis="+Y", calibration=physical["metresPerSourceUnitExact"],
        parts=parts, nativeDesign={**mesh, "vertices": vertices.tolist()}))
    evidence = dict(
        inputSHA256=pins, renderFaces=len(packaged["design"]["faces"]),
        retainedChecks=len(retained["rays"]) + len(retained["isolated"]), profileRays=profile_rays,
        collisionSHA256=sha256((root / f"{ship}-collision-candidate.json").read_bytes()).hexdigest())
    if ship == "SH073":
        source_triangles = (np.asarray(reference["vertices"]) * scale)[reference["faces"]]
        old_triangles = (np.asarray(old["vertices"]) * scale)[old["faces"]]
        assembled = []
        for ray in profile_rays:
            hits = [ray_hit(t, np.asarray(ray["origin"]), np.asarray(ray["direction"]), 30)
                    for t in (source_triangles, old_triangles, triangles)]
            depths = [None if hit is None else hit[1] for hit in hits]
            if None in depths:
                raise ValueError("An assembled profile probe lost its expected surface")
            source_depth, before, after = depths
            if abs(after - source_depth) > abs(before - source_depth) + 1e-8:
                raise ValueError("An assembled profile depth regressed")
            assembled.append(dict(part=ray["part"], origin=ray["origin"],
                                  direction=ray["direction"], depthsMetres=depths))
        evidence["assembledProfileRays"] = assembled
    emit(root, f"{ship}-profile-witness.json", evidence)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--ship", choices=("SH071", "SH072", "SH073"), default="SH071")
    args = parser.parse_args()
    main(args.directory, args.ship)
