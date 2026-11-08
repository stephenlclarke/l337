"""Independent, bounded SH058 original-reference derivation. Source proposal; no implicit START.

No production geometry, renderer or collision module is imported. Point contact uses plane /
barycentric interval clipping. Positive-radius contact uses convex point-to-triangle
projection and monotone-derivative/root bisection, not the production face/edge/sphere
intersection decomposition. Every query and triangle predicate is charged globally.
"""
from decimal import Decimal as D, localcontext
from pathlib import Path
import hashlib
import json
import math
import sys
import tomllib
import copy

NATIVE_SHA = '13ef038a1ab17ffb777bd43f6a63b0a973bbea8bfd6076248cc14f8f1d49b2b8'
CRITERIA_SHA = 'd5eb36879b678ca262824e023cedb8c85c848da529cfb386c65bb34252787d3c'
ITERATIONS = 128


class Invalid(Exception):
    pass


def require(value, reason):
    if not value:
        raise Invalid(reason)


def unique(pairs):
    out = {}
    for key, value in pairs:
        require(key not in out, 'Duplicate JSON key')
        out[key] = value
    return out


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False) + '\n').encode()


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read_pin(pin, maximum=8 * 1024 * 1024):
    path = Path(pin['path'])
    require(not path.is_symlink() and path.is_file(), 'Not a regular immutable input')
    require(0 < pin['bytes'] <= maximum, 'Input byte bound')
    with path.open('rb') as stream:
        raw = stream.read(pin['bytes'] + 1)
    require(len(raw) == pin['bytes'] and sha(raw) == pin['sha256'], 'Input identity changed')
    return raw


def add(a, b): return tuple(x + y for x, y in zip(a, b))
def sub(a, b): return tuple(x - y for x, y in zip(a, b))
def mul(a, s): return tuple(x * s for x in a)
def dot(a, b): return sum((x * y for x, y in zip(a, b)), D(0))
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def norm(a): return dot(a, a).sqrt()
def unit(a):
    length = norm(a)
    require(length > 0, 'Zero direction / degenerate original feature')
    return mul(a, 1 / length)
def point(values):
    require(len(values) == 3, 'Reference point arity')
    p = tuple(D(str(v)) for v in values)
    require(all(v.is_finite() for v in p), 'Nonfinite reference point')
    return p


class Accounting:
    def __init__(self):
        self.rays = set()
        self.primitives = set()
        self.projections = 0
        self.completed_rays = set()
        self.completed_primitives = set()
        self.active = dict(stage='input-authentication', callID=None, product=None, triangleAddress=None)

    def context(self, stage, call_id=None, product=None, triangle=None):
        self.active = dict(stage=stage, callID=call_id, product=product, triangleAddress=triangle)

    def ray(self, key, product):
        self.context('reference-query', key, product)
        require(key not in self.rays and len(self.rays) < 251, 'Unscheduled / excess reference query')
        self.rays.add(key)

    def triangle(self, key, index):
        self.active.update(stage='reference-triangle-predicate', callID=key, triangleAddress=index)
        pair = (key, index)
        require(pair not in self.primitives and len(self.primitives) < 12849,
                'Unscheduled / excess reference triangle predicate')
        self.primitives.add(pair)

    def projection(self):
        # At most 262 projections per reference triangle predicate, including endpoints.
        self.projections += 1
        require(self.projections <= 12849 * 262, 'Reference projection evaluation bound')


def closest(p, tri, budget):
    """Independent convex quadratic projection: feasible plane solution + 3 segments."""
    budget.projection()
    a, b, c = tri
    e, f, w = sub(b, a), sub(c, a), sub(p, a)
    ee, ef, ff = dot(e, e), dot(e, f), dot(f, f)
    determinant = ee * ff - ef * ef
    require(determinant > 0, 'Degenerate original triangle')
    u = (dot(w, e) * ff - dot(w, f) * ef) / determinant
    v = (dot(w, f) * ee - dot(w, e) * ef) / determinant
    options = []
    if u >= 0 and v >= 0 and u + v <= 1:
        options.append(add(a, add(mul(e, u), mul(f, v))))
    for start, end in [(a, b), (b, c), (c, a)]:
        edge = sub(end, start)
        denominator = dot(edge, edge)
        require(denominator > 0, 'Zero original edge')
        fraction = max(D(0), min(D(1), dot(sub(p, start), edge) / denominator))
        options.append(add(start, mul(edge, fraction)))
    return min(options, key=lambda q: dot(sub(p, q), sub(p, q)))


def barycentric(p, tri):
    a, b, c = tri
    e, f, w = sub(b, a), sub(c, a), sub(p, a)
    ee, ef, ff = dot(e, e), dot(e, f), dot(f, f)
    denominator = ee * ff - ef * ef
    require(denominator > 0, 'Degenerate original triangle')
    return ((dot(w, e)*ff-dot(w, f)*ef)/denominator,
            (dot(w, f)*ee-dot(w, e)*ef)/denominator)


def point_contact(ray, tri):
    o, d, limit = ray['origin'], ray['direction'], ray['range']
    normal = cross(sub(tri[1], tri[0]), sub(tri[2], tri[0]))
    require(dot(normal, normal) > 0, 'Degenerate original triangle')
    denominator, numerator = dot(normal, d), dot(normal, sub(tri[0], o))
    epsilon = D('1e-40') * max(D(1), norm(normal))
    if abs(denominator) > epsilon:
        t = numerator / denominator
        if t < -D('1e-30') or t > limit + D('1e-30'):
            return None
        t = max(D(0), min(limit, t))
        u, v = barycentric(add(o, mul(d, t)), tri)
        return t if u >= -D('1e-30') and v >= -D('1e-30') and u+v <= 1+D('1e-30') else None
    if abs(numerator) > epsilon:
        return None
    # Coplanar closed triangle: clip the ray interval by its three affine barycentric constraints.
    u0, v0 = barycentric(o, tri)
    u1, v1 = barycentric(add(o, d), tri)
    lo, hi = D(0), limit
    for intercept, slope in [(u0, u1-u0), (v0, v1-v0), (1-u0-v0, -(u1-u0)-(v1-v0))]:
        if abs(slope) <= D('1e-40'):
            if intercept < -D('1e-30'): return None
        elif slope > 0:
            lo = max(lo, -intercept/slope)
        else:
            hi = min(hi, -intercept/slope)
    return max(D(0), lo) if lo <= hi + D('1e-30') else None


def sphere_contact(ray, tri, budget):
    """Distance to a closed convex triangle is convex along the fixed ray.

    Its squared-distance derivative is 2*(p-project(p)).direction. Find its minimum
    by monotone derivative, then the first radius crossing on the decreasing branch.
    Fixed 128+128 bisections solve one predetermined witness; no witness search occurs.
    Tangency indistinguishable at the declared high-precision bound fails, never skips.
    """
    o, direction, limit, radius = (ray[k] for k in ['origin', 'direction', 'range', 'radius'])
    def value(t):
        p = add(o, mul(direction, t))
        delta = sub(p, closest(p, tri, budget))
        return dot(delta, delta)-radius*radius, 2*dot(delta, direction)
    initial, derivative = value(D(0))
    if initial <= 0: return D(0)
    if derivative >= 0: return None
    final, final_derivative = value(limit)
    if final_derivative <= 0:
        minimum_t, minimum = limit, final
    else:
        lo, hi = D(0), limit
        for _ in range(ITERATIONS):
            middle = (lo+hi)/2
            if value(middle)[1] < 0: lo = middle
            else: hi = middle
        minimum_t = (lo+hi)/2
        minimum = value(minimum_t)[0]
    uncertainty = D('1e-32') * max(D(1), radius*radius, limit*limit)
    if minimum > uncertainty: return None
    require(minimum < -uncertainty, 'Ambiguous finite-radius tangent; qualification unissued')
    lo, hi = D(0), minimum_t
    for _ in range(ITERATIONS):
        middle = (lo+hi)/2
        if value(middle)[0] > 0: lo = middle
        else: hi = middle
    return hi


def nearest(key, ray, triangles, face_ids, budget, product='DIMENSIONLESS_ANALYTIC'):
    budget.ray(key, product)
    hits = []
    for index in face_ids:
        budget.triangle(key, index)
        tri = triangles[index]
        t = point_contact(ray, tri) if ray['radius'] == 0 else sphere_contact(ray, tri, budget)
        budget.completed_primitives.add((key, index))
        if t is not None: hits.append((t, index))
    if not hits:
        budget.completed_rays.add(key)
        budget.active.update(stage='reference-query-complete')
        return None, []
    distance = min(t for t, _ in hits)
    tie = D('1e-8') + ray['range'] * D('1e-10')
    result = distance, sorted(i for t, i in hits if abs(t-distance) <= tie)
    budget.completed_rays.add(key)
    budget.active.update(stage='reference-query-complete')
    return result


def quantized_ray(origin, direction, limit, radius):
    """Freeze IEEE-double inputs first; reference predicates see the identical binary ray."""
    def q(x):
        f = float(x)
        require(math.isfinite(f), 'Nonfinite frozen witness')
        return D.from_float(f)
    result = dict(origin=tuple(q(x) for x in origin), direction=tuple(q(x) for x in direction),
                  range=q(limit), radius=q(radius))
    require(result['range'] > 0 and result['radius'] >= 0, 'Invalid frozen range/radius')
    require(abs(norm(result['direction'])-1) <= D('1e-14'), 'Nonunit frozen direction')
    return result


def analytic_controls(budget):
    # Dimensionless mathematical triangles, not invented ship coordinates or physical receipts.
    tri = tuple(point(p) for p in [[0,0,0],[2,0,0],[0,2,0]])
    cases = [
        ([.5,.5,1],[0,0,-1],2,0,D(1)), ([3,3,1],[0,0,-1],2,0,None),
        ([1,0,1],[0,0,-1],2,.25,D('.75')), ([0,0,1],[0,0,-1],2,.25,D('.75')),
        ([3,3,1],[0,0,-1],2,.25,None), ([.5,.5,.1],[0,0,-1],2,.25,D(0)),
        ([-1,0,0],[1,0,0],4,0,D(1)), ([.5,.5,1],[1,0,0],4,0,None),
        ([1,-.125,1],[0,0,-1],2,.25,1-D(3).sqrt()/8),
        ([-.125,-.125,1],[0,0,-1],2,.25,1-D(2).sqrt()/8),
        ([.5,.5,1],[0,0,-1],.5,0,None), ([.5,.5,1],[0,0,-1],2,0,D(1)),
    ]
    records = []
    for i, (o,d,limit,radius,expected) in enumerate(cases):
        ids = [0,1] if i == 11 else [0]
        actual, ties = nearest('ANALYTIC_%02d' % i,
            quantized_ray(point(o),point(d),D(str(limit)),D(str(radius))), [tri,tri], ids, budget)
        budget.active.update(stage='analytic-control-assertion')
        require((actual is None) == (expected is None), 'Independent analytic control hit class')
        if expected is not None: require(abs(actual-expected) <= D('1e-20'), 'Independent analytic control distance')
        if i == 11: require(ties == [0,1], 'Independent analytic tie control')
        records.append(dict(id='ANALYTIC_%02d' % i, passed=True))
    return records


def serial(value):
    if isinstance(value,D): return float(value)
    if isinstance(value,dict): return {k:serial(v) for k,v in value.items()}
    if isinstance(value,(list,tuple)): return [serial(v) for v in value]
    return value


def independent_successor(inputs, original):
    """Source-equation reconstruction; no generated/current mesh or authoring-code input."""
    detailed = tomllib.loads(read_pin(inputs['originalDetailed']).decode(), parse_float=D)['design']
    parts = json.loads(read_pin(inputs['detailedParts']), object_pairs_hook=unique)['design']
    native_parts = json.loads(read_pin(inputs['nativeParts']), object_pairs_hook=unique)
    if isinstance(native_parts, dict): native_parts = native_parts['nativeDesign']
    def named(rows, name):
        found = [x for x in rows if x['name'] == name]
        require(len(found) == 1, 'Independent source part missing/ambiguous: '+name)
        return found[0]
    def points(design, part):
        return [point(x) for x in design['vertices'][part['vertexStart']:part['vertexStart']+part['vertexCount']]]
    def bounds(points):
        return tuple(min(p[i] for p in points) for i in range(3)), tuple(max(p[i] for p in points) for i in range(3))
    design = copy.deepcopy(original['nativeDesign'])
    design['vertices'] = [point(v) for v in design['vertices']]
    origins=[dict(kind='originalNative',part='ORIGINAL_NATIVE',sourceIndex=i) for i in range(len(design['vertices']))]
    canopy = named(native_parts,'raised command beam bridge pressure canopy')
    low,high = bounds(points(design,canopy)); equator=(low[1]+high[1])/2
    base_low,base_high=bounds(points(design,named(native_parts,'broad freight base')))
    base=(base_low[1]+base_high[1])/2
    brace=named(parts,'raised command beam bridge centre brace')
    brlow,brhigh=bounds(points(detailed,brace)); width=brhigh[0]-brlow[0]; depth=brhigh[1]-brlow[1]
    require(width>0 and depth>0 and base<equator-depth,'Independent source support dimensions')
    def uv(vertices,material):
        a,b,c=vertices; normal=cross(sub(b,a),sub(c,a)); axis=max(range(3),key=lambda i:abs(normal[i]))
        plane=((2,1),(0,2),(0,1))[axis]
        return dict(texture=1 if material==1 else 2, uv=[[float((p[i]*D('0.16')).quantize(D('0.0000001'))) for i in plane] for p in vertices])
    opaque=[]
    for index in range(canopy['faceStart'],canopy['faceStart']+canopy['faceCount']):
        tri=[design['vertices'][i] for i in design['faces'][index]]
        if all(p[1]<=equator for p in tri):
            opaque.append(index);design['faceMaterials'][index]=1;design['faceTextures'][index]=uv(tri,1)
    require(opaque and any(design['faceMaterials'][i]==5 for i in range(canopy['faceStart'],canopy['faceStart']+canopy['faceCount'])),'Both opaque foundation and glazing retained')
    selectors={}
    def insert(name,vertices,faces,materials,textures,source_indices=None):
        first=len(design['faces']);offset=len(design['vertices']);selectors[name]=first
        if source_indices is None:
            origins.extend(dict(kind='computedBox',part=name) for _ in vertices)
        else:
            require(len(source_indices)==len(vertices),'Detailed source identity count')
            origins.extend(dict(kind='originalDetailed',part=name,sourceIndex=i) for i in source_indices)
        design['vertices'].extend(vertices);design['faces'].extend([[offset+i for i in f] for f in faces])
        design['faceMaterials'].extend(materials);design['faceTextures'].extend(textures)
    def closed_box(name,a,b):
        require(all(a[i]<b[i] for i in range(3)),'Positive support box')
        vertices=[(a[0],a[1],a[2]),(b[0],a[1],a[2]),(b[0],b[1],a[2]),(a[0],b[1],a[2]),(a[0],a[1],b[2]),(b[0],a[1],b[2]),(b[0],b[1],b[2]),(a[0],b[1],b[2])]
        # Literal source-declared closed-box topology fixes face addressing/winding.
        faces=[[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[1,2,6],[1,6,5],[2,3,7],[2,7,6],[3,0,4],[3,4,7]]
        insert(name,vertices,faces,[1]*12,[uv([vertices[i] for i in face],1) for face in faces])
    closed_box('DECK',(low[0],equator-depth,low[2]),(high[0],equator,high[2]))
    for xname,xlow,xhigh in [('NEG_X',low[0],low[0]+width),('POS_X',high[0]-width,high[0])]:
        for zname,zlow,zhigh in [('NEG_Z',low[2],low[2]+width),('POS_Z',high[2]-width,high[2])]:
            closed_box('POST_'+xname+'_'+zname,(xlow,base,zlow),(xhigh,equator-depth/2,zhigh))
    housings=[p for p in parts if p['name']=='instrumentation housing'];require(len(housings)==2,'Two genuine detailed housings')
    for name,part in [('ROOF_BRACE',brace),('HOUSING_0',housings[0]),('HOUSING_1',housings[1])]:
        first=part['faceStart'];end=first+part['faceCount'];offset=part['vertexStart']
        insert(name,points(detailed,part),[[i-offset for i in f] for f in detailed['faces'][first:end]],copy.deepcopy(detailed['faceMaterials'][first:end]),copy.deepcopy(detailed['faceTextures'][first:end]),list(range(part['vertexStart'],part['vertexStart']+part['vertexCount'])))
    for index,part in enumerate(housings):
        a,b=bounds(points(detailed,part));centre=mul(add(a,b),D('0.5'))
        closed_box('HOUSING_POST_'+str(index),(centre[0]-width/2,base,centre[2]-width/2),(centre[0]+width/2,centre[1],centre[2]+width/2))
    require(len(design['faces'])==364 and len(design['faces'])<=512,'Independent successor triangle bound')
    return design,selectors,opaque,origins


def derive(inputs, criteria, native, budget):
    require(native['proposal']['id']=='SH058' and native['proposal']['coordinateUnits']=='metres', 'Original identity/units')
    successor,new_features,opaque,origins=independent_successor(inputs,native)
    design = native['nativeDesign']
    vertices = [point(p) for p in design['vertices']]
    faces = design['faces']
    require(0 < len(vertices) <= 1536 and len(faces)==244, 'Original geometry bounds')
    require(all(len(f)==3 and all(type(i) is int and 0<=i<len(vertices) for i in f) for f in faces), 'Original face indices')
    triangles = [tuple(vertices[i] for i in f) for f in faces]
    features = {f['featureID']:f['literalSourceFaceIndex'] for f in criteria['literalFeatureFaceSelectors']}
    require(len(features)==10 and all(0<=i<244 for i in features.values()), 'Frozen original feature addresses')
    bounds = criteria['engineering']['framingBounds']
    lower, upper = point(bounds['min']), point(bounds['max'])
    centre, diagonal = mul(add(lower,upper),D('.5')), norm(sub(upper,lower))
    corners = [(x,y,z) for x in [lower[0],upper[0]] for y in [lower[1],upper[1]] for z in [lower[2],upper[2]]]
    axes = {v['id']:point(v['eyeAxis']) for v in criteria['views']}
    cameras=[]
    for v in criteria['views']:
        axis, up = point(v['eyeAxis']),point(v['up'])
        right=unit(cross(mul(axis,-1),up))
        distance=max(dot(c,axis)+D(1024)*max(abs(dot(c,right)),abs(dot(c,up)))/D(448) for c in corners)+1
        cameras.append(dict(id=v['id'],right=right,up=up,eyeAxis=axis,distance=distance))
    result=[]
    bary={'SURFACE_INTERIOR':(D(1)/3,D(1)/3,D(1)/3), 'EDGE_AB':(D('.5'),D('.5'),D(0)),
          'CORNER_A':(D(1),D(0),D(0)), 'OUTSIDE_OPPOSITE_A':(D(-1),D(1),D(1))}
    new_vertices=[point(v) for v in successor['vertices']]
    new_triangles=[tuple(new_vertices[i] for i in f) for f in successor['faces']]
    by_product={p:[tuple(mul(v,D('.2') if p=='CURRENT_NATIVE_0_2' else D(1)) for v in tri) for tri in (triangles if p=='ORIGINAL_NATIVE' else new_triangles)] for p in ['ORIGINAL_NATIVE','CURRENT_NATIVE','CURRENT_NATIVE_0_2']}
    for row in criteria['collisionSchedule']:
        budget.context('witness-construction', row['callID'], row['product'], row.get('literalSourceFaceIndex'))
        scale=D('.2') if row['product']=='CURRENT_NATIVE_0_2' else D(1)
        transformed=by_product[row['product']]
        if row['class'].startswith('ISOLATED_'):
            if row['class']=='ISOLATED_ORIGINAL_FACE_CONTROL':
                face=features[row['feature']];require(face==row['literalSourceFaceIndex'],'Original selector unchanged');tri=triangles[face]
            else:
                face=new_features[row['feature']];tri=new_triangles[face]
            normal=unit(cross(sub(tri[1],tri[0]),sub(tri[2],tri[0])))
            weights=bary[row['construction']]
            q=tuple(sum((tri[j][i]*weights[j] for j in range(3)),D(0)) for i in range(3))
            altitude=norm(cross(sub(tri[1],tri[0]),sub(tri[2],tri[0])))/max(norm(sub(tri[i],tri[(i+1)%3])) for i in range(3))
            radius=min(D('.125'),altitude/16) if row['construction'] in ['EDGE_AB','CORNER_A'] else D(0)
            ray=quantized_ray(mul(add(q,normal),scale),mul(normal,-1),2*scale,radius*scale)
            target=[face]
        else:
            if row['class']=='WHOLE_HULL_AXIS':
                axis=axes[row['viewAxis']];q=centre;radius=D(0)
            else:
                indices=[features[f] for f in row['featureAnchors']]
                centroids=[mul(add(add(triangles[i][0],triangles[i][1]),triangles[i][2]),D(1)/3) for i in indices]
                q=mul(add(centroids[0],centroids[1]),D('.5'))
                axis=point([1,0,0] if row['relation'].startswith('DRIVE_') else [0,1,0])
                radius=diagonal/D(10000)
            ray=quantized_ray(mul(add(q,mul(axis,2*diagonal)),scale),mul(axis,-1),4*diagonal*scale,radius*scale)
            target=list(range(244 if row['product']=='ORIGINAL_NATIVE' else 364))
        distance,ties=nearest(row['callID'],ray,transformed,target,budget,product=row['product'])
        budget.active.update(stage='source-query-assertion')
        if row['class'].startswith('ISOLATED_'):
            require((distance is not None)==(row['expectedClass']=='HIT'), 'Original isolated analytic class mismatch')
        result.append(dict(callID=row['callID'],product=row['product'],kind=row['class'],
            faceIDs=target,ray=ray,expectedDistance=distance,nearestFaceIDs=ties,
            comparisonTolerance=D('1e-8')+ray['range']*D('1e-10')))
    return result,cameras,successor,opaque,new_features,origins


def main():
    require(len(sys.argv)==3,'Require exact input and literal SHA; this script issues no release')
    manifest=Path(sys.argv[1])
    with manifest.open('rb') as stream: raw=stream.read(262145)
    require(len(raw)<=262144 and sha(raw)==sys.argv[2],'Run input bound or identity changed')
    inputs=json.loads(raw,object_pairs_hook=unique)
    require(inputs['phase']=='REFERENCE_DERIVATION' and inputs['sourceID']=='SH058','Wrong formal phase')
    criteria_raw=read_pin(inputs['criteria']);require(sha(criteria_raw)==CRITERIA_SHA,'Criteria changed')
    native_raw=read_pin(inputs['originalNative']);require(sha(native_raw)==NATIVE_SHA,'Original changed')
    for key,expected_sha in [('originalDetailed','1b743ac0d3fcc1bd5f0d94626cd942d3cbfa3066d28254cdd7e8435621ae0103'),('detailedParts','91a25bfd582d642824269b490635e2747daac7c1cd9e50e0d576172f355e5c78'),('nativeParts','456c3cb2083e38c7c713d299e83a93086ed0df9c923b6cb14b85eb32126cf908')]:
        require(sha(read_pin(inputs[key]))==expected_sha,'Immutable successor construction source changed')
    program=read_pin(inputs['referenceProgram']);require(sha(program)==sha(Path(__file__).read_bytes()),'Oracle source changed')
    criteria=json.loads(criteria_raw,object_pairs_hook=unique)
    require(criteria['schema']=='SH058_SUCCESSOR_PHASED_FORMAL_V3' and criteria['numericalWorkAuthorized'] is False,
            'Source proposal is never execution/admission permission')
    require(len(criteria['renderSchedule'])==36 and len(criteria['collisionSchedule'])==239,'Exact schedule')
    require(len({r['callID'] for r in criteria['collisionSchedule']})==239,'Duplicate collision IDs')
    output=Path(inputs['outputDirectory']);source=Path(inputs['sourceRoot']).resolve(strict=True)
    require(output.is_absolute() and not output.exists() and not output.is_symlink(),'Fresh external output required')
    require(not output.resolve().is_relative_to(source) and not source.is_relative_to(output.resolve()),'Output/source overlap')
    output.mkdir(mode=0o700,exist_ok=False)
    budget=Accounting()
    try:
        with localcontext() as context:
            context.prec=80
            controls=analytic_controls(budget)
            budget.context('original-source-decode',product='ORIGINAL_REFERENCE')
            original=tomllib.loads(native_raw.decode(),parse_float=D)
            witnesses,cameras,successor,opaque,new_features,origins=derive(inputs,criteria,original,budget)
            require(len(budget.rays)==251 and len(budget.primitives)==12849,'Exact reference accounting')
            require(budget.completed_rays==budget.rays and budget.completed_primitives==budget.primitives, 'Complete actual reference operations')
            result=serial(dict(schema='SH058_SUCCESSOR_EXPECTED_V3',sourceID='SH058',criteriaSHA256=CRITERIA_SHA,
                originalSHA256=NATIVE_SHA,referenceProgramSHA256=sha(program),
                status='INDEPENDENT_EXPECTED_VALUES_ONLY_NOT_SOURCE_OR_ADMISSION_APPROVAL',
                witnesses=witnesses,cameras=cameras,analyticControls=controls,successorDesign=successor,opaqueCanopyFaces=opaque,successorFeatureFaces=new_features,successorVertexOrigins=origins,
                accounting=dict(referenceQueries=251,referenceTrianglePredicates=12849,
                    completedReferenceQueries=len(budget.completed_rays),
                    completedReferenceTrianglePredicates=len(budget.completed_primitives),
                    pointProjectionEvaluations=budget.projections,plannedSUTQueries=239,
                    plannedSUTTriangleCalls=12836,totalPlannedQueries=490,totalPlannedTriangleCalls=25685),
                semanticStatus='Whole-source contact classification only; R3 opaque support and source fidelity review remain independent obligations'))
            expected=encoded(result)
    except BaseException as error:
        (output/'reference-failure.json').write_bytes(encoded(dict(
            status='REFERENCE_FAILED_NO_EXPECTED_SUT_OR_ADMISSION', errorType=type(error).__name__,
            error=str(error), sourceInputSHA256=sys.argv[2], criteriaSHA256=CRITERIA_SHA,
            activeOperation=budget.active,
            referenceQueries=len(budget.rays), referenceTrianglePredicates=len(budget.primitives),
            completedReferenceQueries=len(budget.completed_rays),
            completedReferenceTrianglePredicates=len(budget.completed_primitives),
            completedReferenceCallIDs=sorted(budget.completed_rays),
            pointProjectionEvaluations=budget.projections, productionKernelCalls=0, renderCalls=0)))
        raise
    (output/'expected.json').write_bytes(expected)
    (output/'reference-receipt.json').write_bytes(encoded(dict(status='REFERENCE_EXPECTATIONS_FROZEN_NOT_SUT_RESULT_OR_ADMISSION',
        sourceInputSHA256=sys.argv[2],criteriaSHA256=CRITERIA_SHA,originalSHA256=NATIVE_SHA,
        expected=dict(path=str(output/'expected.json'),bytes=len(expected),sha256=sha(expected)),
        accounting=result['accounting'],executionCredits=dict(renderer=0,productionKernel=0,actors=0,admission=0))))


if __name__=='__main__':
    main()
