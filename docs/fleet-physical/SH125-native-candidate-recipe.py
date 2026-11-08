"""Complete SH125 native sampling candidate; G1 alone may generate/qualify it.

The actual pinned larvaal creator equations below retain FOUR closed shell
intervals, THREE actual open slots, inner faces, every rim and ONE complete core.
Only angular/latitude sampling is newly proposed. No part/material is removed,
no source unit/frame is inferred and no candidate is installed by this module.
"""

from collections import Counter
import hashlib
import math
import tomllib

SOURCE_SHA256 = "43340089afa8c01e2fe8e2482d9b8fa98e4735480ba45c65083d617e43bc66b1"
CREATOR_SHA256 = "a80f3606edd1ca0c9e4f0133136ab97257b07b2afe3efbbeb8a46960eb836476"
RESOURCE_SHA256 = "59f90d0c480f818ce6ae325c48347fa26989dbc7e2f90b82dc4acd4d5562c0ff"
R3_SHA256 = "66671c43983362d99fa0ecbc361fe224db0a7ac50799fd7d35cedb4d3fa4506e"

# NEW approximation only. No generated count or source-fidelity PASS exists.
ANGULAR_SIDES = 6
LATITUDE_STEPS = 4


def _build_geometry(creator):
    np, Hull, TAU = creator.np, creator.Hull, math.tau
    hull = Hull("larvaal")
    parts = []
    sides = ANGULAR_SIDES
    latitude_steps = LATITUDE_STEPS
    vertical_scale, cavity_radius, core_radius = .65, .62, .59
    centres, half_width = [-.2925, 0, .2925], .05525

    def triangle(a, b, c, material):
        if material==0:
            # Restrained jade variation makes the upright spin readable
            # without adding raised panels to the smooth alien shell.
            centre=np.array([hull.vertices[i] for i in (a,b,c)]).mean(axis=0)
            theta=math.atan2(centre[2],centre[0])
            variation=math.sin(3*theta+2.7*centre[1])*math.sin(5*theta-3*centre[1])
            material=3 if variation>.55 else 4 if variation<-.55 else 0
        hull.faces.append([a, b, c])
        hull.face_materials.append(material)

    def patch(y0, y1, horizontal_radius, vertical_radius, material, inward=False):
        """A meridian patch with explicit winding, including optional poles."""
        phi0, phi1 = math.asin(y0/vertical_radius), math.asin(y1/vertical_radius)
        steps=max(2,math.ceil((phi1-phi0)*latitude_steps/math.pi))
        rings=[]
        for phi in np.linspace(phi0,phi1,steps+1):
            y=vertical_radius*math.sin(phi)
            radius=horizontal_radius*math.cos(phi)
            offset=len(hull.vertices)
            if radius<1e-8:
                hull.vertices.append([0,y,0]);rings.append([offset])
            else:
                hull.vertices.extend([radius*math.cos(TAU*i/sides),y,
                                      radius*math.sin(TAU*i/sides)] for i in range(sides))
                rings.append(list(range(offset,offset+sides)))
        for low,high in zip(rings,rings[1:]):
            for i in range(sides):
                j=(i+1)%sides
                if len(low)==1:
                    faces=[(low[0],high[i],high[j])]
                elif len(high)==1:
                    faces=[(low[i],high[0],low[j])]
                else:
                    faces=[(low[i],high[i],high[j]),(low[i],high[j],low[j])]
                for a,b,c in faces:
                    triangle(a,c,b,material) if inward else triangle(a,b,c,material)
        return rings[0],rings[-1]

    # Four solid jade shell sections surround three real circumferential
    # openings. Their inner surfaces enclose a spherical cavity.
    intervals=[(-vertical_scale,centres[0]-half_width),
               (centres[0]+half_width,centres[1]-half_width),
               (centres[1]+half_width,centres[2]-half_width),
               (centres[2]+half_width,vertical_scale)]
    for lo,hi in intervals:
        first_vertex, first_face = len(hull.vertices), len(hull.faces)
        outer0,outer1=patch(lo,hi,1,vertical_scale,0)
        inner0,inner1=patch(max(lo,-cavity_radius),min(hi,cavity_radius),
                            cavity_radius,cavity_radius,1,True)
        for outer,inner,top in [(outer0,inner0,False),(outer1,inner1,True)]:
            if len(outer)==1 or len(inner)==1:
                continue
            for i in range(sides):
                j=(i+1)%sides
                if top:
                    triangle(outer[i],inner[i],inner[j],1)
                    triangle(outer[i],inner[j],outer[j],1)
                else:
                    triangle(outer[i],outer[j],inner[j],1)
                    triangle(outer[i],inner[j],inner[i],1)
        parts.append({
            "index": len(parts), "name": "closed jade shell source interval " + str(len(parts)),
            "vertexStart": first_vertex, "vertexCount": len(hull.vertices) - first_vertex,
            "faceStart": first_face, "faceCount": len(hull.faces) - first_face,
            "shellInterval": [lo, hi], "allowedSourceMaterials": [0, 1, 3, 4],
        })
    # One complete connected gold sphere is visible through all three slots.
    first_vertex, first_face = len(hull.vertices), len(hull.faces)
    patch(-core_radius,core_radius,core_radius,core_radius,2)
    parts.append({
        "index": 4, "name": "single complete gold core sphere",
        "vertexStart": first_vertex, "vertexCount": len(hull.vertices) - first_vertex,
        "faceStart": first_face, "faceCount": len(hull.faces) - first_face,
        "allowedSourceMaterials": [2],
    })
    hull.validate()
    assert len(centres) == 3 and centres[1] == 0
    # The core is genuinely spherical and fits inside the flattened shell.
    core_indices={i for f,m in zip(hull.faces,hull.face_materials) if m==2 for i in f}
    assert np.max(np.abs(np.linalg.norm(np.array(hull.vertices)[list(core_indices)],axis=1)-core_radius))<1e-10
    envelope=np.array(hull.vertices) / np.array([1,vertical_scale,1])
    assert np.linalg.norm(envelope,axis=1).max() <= 1.0000001
    return hull, parts


def build_candidate_native(creator, *, source_bytes, creator_bytes, resource_bytes):
    """Require the real per-ID inputs; return a candidate without file/runtime writes."""
    for label, data, expected in [
        ("original SH125 source", source_bytes, SOURCE_SHA256),
        ("original larvaal creator", creator_bytes, CREATOR_SHA256),
        ("current SH125 resource", resource_bytes, RESOURCE_SHA256),
    ]:
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(label + " changed; reconcile actual source before generation")
    source = tomllib.loads(source_bytes.decode("utf-8"))
    resource = tomllib.loads(resource_bytes.decode("utf-8"))
    if resource["id"] != "SH125" or source["proposal"]["id"] != "SH125":
        raise ValueError("Wrong actual drone source")
    for key in ("design", "nativeDesign"):
        if resource[key] != source[key]:
            raise ValueError("Packaged drone changed its original " + key)
    hull, parts = _build_geometry(creator)
    if len(parts) != 5 or any(p["vertexCount"] <= 0 or p["faceCount"] <= 0 for p in parts):
        raise ValueError("Candidate omitted a complete original shell/core part")
    if len(hull.faces) > 512:
        raise ValueError("Complete SH125 candidate exceeds512; no omission/cap waiver")
    directed = Counter((a, b) for face in hull.faces
                       for a, b in zip(face, face[1:] + face[:1]))
    if any(count != 1 or directed[(b, a)] != 1 for (a, b), count in directed.items()):
        raise ValueError("Candidate does not retain closed consistently wound parts")
    model = creator.design_dict(hull)
    original = source["nativeDesign"]
    geometry_keys = {"vertices", "faces", "faceMaterials"}
    if model.keys() != original.keys():
        raise ValueError("Candidate serializer changed source fields, including appearance/UV")
    for key in original.keys() - geometry_keys:
        if model[key] != original[key]:
            raise ValueError("Candidate changed source metadata/appearance: " + key)
    if set(model["faceMaterials"]) != set(original["faceMaterials"]):
        raise ValueError("Candidate lost an original jade/shadow/gold material")
    for part in parts:
        start, count = part["faceStart"], part["faceCount"]
        materials = set(model["faceMaterials"][start:start + count])
        if not materials or not materials.issubset(part["allowedSourceMaterials"]):
            raise ValueError("Candidate changed original part material ownership")
    return {
        "status": "GENERATED_CANDIDATE_ONLY_NOT_INSTALLED_OR_NATIVE_QUALIFIED",
        "id": "SH125", "originalSourceSHA256": SOURCE_SHA256,
        "r3SHA256": R3_SHA256, "nativeCandidate": model, "parts": parts,
        "coordinateRule": "Original coordinates; no rescale/recentre/unit inference",
        "unproven": [
            "complete source-profile/material-distribution/slot-and-cavity fidelity",
            "actual native collision, occupied voids and environment acceptance",
            "installed hardware/power and empty/loaded mass, COM and full tensor",
            "genuine autonomous production, EMP/wreck/acquisition/current-save journeys",
        ],
    }
