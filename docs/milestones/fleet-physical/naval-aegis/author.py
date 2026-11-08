"""Build the new project-owned Aegis naval prototype in authored metres."""
import json
from pathlib import Path

MATERIALS = [
    dict(name="Slate armour", colour=0x344659FF, emissive=False),
    dict(name="Brass identification panels", colour=0xC49A54FF, emissive=False),
    dict(name="Blue canopy", colour=0x5899BCFF, emissive=False),
    dict(name="Ion aperture", colour=0x77F3D3FF, emissive=True),
]

# Octagonal sections in counterclockwise XY order, viewed from positive Z.
SECTION = ((1, 0), (.74, .72), (0, 1), (-.74, .72),
           (-1, 0), (-.74, -.72), (0, -1), (.74, -.72))


def loft(stations):
    vertices = [[x * width + cx, y * height + cy, z]
                for z, cx, cy, width, height in stations for x, y in SECTION]
    faces = [[0, i+1, i] for i in range(1, 7)]
    for i in range(len(stations)-1):
        for j in range(8):
            a = i*8+j
            b = i*8+(j+1)%8
            faces.extend(([a, b, b+8], [a, b+8, a+8]))
    end = len(vertices)-8
    faces.extend([end, end+i, end+i+1] for i in range(1, 7))
    return vertices, faces


def wing(side):
    # The port and starboard wings use the same authored outline and thickness.
    outline = [(2.5, -7), (11.5, -9), (10.5, -4), (2.5, 6)]
    vertices = [[side*x, y, z] for y in (-.9, .55) for x, z in outline]
    faces = [[0, 1, 2], [0, 2, 3], [4, 6, 5], [4, 7, 6]]
    for a in range(4):
        b = (a+1)%4
        faces.extend(([b, a, a+4], [b, a+4, b+4]))
    return vertices, faces if side > 0 else [face[::-1] for face in faces]


def build():
    mesh = dict(vertices=[], faces=[], faceMaterials=[], materials=MATERIALS,
                license="MIT", source="Original L337 Aegis Prototype, authored for the naval hunt")
    parts = []

    def add(name, geometry, material):
        vertices, faces = geometry
        v, f = len(mesh["vertices"]), len(mesh["faces"])
        parts.append(dict(name=name, vertexStart=v, vertexCount=len(vertices),
                          faceStart=f, faceCount=len(faces)))
        mesh["vertices"].extend(vertices)
        mesh["faces"].extend([[v+i for i in face] for face in faces])
        mesh["faceMaterials"].extend([material]*len(faces))

    add("armoured fuselage", loft([(-12,0,0,3.8,1.65), (-7,0,0,5,2),
        (1,0,0,4.7,2.25), (10,0,0,2.4,1.4), (16,0,0,1.25,.72)]), 0)
    add("glazing", loft([(-3,0,1.6,1.5,.5), (1,0,2.05,1.9,1.1),
        (6,0,1.7,1.2,.5)]), 2)
    for name, side in (("port",-1),("starboard",1)):
        add(f"{name} wing", wing(side), 1)
        add(f"{name} drive casing", loft([(-12.8,side*7.2,0,1.4,1.25),
            (-7.4,side*7.2,0,1.6,1.25), (-4.4,side*7.2,0,1.05,.75)]), 0)
        add(f"{name} luminous aperture", loft([(-12.95,side*7.2,0,.95,.85),
            (-12.55,side*7.2,0,.95,.85)]), 3)

    return dict(schemaVersion=1, id="naval.aegis-prototype", name="Aegis Prototype",
                role="naval.experimental-warship-target", units="metres",
                forwardAxis="+Z", upAxis="+Y", nativeDesign=mesh, parts=parts,
                combat=dict(energy=252, bounty=0, speed=36, laserDamage=26, missiles=4,
                            ecm=True, bombImmune=True, plasmaImmune=True,
                            incomingLaserClasses=["military","naval"], laserDamageDivisor=4,
                            laserDamageRounding="floor", removalAxisLimit=57600),
                muzzle=[0,0,16.2], collision="nativeDesign")


if __name__ == "__main__":
    path = Path(__file__).with_name("source.json")
    path.write_text(json.dumps(build(), indent=2, allow_nan=False)+"\n")
