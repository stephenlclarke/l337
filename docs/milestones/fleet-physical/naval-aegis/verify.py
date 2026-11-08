"""Independent closure, physical join and finite-ray checks for the authored Aegis."""
from collections import Counter
from hashlib import sha256
from math import isclose
from pathlib import Path
import json


def difference(a, b):
    return tuple(x-y for x, y in zip(a, b))


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def cross(a, b):
    x,y,z = a
    u,v,w = b
    return y*w-z*v, z*u-x*w, x*v-y*u


def nearest(triangles, origin, direction, limit):
    hits = []
    for name, (a,b,c) in triangles:
        u, v = difference(b,a), difference(c,a)
        normal = cross(u,v)
        denominator = dot(normal,direction)
        if abs(denominator) < 1e-10:
            continue
        depth = dot(normal,difference(a,origin))/denominator
        if not 0 < depth <= limit:
            continue
        target = tuple(x+depth*y for x,y in zip(origin,direction))
        if all(dot(cross(difference(q,p),difference(target,p)),normal) >= -1e-9
               for p,q in ((a,b),(b,c),(c,a))):
            hits.append((depth,name))
    return min(hits, default=None)


data = Path(__file__).with_name("source.json").read_bytes()
source = json.loads(data)
mesh = source["nativeDesign"]
vertices, faces = mesh["vertices"], mesh["faces"]
assert len(vertices) == 160 and len(faces) == len(mesh["faceMaterials"]) == 288
cursor_v = cursor_f = 0
triangles = []
for part in source["parts"]:
    v, f = part["vertexStart"], part["faceStart"]
    assert (v,f) == (cursor_v,cursor_f)
    cursor_v += part["vertexCount"]
    cursor_f += part["faceCount"]
    local = faces[f:cursor_f]
    assert {i for face in local for i in face} == set(range(v,cursor_v))
    edges = Counter((a,b) for face in local for a,b in zip(face,face[1:]+face[:1]))
    assert all(n == edges[b,a] == 1 for (a,b),n in edges.items())
    volume = 0
    for a,b,c in ([vertices[i] for i in face] for face in local):
        normal = cross(difference(b,a),difference(c,a))
        assert dot(normal,normal) > 1e-10
        volume += dot(a,cross(b,c))/6
        triangles.append((part["name"],(a,b,c)))
    assert volume > 0
assert cursor_v == len(vertices) and cursor_f == len(faces)

controls = []
for x,y, expected in ((0,0,"armoured fuselage"),(-7.2,0,"port luminous aperture"),
                       (7.2,0,"starboard luminous aperture"),(0,2.65,"glazing"),
                       (-10.2,0,"port wing"),(10.2,0,"starboard wing"),(7.2,2,None),
                       (-7.2,2,None),(12,0,None),(0,3.4,None)):
    hit = nearest(triangles,(x,y,-20),(0,0,1),40)
    assert (hit[1] if hit else None) == expected, (x,y,hit)
    controls.append(dict(origin=[x,y,-20],hit=hit))
    if expected and "luminous" in expected:
        assert isclose(hit[0],7.05,abs_tol=1e-9)

joins = []
for first,second,x,z in (
    ("armoured fuselage","glazing",0,1),
    ("armoured fuselage","port wing",-3,0),
    ("armoured fuselage","starboard wing",3,0),
    ("port wing","port drive casing",-7.2,-6),
    ("starboard wing","starboard drive casing",7.2,-6),
    ("port drive casing","port luminous aperture",-7.2,-12.65),
    ("starboard drive casing","starboard luminous aperture",7.2,-12.65),
):
    intervals = []
    for name in (first,second):
        selected = [tri for tri in triangles if tri[0] == name]
        low = nearest(selected,(x,-10,z),(0,1,0),20)
        high = nearest(selected,(x,10,z),(0,-1,0),20)
        assert low and high
        intervals.append((low[0]-10,10-high[0]))
    overlap = min(a[1] for a in intervals) - max(a[0] for a in intervals)
    assert overlap > 0.05, (first,second,intervals)
    joins.append(dict(parts=[first,second],pointXZ=[x,z],overlap=overlap))

assert nearest(triangles,source["muzzle"],(0,0,1),100) is None
assert nearest(triangles,source["muzzle"],(0,0,-1),1)[1] == "armoured fuselage"
report = dict(sourceSHA256=sha256(data).hexdigest(), bounds=list(zip(
    map(min,zip(*vertices)),map(max,zip(*vertices)))),
    vertices=len(vertices), triangles=len(faces), closedParts=len(source["parts"]),
    collisionRays=controls, joins=joins, muzzleClearance=True)
print(json.dumps(report, indent=2))
