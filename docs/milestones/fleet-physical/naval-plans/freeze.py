"""Freeze the SH124 geometry handoff and bound the SH125 lobe passage."""
from collections import Counter
from fractions import Fraction
from hashlib import sha256
import json
from pathlib import Path
import sys

PINS = {
    "warship.json": "00758885834dbfa03157f15a77e85aee054cf46367c205b9c31d5772e8b7c607",
    "warship-witness.json": "0819526f32a5487318c6dd9471e84e1f2e4e8d0ed9764d2538c938690befcae8",
    "warship-reference.json": "3d49ebbb5310f7d19fd793f20d16ac6711f6e1266ee94d0cc40fa13fa9236452",
    "drone-reference.json": "8588f0f5d92376d7253a5978413cd7ba3c2444dd51c54d4ba83d0bdb2e4f622b",
    "SH124-physical.json": "1e842cb7392dc8e9f6cbba555545de12eb8fc0eb9cf06df1bf32af1690b7067d",
    "SH125-physical.json": "52f994685dd828bc8b77ec73ad1ee92189a129c1e3eb3db9523c6c129120e182",
}
root = Path(sys.argv[1])


def read(name):
    data = (root / name).read_bytes()
    if sha256(data).hexdigest() != PINS[name]:
        raise ValueError(f"Changed source: {name}")
    return json.loads(data)


def emit(name, data):
    with (root / name).open("x") as stream:
        json.dump(data, stream, sort_keys=True, separators=(",", ":"), allow_nan=False)
        stream.write("\n")


warship = read("warship.json")
witness = read("warship-witness.json")
reference = read("warship-reference.json")["nativeDesign"]
drone = read("drone-reference.json")["nativeDesign"]
warship_record = read("SH124-physical.json")
drone_record = read("SH125-physical.json")
assert warship["originalSourceSHA256"] == warship_record["detailedSourceSHA256"]
warship_scale = Fraction(warship_record["metresPerSourceUnitExact"])
drone_scale = Fraction(drone_record["metresPerSourceUnitExact"])
assert warship_scale == Fraction(760,69) and drone_scale == Fraction(19000000,996381)

source = warship["nativeDesign"]
mesh = {**source, "vertices": [[coordinate * float(warship_scale) for coordinate in point]
                             for point in source["vertices"]]}
assert len(mesh["faces"]) == len(mesh["faceMaterials"]) == len(mesh["faceTextures"]) == 512
assert len(warship["parts"]) == 8
for part in warship["parts"]:
    f, v = part["faceStart"], part["vertexStart"]
    faces = mesh["faces"][f:f+part["faceCount"]]
    assert {i for face in faces for i in face} == set(range(v,v+part["vertexCount"]))
    edges = Counter((a,b) for face in faces for a,b in zip(face,face[1:]+face[:1]))
    assert all(n == edges[b,a] == 1 for (a,b),n in edges.items())
assert sum(r["count"] for r in witness["controls"] if r["name"]=="wall" and r["retained"]) == 8
assert sum(r["count"] for r in witness["controls"] if r["name"]=="inner-clearance" and r["retained"]) == 16

# The inner rim lies in the centre plane of each lobe. Vertex order follows the pinned torus ownership.
apertures = []
for start in (0,312):
    inner = reference["vertices"][start+4:start+192:8]
    assert len(inner) == 24 and all(y == 0 for _,y,_ in inner)
    width = max(Fraction(str(x)) for x,_,_ in inner) - min(Fraction(str(x)) for x,_,_ in inner)
    apertures.append(width * warship_scale)

# The gold core owns all six axial points. Their octahedron has minimum projected width 2r/sqrt(3).
core_indices = {i for face, material in zip(drone["faces"], drone["faceMaterials"])
                if material == 2 for i in face}
core_points = {tuple(Fraction(str(x)) for x in drone["vertices"][i]) for i in core_indices}
radius = Fraction(59,100)
for axis in range(3):
    for sign in (-1,1):
        assert tuple(sign*radius if k == axis else 0 for k in range(3)) in core_points
width_squared = (2 * radius * drone_scale)**2 / 3
assert all(width**2 < width_squared for width in apertures)

emit("SH124-collision-candidate.json", dict(
    schemaVersion=1, catalogueID="SH124", coordinateUnits="metres",
    forwardAxis="+Z", upAxis="+Y", calibration=str(warship_scale),
    status="SOURCE_GEOMETRY_ONLY", nativeDesign=mesh, parts=warship["parts"],
    sourceSHA256=warship["originalSourceSHA256"], inputSHA256=PINS["warship.json"]))
emit("mount-clearance.json", dict(
    inputs=PINS, originalLobeInnerWidthMetres=[float(w) for w in apertures],
    droneCoreMinimumProjectedWidthMetres=float(width_squared)**.5,
    droneCoreMinimumProjectedWidthSquaredExact=str(width_squared),
    conclusion="Original calibrated core cannot pass either lobe by straight fixed-attitude translation along Y",
    mountSource="Unissued"))
