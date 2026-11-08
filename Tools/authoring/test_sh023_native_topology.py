"""Independent source correspondence checks for the bounded SH023 candidate."""
from collections import Counter
from fractions import Fraction as Q
from pathlib import Path
import json
import sys
import tomllib

from sh023_native_topology import OWNER_SHA, SOURCE_SHA, read

source, owner, output = map(Path, sys.argv[1:])
original = tomllib.loads(read(source, SOURCE_SHA).decode(), parse_float=Q)["nativeDesign"]
original_parts = json.loads(read(owner, OWNER_SHA))["models"]["nativeDesign"]["parts"]
candidate = json.loads(output.read_text(), parse_float=Q)
model = candidate["nativeDesign"]
changed = {0, 5, 13, 19, 22, 23, 25, 26}


def local(mesh, part):
    v, f = part["vertexStart"], part["faceStart"]
    end = f + part["faceCount"]
    return (mesh["vertices"][v:v + part["vertexCount"]],
            [[i - v for i in tri] for tri in mesh["faces"][f:end]],
            mesh["faceMaterials"][f:end], mesh["faceTextures"][f:end])


assert candidate["id"] == "SH023" and candidate["originalSourceSHA256"] == SOURCE_SHA
assert len(candidate["parts"]) == 27 and len(model["faces"]) == 512
assert all(len(f) == 3 for f in model["faces"])
assert set(model["faceMaterials"]) == set(original["faceMaterials"])
for key in original.keys() - {"vertices", "faces", "faceMaterials", "faceTextures"}:
    assert model[key] == original[key]
expected = {0: [3, 6, 4, 3, 4], 5: [3, 6, 4, 3, 4],
            13: [3, 6, 4, 3, 3], 19: [3, 5, 3, 3, 3],
            22: [6, 3], 23: [5, 3], 25: [6, 3], 26: [5, 3]}
triangles = Counter()
v0 = f0 = 0
for i, (part, old) in enumerate(zip(candidate["parts"], original_parts)):
    assert part["index"] == i and part["name"] == old["name"]
    assert (part["vertexStart"], part["faceStart"]) == (v0, f0)
    v0 += part["vertexCount"]
    f0 += part["faceCount"]
    points, faces, materials, uv = local(model, part)
    assert points == [original["vertices"][j] for j in part["originalVertexIDs"]]
    assert len(set(part["originalVertexIDs"])) == len(points)
    assert all(old["vertexStart"] <= j < old["vertexStart"] + old["vertexCount"]
               for j in part["originalVertexIDs"])
    assert {v for f in faces for v in f} == set(range(len(points)))
    edges = Counter((a, b) for f in faces for a, b in zip(f, f[1:] + f[:1]))
    assert all(count == 1 and edges[b, a] == 1 for (a, b), count in edges.items())
    assert len(faces) == 2 * len(points) - 4
    if i not in changed:
        assert local(model, part) == local(original, old)
        triangles["fixed"] += len(faces)
        continue
    by_z = Counter(p[2] for p in points)
    original_z = sorted({p[2] for p in local(original, old)[0]})
    assert sorted(by_z) == original_z
    assert [by_z[z] for z in original_z] == expected[i]
    assert set(materials) == set(local(original, old)[2])
    for face, material, mapping in zip(faces, materials, uv):
        a, b, c = [points[j] for j in face]
        e = [b[k] - a[k] for k in range(3)]
        g = [c[k] - a[k] for k in range(3)]
        n = [e[1]*g[2]-e[2]*g[1], e[2]*g[0]-e[0]*g[2], e[0]*g[1]-e[1]*g[0]]
        assert any(n)
        axis = max(range(3), key=lambda k: abs(n[k]))
        plane = ((2, 1), (0, 2), (0, 1))[axis]
        assert mapping["texture"] == (0 if material == 0 else 2)
        # At one serialized micro-unit, rounding and float ties do not
        # obscure a wrong plane, texture, vertex ordering or scale.
        assert all(abs(value - point[k]*Q(85,100)) <= Q(1,10**6)
                   for point, pair in zip((a,b,c), mapping["uv"]) for k,value in zip(plane,pair))
    triangles["drives" if i >= 22 else "bodies"] += len(faces)
assert (v0, f0) == (len(model["vertices"]), len(model["faces"]))
assert triangles == {"fixed": 324, "bodies": 136, "drives": 52}
print(json.dumps({"status": "SOURCE_TOPOLOGY_CHECKS_PASS_UNQUALIFIED",
                  "partCount": 27, "triangleBudget": triangles,
                  "fixedPartsExactIncludingUV": 19,
                  "allChangedVerticesOwnedByOriginal": True,
                  "allOriginalZStationsRetained": True}))
