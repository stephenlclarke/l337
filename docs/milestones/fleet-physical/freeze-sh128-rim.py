"""Recover original exposed luminous shoulders within each hull triangle budget."""

import argparse
from fractions import Fraction
from hashlib import sha256
from pathlib import Path
import runpy

import numpy as np


PINS = {
    "candidate.json": "9b7c403a7f61dec7d03db0e8ffaea77e0dd3197f8b48ebba907dd05547eba983",
    "reference.json": "48253b0e357e3cea78b25f254f88033a5902ac1e26ac8e828fb810625a94c67a",
    "criteria.json": "7c32b9668fee26e5495280a7bbb009d61fd38a1cf2afc0b4866690d9c3556b76",
    "witness.json": "2278e7651ee2c842944c6c9f22f8a49627e6b3f553acc64e3e082ffb2835add3",
    "source.toml": "f5b934ab51d55b29d5cdcfc112b9e5300030dbc2d9f0f33d5290562c1b2cd4aa",
    "SH128.json": "24b256fd113c5e4fe569d647d898f16bc438c22136d4b6adac3d835772d58d89",
    "SH128.toml": "6678128392d3d27d80463d0ae59ee62d8e26ef03efbe322c767953be8500ae8a",
    "prior-shoulder-candidate.json": "9ddd8945c830f83e438d9fc777124b17eff2adac02ea1ae5f1e4b46c2fd3a661",
    "prior-shoulder-witness.json": "25d4738cbdcffe58da258784ec8f19779da208122b4298f4ab626528990c4bf5",
}
LANNER_PINS = {
    "candidate.json": "a80cdbc0e7e0d9e76ec0aeec1d6a7081df0d1c22b3dbe709c2d8388dd248de5b",
    "reference.json": "e9204ee8e06aefaf52ec0c1d203fec40ea3dd3f9ed9ab505e3186c4fc3ead8ae",
    "criteria.json": "91dd513c4da5d7c21da44976018a238f94f844f843c53cbc1a92f6fb775db409",
    "witness.json": "eb4f1cfea790067f1b9ba6248e1545a819ff03ef1ab2d72d90aecf3c5ec9f009",
    "source.toml": "e55137ce5a91f7b2fc6521f3ebe11be865ee7b2c1467452844f33bb10edc90f6",
    "SH048.json": "cc12450d3978c0168bbdf7f0973457d2d2f1c59f3868309d642a991b37f0e64d",
    "SH048.toml": "614a29ae15792706a524deaee382c66318f6f05567a743ee4c2ffb28247215bf",
}
AUROCHS_PINS = {
    "candidate.json": "ed96d74073ec3baeb1d35f1544f7e7b02a07214b59d5959d326e396f7c333a44",
    "reference.json": "158ed9cb19787d1dfbc851045fc7a86b1ce7bc7557d7d67c2959c46a097f52c6",
    "criteria.json": "60b6243705733f250288ac877fdaac1a62115d3170d942bd3e550ad79347c5a5",
    "witness.json": "18b1d0fad18501a5446f74e9a57f060637cc87d51b96ab27ceb345b9a301f1fc",
    "source.toml": "5636b640e4ece28c7985d56f9643e6f6a24e011fd826ea085f1e811ccf5d30d7",
    "SH092.json": "e97aad550dd0f92d71135bfe802e6ffef0507c8a52e50e8a57ab26bbddb59710",
    "SH092.toml": "c914c1d28437e4109c59f63a94488c37906a10d2ec04024a97c603c348c4960f"
}
GATED_PINS = {
    "SH163": {
        "candidate.json": "7a47f8d199b4eb571e77842d3aacef57d6cbd5f67f58105755e5a8b629749989",
        "reference.json": "62e5d647bfb6942ad279eba56526e9baa91e73179175fc42ac7a5fe4e5389ad8",
        "criteria.json": "f96795ad8a7aad64b8e57c06e7e1a4a4a1675d5ce3db302b75d7b7bebb4a9b95",
        "witness.json": "278f1c3e8f6ef5f0060e8d82cd4181d8b4190789b0c90cab4bfe4f46f08e139b",
        "source.toml": "35c56db12a269759f3c87d95be388022146d95bfa4f8b8e4e09a4214cc84c9cc",
        "SH163.json": "1d1cfaaefa0d84022fcee69362407a37273df59101fb57c506c4807602b87af0",
        "SH163.toml": "eefd1e476efca3ece00b5d2ba418eeb40798a6420f785a5a19b05b60fdfeb479"
    },
    "SH165": {
        "candidate.json": "b8ade2d18d24caaf9bdb8e841e373134422012f93fe900a56d0217e0260837e9",
        "reference.json": "13d779bd44001ad138f101fa2aca91cd900b819c2527b716279df3a297486db4",
        "criteria.json": "5edd86466b049597c6fb4369fd771db228ff07450c534a75ddb79370f5d54a5c",
        "witness.json": "561a47c9c57f87e907d65954f8a271b82793bc80b07a00bfc685ebe71e1e4cd1",
        "source.toml": "21eb911f38e847414ac0dfc1a66e52d506673859d030acfc6f67526c6ab3d332",
        "SH165.json": "0df44a224fd267b6e5f39c456439ffaa82899181f8219b0b26f1045d0d773f00",
        "SH165.toml": "496fb92ab8ff57e2232fa32dd132e757719664223afa80b1ec9913e610f343b9"
    },
    "SH167": {
        "candidate.json": "bb7fb000183714b1ab23ae753820d65a1f5297eb0f9857a4ac132198533c3ac5",
        "reference.json": "01e431fca7bd4e2f86caa1b509e674628236b5a6d5fc321408225df1c3de6454",
        "criteria.json": "288f0a6f5410afe4deaa72485eec93c653c0abdd23e1cc295b3790ca792e035c",
        "witness.json": "8f1b9fd7cdbc6caed62e45bb9fb80064b785197eeb4640f030dbd8455d11b34a",
        "source.toml": "e3f38e953673b840106430b34385a1492e18c1bb2db3250619f380da6d4fdf4b",
        "SH167.json": "249bc66ab88bd99f634c5e0489f03ccd0fab4b65e7b88d60f45af9a0f51e5918",
        "SH167.toml": "f140c3d322aa63e53b998e68118edc26471e0632987bbec9a0840ffd907baa0b"
    }
}
HERE = Path(__file__).resolve().parent


def split(current, source_point, edge, uv):
    points, faces, materials, textures = current
    middle = len(points)
    points = points + [source_point]
    result = []
    uses = 0
    for face, material, texture in zip(faces, materials, textures, strict=True):
        for offset, (a, b) in enumerate(zip(face, face[1:] + face[:1])):
            if tuple(sorted((a, b))) == edge:
                uses += 1
                c = face[(offset + 2) % 3]
                for child in ([a, middle, c], [middle, b, c]):
                    result.append((child, material, uv([points[i] for i in child], material)))
                break
        else:
            result.append((face, material, texture))
    if uses != 2:
        raise ValueError("A closed source chord must have two incident faces")
    return points, *map(list, zip(*result))


def same_depth(a, b):
    if a is None or b is None:
        return a is None and b is None
    return abs(a - b) < 1e-8


def no_depth_regression(depths):
    reference, before, after = depths
    if same_depth(after, before) or same_depth(after, reference):
        return True
    if reference is None or after is None:
        return False
    return before is None or abs(after - reference) <= abs(before - reference) + 1e-8


def drive_surfaces(part, source_parts, old_parts, owners, surfaces):
    source_faces = [i for p in source_parts[part - 1:part + 1]
                    for i in range(p["faceStart"], p["faceStart"] + p["faceCount"])]
    old_faces = [i for p in old_parts[part - 1:part + 1]
                 for i in range(p["faceStart"], p["faceStart"] + p["faceCount"])]
    drive_faces = np.flatnonzero(np.isin(owners, (part - 1, part)))
    return (surfaces[0][source_faces], surfaces[1][old_faces], surfaces[2][drive_faces]), drive_faces


def check_drive_envelopes(parts, source_parts, old_parts, owners, surfaces, scale, ray_hit):
    checks = []
    for part in parts:
        isolated, _ = drive_surfaces(part, source_parts, old_parts, owners, surfaces)
        recess = source_parts[part]
        source = surfaces[0][recess["faceStart"]:recess["faceStart"] + recess["faceCount"]].reshape(-1, 3)
        low, high = source.min(axis=0) / scale, source.max(axis=0) / scale
        center = (low + high) / 2
        radius = (high[1] - low[1]) / 2
        for degrees in range(0, 360, 5):
            angle = np.deg2rad(degrees)
            for fraction in (.95, .99, 1.03):
                origin = center + radius * fraction * np.array([np.cos(angle), np.sin(angle), 0])
                origin[2] = low[2] - .1
                depths = []
                assembled = []
                for meshes, output in ((isolated, depths), (surfaces, assembled)):
                    for mesh in meshes:
                        hit = ray_hit(mesh, origin * scale, np.array([0, 0, 1]), .15 * scale)
                        output.append(None if hit is None else hit[1])
                    if not no_depth_regression(output):
                        raise ValueError(f"A drive-envelope probe regressed at part {part}, "
                                         f"angle {degrees}, radius {fraction}: {output}")
                checks.append(dict(part=part, degrees=degrees, radiusFraction=fraction,
                                   originMetres=(origin * scale).tolist(),
                                   depthsMetres=depths, assembledDepthsMetres=assembled))
    return checks


def correct_octagonal_quadrant(current, original, upper_left, chart):
    # Correct both rings of the protruding octagonal diagonal. The exposed
    # ring then gains its missing source point through the normal edge split.
    cached_index, source_index = (3, 4) if upper_left else (1, 2)
    points, faces, materials, textures = current
    points = list(points)
    points[cached_index] = original[0][source_index]
    points[cached_index + 8] = original[0][source_index + 12]
    moved = (cached_index, cached_index + 8)
    textures = [chart([points[i] for i in face], material)
                if any(i in face for i in moved) else uv
                for face, material, uv in zip(faces, materials, textures, strict=True)]
    return points, faces, materials, textures


def main(root, ship="SH128"):
    helper = runpy.run_path(str(HERE / "freeze-sh071-profiles.py"))
    pins = {"SH128": PINS, "SH048": LANNER_PINS, "SH092": AUROCHS_PINS,
            **GATED_PINS}[ship]
    inputs = {name: helper["load"](root, name, digest) for name, digest in pins.items()}
    local = runpy.run_path(str(HERE / "freeze-sh063-recesses.py"))["local"]
    verify = runpy.run_path(str(HERE / "freeze-sh169-crest.py"))
    chart = runpy.run_path(str(HERE.parents[2] / "Tools/authoring/sh023_native_topology.py"))["uv_for_face"]
    baseline = inputs["candidate.json"]
    source, resource = inputs["source.toml"], inputs[f"{ship}.toml"]
    original = inputs["reference.json"]["nativeDesign"]
    physical = inputs[f"{ship}.json"]
    if (source["proposal"]["id"], resource["id"], baseline["id"], physical["id"]) != (ship,) * 4:
        raise ValueError("Wrong original hull input")
    if (source["design"] != resource["design"] or source["nativeDesign"] != original
            or baseline["originalSourceSHA256"] != pins["source.toml"]
            or physical["detailedSourceSHA256"] != pins["source.toml"]):
        raise ValueError("Source, render and engineering do not bind the same hull")
    scale = float(Fraction(physical["metresPerSourceUnitExact"]))
    old = baseline["nativeDesign"]
    source_parts = inputs["criteria.json"]["parts"]["originalPartRanges"]
    mesh = {key: [] if key in ("vertices", "faces", "faceMaterials", "faceTextures") else value
            for key, value in old.items()}
    parts = []
    points_to_check = []
    if ship == "SH128":
        selections_by_part = {15: [(1, (0, 1))], 18: [(5, (3, 4))]}
    elif ship == "SH048":
        selections_by_part = {10: [(1, (0, 1)), (5, (2, 3))],
                              13: [(1, (0, 1)), (5, (2, 3))]}
    elif ship == "SH092":
        # Restore the same five angular samples on both drives. The lower
        # apex and inboard ring remain cached within this triangle budget.
        shoulder_points = [(1, (0, 1)), (3, (1, 2)), (5, (2, 3)),
                           (7, (3, 4)), (11, (0, 5))]
        selections_by_part = {14: shoulder_points, 17: shoulder_points}
    else:
        negative = 17 if ship == "SH163" else 13
        selections_by_part = {negative: [(5, (3, 4))], negative + 3: [(1, (0, 1))]}
    for part in baseline["parts"]:
        current = local(old, part)
        if (ship == "SH128" or ship in GATED_PINS) and part["index"] in selections_by_part:
            upper_left = (part["index"] == 18 if ship == "SH128"
                          else part["index"] == min(selections_by_part))
            current = correct_octagonal_quadrant(
                current, local(original, source_parts[part["index"]]), upper_left, chart)
        is_checked_casing = part["index"] in {i - 1 for i in selections_by_part}
        if (ship in ("SH128", "SH092") or ship in GATED_PINS) and is_checked_casing:
            if current != local(original, source_parts[part["index"]]):
                raise ValueError("An original propulsion casing changed")
        selections = selections_by_part.get(part["index"], [])
        if selections:
            original_points = local(original, source_parts[part["index"]])[0]
            center = (np.array([-1.178 if part["index"] == 15 else 1.178, 0, original_points[0][2]])
                      if ship == "SH128" else np.asarray(original_points[:12]).mean(axis=0))
            for source_index, edge in selections:
                source_point = original_points[source_index]
                points_to_check.append((part["index"], np.asarray(source_point), center))
                current = split(current, source_point, edge, chart)
        points, faces, materials, textures = current
        v, f = len(mesh["vertices"]), len(mesh["faces"])
        parts.append(dict(part, vertexStart=v, vertexCount=len(points),
                          faceStart=f, faceCount=len(faces)))
        mesh["vertices"].extend(points)
        mesh["faces"].extend([[v + i for i in face] for face in faces])
        mesh["faceMaterials"].extend(materials)
        mesh["faceTextures"].extend(textures)
    vertices = np.asarray(mesh["vertices"]) * scale
    triangles = vertices[mesh["faces"]]
    expected_parts = 21 if ship in GATED_PINS else (19 if ship == "SH128" else 18)
    if len(triangles) != 512 or len(parts) != expected_parts:
        raise ValueError("Expected complete 512-triangle hull")
    owners = verify["verify_parts"](mesh["faces"], triangles, parts)
    all_faces = np.arange(len(triangles))
    witness = inputs["witness.json"]
    by_name = {ray["name"]: ray for ray in witness["rays"]}
    for ray in witness["rays"]:
        verify["verify_ray"](ray, ray["hits"]["reference"], all_faces, triangles, owners, scale)
    for ray in witness["isolated"]:
        expected = ray["hits"]["reference"]
        verify["verify_ray"](by_name[ray["name"]], expected,
                             np.flatnonzero(owners == expected["part"]), triangles, owners, scale)
    old_triangles = (np.asarray(old["vertices"]) * scale)[old["faces"]]
    original_triangles = (np.asarray(original["vertices"]) * scale)[original["faces"]]
    probes = []
    for part, point, center in points_to_check:
        direction = point - center
        for fraction in (.97, .98, .99, 1.03):
            origin = center + fraction * direction
            origin[2] -= .1
            surfaces = (original_triangles, old_triangles, triangles)
            assembled_depths = None
            if ship == "SH092":
                # The lower inner rim overlaps a separately simplified pod.
                # Check the drive itself and retain the assembled outcome too.
                assembled_hits = [verify["RAY_HIT"](t, origin * scale, np.array([0, 0, 1]), .15 * scale)
                                  for t in surfaces]
                assembled_depths = [None if hit is None else hit[1] for hit in assembled_hits]
                surfaces, drive_faces = drive_surfaces(
                    part, source_parts, baseline["parts"], owners, surfaces)
                before, after = assembled_depths[1:]
                reference_depth = assembled_depths[0]
                if not (same_depth(after, before) or same_depth(after, reference_depth)):
                    raise ValueError("The assembled shoulder contact regressed")
            hits = [verify["RAY_HIT"](t, origin * scale, np.array([0, 0, 1]), .15 * scale)
                    for t in surfaces]
            depths = [None if hit is None else hit[1] for hit in hits]
            if fraction < 1:
                if (hits[0] is None or hits[2] is None or
                        abs(depths[0] - depths[2]) > 1e-8 or
                        (hits[1] is not None and depths[1] <= depths[2] + 1e-8)):
                    raise ValueError(f"The source shoulder was not recovered at part {part}, "
                                     f"point {point.tolist()}, fraction {fraction}: {depths}")
            elif (any(hit is None for hit in hits) or
                  max(depths) - min(depths) > 1e-8 or
                  owners[drive_faces[hits[2][0]] if ship == "SH092" else hits[2][0]] != part - 1):
                raise ValueError("The casing control outside the shoulder changed")
            probe = dict(part=part, fraction=fraction,
                         originMetres=(origin * scale).tolist(), depthsMetres=depths)
            if assembled_depths is not None:
                probe["assembledDepthsMetres"] = assembled_depths
            probes.append(probe)
    helper["emit"](root, f"{ship}-collision-candidate.json", dict(
        status="SOURCE_GEOMETRY_ONLY", catalogueID=ship, coordinateUnits="metres",
        forwardAxis="+Z", upAxis="+Y", calibration=physical["metresPerSourceUnitExact"],
        parts=parts, nativeDesign={**mesh, "vertices": vertices.tolist()}))
    evidence = dict(
        inputSHA256=pins, shoulderProbes=probes,
        retainedChecks=len(witness["rays"]) + len(witness["isolated"]),
        collisionSHA256=sha256((root / f"{ship}-collision-candidate.json").read_bytes()).hexdigest())
    if ship in ("SH128", "SH092") or ship in GATED_PINS:
        evidence["driveEnvelopeProbes"] = check_drive_envelopes(
            tuple(selections_by_part), source_parts, baseline["parts"], owners,
            (original_triangles, old_triangles, triangles), scale, verify["RAY_HIT"])
    if ship == "SH128":
        prior = inputs["prior-shoulder-candidate.json"]
        prior_witness = inputs["prior-shoulder-witness.json"]
        if (prior["catalogueID"] != ship or prior["calibration"] != physical["metresPerSourceUnitExact"]
                or prior_witness["collisionSHA256"] != pins["prior-shoulder-candidate.json"]):
            raise ValueError("The earlier shoulder control is not the same Boar source")
        for before, after in zip(prior_witness["shoulderProbes"], probes, strict=True):
            if (before["originMetres"] != after["originMetres"]
                    or not same_depth(before["depthsMetres"][2], after["depthsMetres"][2])):
                raise ValueError("An earlier restored shoulder contact changed")
        prior_triangles = np.asarray(prior["nativeDesign"]["vertices"])[prior["nativeDesign"]["faces"]]
        evidence["priorShoulderEnvelopeProbes"] = check_drive_envelopes(
            tuple(selections_by_part), source_parts, prior["parts"], owners,
            (original_triangles, prior_triangles, triangles), scale, verify["RAY_HIT"])
    helper["emit"](root, f"{ship}-rim-witness.json", evidence)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--ship", choices=("SH128", "SH048", "SH092", *GATED_PINS), default="SH128")
    args = parser.parse_args()
    main(args.directory, args.ship)
