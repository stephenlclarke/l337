"""Unexecuted current025 fixed native candidate. Separate Root authority is required."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parent
METHOD = 'current025-fixed-component-native512-v1'
INPUT = ROOT / 'current-025-native512-method-input-first.json'
INPUT_SHA256 = '0fb59f2f331fd08ae9535633de930ee5005fc5ed6bdf64198687652b13f232e7'
FIRST, USED, OPS, CAPS = {}, {}, {}, {}


class Counter:
    def __init__(self, native, id, form):
        self.native = native
        self.id = id
        self.form = form
        self.sides = 12 if native else 24
        self.vertices = 0
        self.faces = 0
        self.parts = []
        self.drive_parts = []

    def emit(self, name, vertices, runs, method, role='opaque-stock'):
        USED['partRecords'] += 1
        assert USED['partRecords'] <= FIRST['maximumPartRecords']
        count = sum(n for _, n in runs)
        assert vertices > 0 and count > 0
        part = dict(index=len(self.parts), name=name, vertexStart=self.vertices,
                    vertexCount=vertices, faceStart=self.faces, faceCount=count,
                    exactMaterialRuns=[dict(material=m, faces=n) for m, n in runs],
                    creatorMethod=method, creatorForm=self.form, role=role,
                    stockKgPerSquareMetre=5 if role == 'cockpit-glazing-stock' else 14)
        self.parts.append(part)
        self.vertices += vertices
        self.faces += count
        return part['index']

    def box(self, name, material=0):
        return self.emit(name, 8, [(material, 12)], 'Hull.box / Hull.solid')

    def strut(self, name, material=1):
        return self.emit(name, 8, [(material, 12)], 'Mesh.strut / Hull.box')

    def loft(self, name, stations=5, sides=None, material=0, role='opaque-stock'):
        n = self.sides if sides is None else sides
        # Two fan caps and the exact successive rings; integer topology only.
        return self.emit(name, stations * n, [(material, 2 * (n - 2) + 2 * n * (stations - 1))],
                         'Hull.loft / Hull.solid', role)

    def well(self, name, material=0):
        self.emit(name, 12, [(material, 16), (3, 2), (material, 2)], 'Mesh.well')
        if not self.native:
            for i in range(3):
                self.strut(name + '/recess-service-strut-' + str(i), 4)

    def pod(self, name, material=0, detail=True, glazing=False):
        self.loft(name, material=material,
                  role='cockpit-glazing-stock' if glazing else 'opaque-stock')
        if detail:
            for angle in range(4):
                for fraction in range(1 if self.native else 3):
                    self.well(name + '/service-well-' + str(angle) + '-' + str(fraction), material)
            if not self.native:
                for i in range(2):
                    self.strut(name + '/longitudinal-service-strut-' + str(i), 4)

    def body(self, detail=True):
        self.pod('body primary pressure envelope', detail=detail)

    def cockpit(self):
        self.pod('cockpit glazing envelope', 5, detail=False, glazing=True)
        self.strut('cockpit connected structural crossmember', 2)

    def drive(self, name):
        casing = self.loft(name + '/propulsion casing', stations=2, material=1,
                           role='creator-declared-drive-casing-stock')
        self.drive_parts.append(casing)
        self.loft(name + '/propulsion luminous recess', stations=2, material=6,
                  role='creator-declared-drive-recess-stock')

    def engine_pair(self):
        # This is the creator's literal two-iteration engine_pair call, never a default drive count.
        for side in ['negative side', 'positive side']:
            self.strut('engine_pair/' + side + '/connected support', 1)
            self.drive('engine_pair/' + side)

    def pods(self, count, material=0):
        for i in range(count):
            self.pod('pods explicit member ' + str(i), material)

    def dock(self):
        for i in range(2):
            self.box('dock lateral structural member ' + str(i), 1)
        for i in range(2):
            self.box('dock transverse structural member ' + str(i), 0)
        for i in range(2):
            self.strut('dock aperture guidance marker ' + str(i), 6)

    def wing(self, name='wing structural member', material=0):
        # All wing outlines in this pinned constructor have four points and two layers.
        self.emit(name, 8, [(material, 12)], 'Mesh.wing / Hull.solid')

    def wing_pair(self):
        for i in range(2):
            self.wing('wing_pair member ' + str(i))

    def box_detail(self):
        self.box('box_detail structural envelope', 0)
        self.well('box_detail recessed service well')

    def torus(self, name, mode='full', material=0):
        # Exact fixed integer loop counts for the pinned full/half/0.5-gap/0.6-gap calls.
        if self.native:
            steps = dict(full=24, half=12, arc=22, probe=22)[mode]
            minor = 8
        else:
            steps = dict(full=48, half=24, arc=44, probe=43)[mode]
            minor = 12
        closed = mode == 'full'
        rows = steps if closed else steps + 1
        caps = 0 if closed else 2 * (minor - 2)
        self.emit(name, rows * minor, [(material, 2 * steps * minor + caps)], 'Mesh.torus / Mesh.raw')


def operation_groups(row, native):
    form, count, id = row['sourceArchetype'], row['sourceModuleCount'], row['id']
    h = Counter(native, id, form)
    if form in ['panniers', 'container-train', 'heavy-rail', 'gift-barge', 'transverse-bins']:
        h.body()
        if form == 'transverse-bins':
            for _ in range(count):
                h.box_detail()
        else:
            for _ in range(count):
                for _ in range(2):
                    h.strut('pannier connected structural support', 2)
                    if form in ['gift-barge', 'container-train']:
                        h.box_detail()
                    else:
                        h.pod('pannier pressure envelope', 1)
        h.cockpit()
        h.engine_pair()
    elif form in ['fan-freighter', 'tri-stack', 'side-stack', 'rotary-silo', 'vertical-stack']:
        if form == 'fan-freighter':
            h.pods(count)
            h.box('fan transverse structural deck', 2)
        elif form in ['tri-stack', 'rotary-silo']:
            for _ in range(count):
                h.pod('radial pressure envelope', 1)
                h.strut('radial connected support', 2)
            for _ in range(2):
                h.torus('radial structural collar', material=2)
        elif form == 'side-stack':
            h.pods(count, 1)
            h.strut('side stack structural spine', 2)
        else:
            for _ in range(count):
                h.box_detail()
            for _ in range(2):
                h.strut('vertical stack bracing', 2)
        h.cockpit()
        h.engine_pair()
    elif form in ['twin-keel', 'double-bay', 'twin-deck', 'low-loader', 'high-bridge',
                  'shield-barge', 'broad-tug', 'staggered-capsules']:
        if form in ['twin-keel', 'double-bay']:
            h.pods(2)
            for _ in range(2):
                h.box('keel cross bridge', 2)
            if form == 'double-bay':
                h.dock()
        elif form == 'twin-deck':
            for _ in range(2):
                h.box('twin deck pressure envelope')
            for _ in range(2):
                h.strut('twin deck connected support', 2)
        elif form == 'staggered-capsules':
            h.pods(2)
        elif form == 'high-bridge':
            h.body()
            h.box('raised bridge structural envelope', 1)
        elif form == 'shield-barge':
            h.body()
            h.pods(3)
        else:
            h.box('low freight deck')
            h.box('raised aft pressure envelope', 1)
            if form == 'broad-tug':
                h.dock()
            else:
                for _ in range(3):
                    h.strut('longitudinal low deck support', 2)
        h.cockpit()
        h.engine_pair()
    elif form in ['closed-loop', 'oval-shuttle', 'shuttle-loop', 'arc-liner', 'arc-runner', 'double-hoop', 'bow-hook']:
        if form == 'shuttle-loop':
            h.torus('closed shuttle loop')
            h.body()
        elif form == 'double-hoop':
            for _ in range(2):
                h.torus('closed structural hoop')
            h.body()
        else:
            h.torus('closed loop' if form == 'closed-loop' else 'open curved loop',
                    mode='full' if form == 'closed-loop' else 'arc', material=1)
            h.body()
            if form in ['arc-runner', 'arc-liner']:
                for _ in range(2):
                    h.box('arc transverse connected support', 2)
        h.cockpit()
        h.engine_pair()
    elif form == 'split-keel':
        h.body()
        for side in range(2):
            h.box('split keel vertical envelope', 1)
            h.wing()
            h.drive('split keel explicit drive ' + str(side))
            h.well('split keel recessed service well', 1)
        h.cockpit()
    elif form == 'twin-spine':
        for _ in range(2):
            h.box('twin spine pressure envelope')
            h.box('twin spine shoulder envelope', 1)
            for _ in range(3):
                h.well('twin spine shoulder service well', 1)
        for _ in range(2):
            h.box('twin spine transverse bridge', 2)
        h.pod('twin spine central forward envelope')
        h.cockpit()
        h.engine_pair()
        if id == 'SH161':
            h.dock()
    elif form in ['wishbone', 'forward-fork', 'split-prow', 'gated-bow', 'fork-keel',
                  'shoulder-jaws', 'arched-boom', 'rescue-cradle']:
        if form in ['wishbone', 'arched-boom', 'gated-bow']:
            if form == 'arched-boom':
                for _ in range(2):
                    h.torus('arched connected boom', mode='half', material=1)
                h.pods(2)
            elif form == 'wishbone':
                for _ in range(2):
                    h.strut('wishbone connected arm', 1)
                    h.pod('wishbone forward envelope')
                h.box('wishbone forward cross bridge', 2)
            else:
                for _ in range(2):
                    h.box('gate longitudinal envelope', 1)
                    h.strut('gate connected aft support', 0)
                h.box('gate forward cross bridge', 2)
            h.box('aft transverse bridge', 2)
            h.body()
        elif form == 'rescue-cradle':
            h.pods(2)
            h.dock()
            h.body()
        else:
            h.pods(2)
            for _ in range(2):
                h.box('fork longitudinal envelope', 1)
            h.box('fork aft cross bridge', 2)
            h.body()
            if form == 'split-prow':
                h.box('split prow lower pressure envelope', 1)
        h.cockpit()
        h.engine_pair()
        if id == 'SH161':
            h.dock()
    elif form in ['broken-spar', 'sidecar-raider', 'cantilever', 'needle-outrigger', 'cross-spars',
                  'stepped-fins', 'scissor', 'shield-fighter', 'hanging-keel', 'raised-collar']:
        h.body()
        if form == 'cross-spars':
            for _ in range(4):
                h.strut('cross spar connected support', 1)
                h.pod('cross spar outboard envelope', 1)
        elif form == 'hanging-keel':
            h.wing_pair()
            for _ in range(2):
                h.box('hanging keel vertical envelope', 1)
        elif form == 'shield-fighter':
            h.pod('upper shielded pressure envelope')
            for _ in range(2):
                h.box('shielded vertical aft support', 1)
        elif form == 'raised-collar':
            for _ in range(2):
                h.torus('raised structural collar')
            h.wing_pair()
        else:
            h.wing_pair()
            h.pods(2, 1)
            if form == 'stepped-fins':
                for _ in range(2):
                    h.box('stepped vertical fin', 2)
            if form == 'broken-spar':
                h.box('broken spar upper crossmember', 1)
                for _ in range(2):
                    h.box('broken spar raised shoulder', 2)
            if form == 'cantilever':
                h.pods(2, 1)
        h.cockpit()
        h.engine_pair()
    elif form == 'blade-rail':
        h.body()
        h.box('vertical blade rail', 1)
        h.cockpit()
        h.engine_pair()
        for _ in range(2):
            h.strut('blade rail transverse support', 2)
    elif form in ['drill-cradle', 'ore-cart', 'long-borer', 'segmented-hopper']:
        h.body()
        if form == 'segmented-hopper':
            for _ in range(count):
                h.torus('open hopper collar', mode='half', material=1)
        else:
            h.dock()
            h.pods(2, 1)
        if form != 'ore-cart':
            for _ in range(2):
                h.strut('boring-head structural support', 2)
                h.loft('boring head', stations=3, sides=8, material=2)
                if not native:
                    for _ in range(4):
                        h.torus('boring head collar', material=3)
        if form == 'ore-cart':
            h.box('ore cart forward lower member', 1)
            for _ in range(2):
                h.wing('ore cart forward loading blade', 2)
        if form == 'long-borer':
            h.strut('long borer central service support', 4)
        h.cockpit()
        h.engine_pair()
    elif form in ['harbour', 'double-drum', 'haven-cage', 'fortress-gate', 'process-factory']:
        if form in ['harbour', 'double-drum', 'haven-cage']:
            for _ in range(2):
                h.torus('station structural ring', material=1)
            h.pods(count if form == 'harbour' else 4)
            h.dock()
        elif form == 'fortress-gate':
            h.dock()
            for _ in range(4):
                h.pod('fortress corner pressure envelope', 1)
                h.strut('fortress forward corner support', 2)
        else:
            h.dock()
            for _ in range(4):
                h.pod('factory transverse processing envelope', 1)
                h.strut('factory lower service support', 4)
            for _ in range(3):
                h.box('factory lower transverse bridge', 2)
        if not native:
            for _ in range(4):
                h.well('station outer service well')
    elif form == 'sawback':
        h.body()
        for _ in range(2 * count):
            h.wing('sawback blade', 1)
        h.cockpit()
        h.engine_pair()
    elif form == 'seed':
        h.body(detail=False)
        h.cockpit()
        for _ in range(2):
            h.torus('seed circumferential collar', material=2)
        for i in range(2):
            h.drive('seed explicit drive ' + str(i))
    elif form in ['alien-lobes', 'alien-probe']:
        if form == 'alien-lobes':
            for _ in range(2):
                h.torus('closed alien lobe')
                h.pod('existing alien end growth', detail=False)
                h.loft('exact reflected copy of alien end growth', material=0)
            h.pod('central alien structural growth', 2, detail=False)
        else:
            h.pod('alien probe primary envelope', detail=False)
            h.torus('alien probe open structural arc', mode='probe', material=2)
        h.pod('alien luminous aft organ', 6, detail=False)
    else:
        raise ValueError('Unmapped exact creator branch: ' + form)
    if row['sourceRole'] in ['military', 'bountyHunter'] and id != 'SH161':
        for _ in range(2):
            h.strut('explicit military mount upright', 2)
            h.strut('explicit military mount longitudinal member', 3)
    return h


def check_source(counter, design, vertex_bound, face_bound):
    assert len(design['vertices']) == vertex_bound == counter.vertices, (
        counter.id, counter.native, 'vertices', len(design['vertices']), vertex_bound, counter.vertices)
    assert len(design['faces']) == face_bound == counter.faces, (
        counter.id, counter.native, 'faces', len(design['faces']), face_bound, counter.faces)
    assert len(design['faceMaterials']) == face_bound
    material_limit = FIRST['maximumFaceMaterialChecks']
    for part in counter.parts:
        offset = part['faceStart']
        for run in part['exactMaterialRuns']:
            for face in range(offset, offset + run['faces']):
                USED['faceMaterialChecks'] += 1
                assert USED['faceMaterialChecks'] <= material_limit
                assert design['faceMaterials'][face] == run['material'], (
                    counter.id, counter.native, 'material', face, design['faceMaterials'][face], run['material'])
            offset += run['faces']
        for face in design['faces'][part['faceStart']:part['faceStart'] + part['faceCount']]:
            assert len(face) == 3
            for index in face:
                USED['faceIndexChecks'] += 1
                assert USED['faceIndexChecks'] <= FIRST['maximumFaceIndexChecks']
                assert part['vertexStart'] <= index < part['vertexStart'] + part['vertexCount'], (
                    counter.id, counter.native, 'owned index', part['index'], index)



def artifact_status(path):
    """An error is not evidence that the final artifact is absent."""
    try:
        metadata = path.lstat()
        return {"presence": "PRESENT", "bytes": metadata.st_size}
    except FileNotFoundError:
        return {"presence": "ABSENT"}
    except OSError as error:
        return {"presence": "UNKNOWN", "inspectionError": type(error).__name__ + ": " + str(error)[:512]}


def publish_exclusive(target, encoded):
    """Verify an owned temporary inode before atomically linking a new final name."""
    descriptor, name = tempfile.mkstemp(prefix="." + target.name + ".", suffix=".tmp", dir=target.parent)
    temporary = Path(name)
    identity = None
    try:
        identity = os.fstat(descriptor)
        stream = os.fdopen(descriptor, "w+b")
        descriptor = None
        with stream:
            if stream.write(encoded) != len(encoded):
                raise OSError("Incomplete temporary artifact write")
            stream.flush()
            os.fsync(stream.fileno())
            stream.seek(0)
            if stream.read(len(encoded) + 1) != encoded:
                raise OSError("Temporary artifact byte verification failed")
        # link is atomic and fails if any final entry already exists, including a symlink.
        os.link(temporary, target)
    finally:
        try:
            if descriptor is not None:
                os.close(descriptor)
        finally:
            metadata = temporary.lstat()
            if identity is None or (metadata.st_dev, metadata.st_ino) != (identity.st_dev, identity.st_ino):
                raise OSError("Temporary ownership uncertain; entry retained without deletion")
            temporary.unlink()
            directory = os.open(target.parent, os.O_RDONLY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)


def charged(key, amount=1):
    OPS[key] += amount
    assert OPS[key] <= CAPS[key], (key, OPS[key], CAPS[key])


def raw_pin(path, pin, maximum=2_097_152):
    path = Path(path)
    assert not path.is_symlink() and path.is_file()
    assert path.stat().st_size <= maximum
    with path.open('rb') as stream:
        raw = stream.read(maximum + 1)
    assert len(raw) <= maximum
    assert len(raw) == pin['bytes'] and hashlib.sha256(raw).hexdigest() == pin['sha256']
    return raw


def resolved_pin(pin):
    path = Path(pin['path'])
    if not path.is_absolute(): path = ROOT.parent.parent / path
    return raw_pin(path, pin)


def execution_gate(authority_path):
    assert __debug__, 'Checks require an unoptimized interpreter'
    authority_raw = Path(authority_path).read_bytes()
    assert len(authority_raw) <= 65_536
    authority = json.loads(authority_raw)
    assert authority['executionAuthorized'] is True
    assert authority['scopeIDs'] == ['SH025'] and authority['method'] == METHOD
    for key in ['rootDecision', 'sourceMethodReview', 'methodFirst']:
        pin = authority[key]
        raw_pin(pin['path'], pin)
    method_first = json.loads(Path(authority['methodFirst']['path']).read_bytes())
    raw_pin(Path(__file__), method_first['source'])
    raw = raw_pin(INPUT, method_first['input'])
    assert hashlib.sha256(raw).hexdigest() == INPUT_SHA256
    spec = json.loads(raw)
    assert spec['scopeID'] == 'SH025'
    assert spec['outputNativeExact'] == {'vertices': 310, 'triangles': 512, 'closedNamedComponents': 27,
                                       'triangleBudgetExpression': '3*32 + 44 + 4*12 + 12*20 + 7*12 = 512; no omitted part or final cap increase.'}
    for pin in spec['callerAndMethodPins'] + [spec['r3']]: resolved_pin(pin)
    creator = spec['sourceCreatorPins']
    for path_key, sha_key in [('creatorPath','creatorSHA256'), ('primitiveCreatorPath','primitiveCreatorSHA256'),
                             ('emissionManifestPath','emissionManifestSHA256'), ('originalInputPath','originalInputSHA256')]:
        data = Path(creator[path_key]).read_bytes()
        assert hashlib.sha256(data).hexdigest() == creator[sha_key]
    return spec, authority


def vector_sub(a, b):
    return tuple(a[i] - b[i] for i in range(3))


def cross(a, b):
    charged('normalCrossProducts')
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def dot(a, b):
    return sum(a[i]*b[i] for i in range(3))


def float_point(tokens):
    assert len(tokens) == 3
    result = []
    for token in tokens:
        charged('coordinateFloatConversions')
        assert type(token) in (str, int)
        value = float(token)
        assert math.isfinite(value)
        result.append(value)
    return tuple(result)


def bounds(points):
    low, high = [math.inf]*3, [-math.inf]*3
    for point in points:
        charged('componentBoundsVertexVisits')
        for axis in range(3):
            low[axis] = min(low[axis], point[axis])
            high[axis] = max(high[axis], point[axis])
    return low + high


def number(value):
    if type(value) is int: return str(value)
    if type(value) is float:
        assert math.isfinite(value)
        return repr(value)
    assert type(value) is str and re.fullmatch(r'[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?', value)
    return value


def numeric_array(values):
    return '[' + ', '.join(numeric_array(value) if type(value) in (list, tuple) else number(value)
                           for value in values) + ']'


def face_texture(item):
    assert type(item['texture']) is int and len(item['uv']) == 3
    assert all(len(pair) == 2 for pair in item['uv'])
    return '{ texture = ' + str(item['texture']) + ', uv = ' + numeric_array(item['uv']) + ' }'


def calculate(spec):
    global FIRST, USED
    FIRST = {'maximumPartRecords': CAPS['ownIntegerPartRecords'],
             'maximumFaceIndexChecks': CAPS['inputNativeFaceIndexChecks'],
             'maximumFaceMaterialChecks': CAPS['inputNativeFaceMaterialChecks']}
    USED = dict(partRecords=0, faceIndexChecks=0, faceMaterialChecks=0)
    original_raw = resolved_pin(spec['inputOriginalSource'])
    current_raw = resolved_pin(spec['inputCurrentResource'])
    charged('sourceTOMLParses')
    original = tomllib.loads(original_raw.decode(), parse_float=str)
    charged('sourceTOMLParses')
    current = tomllib.loads(current_raw.decode(), parse_float=str)
    assert original['proposal']['id'] == current['id'] == 'SH025'
    assert spec['inputNativeExpected']['vertices'] == 536 and spec['inputNativeExpected']['triangles'] == 964
    row = {'id': 'SH025', 'sourceArchetype': 'split-prow', 'sourceModuleCount': 2, 'sourceRole': 'trader'}
    ownership = operation_groups(row, True)
    assert len(ownership.parts) == 27
    old, reference = current['nativeDesign'], original['nativeDesign']
    check_source(ownership, reference, 536, 964)
    check_source(ownership, old, 536, 964)
    OPS['ownIntegerPartRecords'] = USED['partRecords']
    OPS['inputNativeFaceIndexChecks'] = USED['faceIndexChecks']
    OPS['inputNativeFaceMaterialChecks'] = USED['faceMaterialChecks']
    for index in range(964):
        charged('inputNativeCorrespondenceFaceComparisons')
        assert old['faces'][index] == reference['faces'][index]
        assert old['faceMaterials'][index] == reference['faceMaterials'][index]
    for key in ['materials', 'textures', 'license', 'appearanceLicense', 'paletteName']:
        assert old[key] == reference[key], ('native declaration correspondence', key)
    assert len(old['faceTextures']) == 964
    assert old['license'] == old['appearanceLicense'] == 'MIT'
    recipes = {}
    for recipe in spec['fixedPartRecipe']:
        for index in recipe['indices']:
            assert index not in recipes
            recipes[index] = recipe
    assert set(recipes) == set(range(27))
    charged('existingScaleTokenConversions')
    scale = float('36.95309420575483')
    assert scale > 0 and math.isfinite(scale)
    assert 'Uniform scale 36.95309420575483' in current['geometryContext']
    old_points = [float_point(tokens) for tokens in old['vertices']]
    new_points, raw_points, faces, materials, textures = [], [], [], [], []
    old_to_new, relative_points, provenance = {}, {}, []

    def vertex(old_index):
        assert old_index not in old_to_new
        charged('newVertexCopies')
        point = old_points[old_index]
        relative = float_point(reference['vertices'][old_index])
        for axis in range(3):
            charged('sourceFrameCoordinateComparisons')
            expected = relative[axis]*scale
            assert math.isfinite(expected)
            assert abs(point[axis]-expected) <= 1e-9*max(1, abs(point[axis]), abs(expected)), ('unchanged F01 source-frame mismatch', old_index, axis)
        index = len(new_points)
        old_to_new[old_index] = index
        relative_points[index] = relative
        new_points.append(point)
        raw_points.append(old['vertices'][old_index])
        return index

    def projected_uv(face, material):
        charged('UVProjectionFaces')
        points = [relative_points[index] for index in face]
        normal = cross(vector_sub(points[1], points[0]), vector_sub(points[2], points[0]))
        assert all(math.isfinite(value) for value in normal) and dot(normal, normal) > 0
        axis = max(range(3), key=lambda index: abs(normal[index]))
        plane = {0:(2,1), 1:(0,2), 2:(0,1)}[axis]
        pairs = []
        for point in points:
            pair = []
            for axis in plane:
                charged('UVNumericRoundings')
                value = round(point[axis]*0.85, 6)
                assert math.isfinite(value)
                pair.append(value)
            pairs.append(pair)
        return {'texture': 0 if material == 0 else 2, 'uv': pairs}

    def triangle(face, material, texture=None):
        charged('newTriangleRecords')
        assert len(face) == 3 and len(set(face)) == 3
        for index in face:
            charged('newTriangleIndexChecks')
            assert type(index) is int and 0 <= index < len(new_points)
        assert type(material) is int and 0 <= material < len(old['materials'])
        faces.append(face)
        materials.append(material)
        if texture is None:
            textures.append(projected_uv(face, material))
        else:
            charged('copiedFaceTextures')
            textures.append(texture)

    def polygon(indices, material):
        for index in range(1, len(indices)-1):
            triangle([indices[0], indices[index], indices[index+1]], material)

    for part in ownership.parts:
        recipe = recipes[part['index']]
        first_vertex, first_face = len(new_points), len(faces)
        old_first = part['vertexStart']
        selected_old_indices = []
        if recipe.get('copyExact'):
            assert part['vertexCount'] == recipe['newVerticesEach'] and part['faceCount'] == recipe['newTrianglesEach']
            for old_index in range(old_first, old_first+part['vertexCount']):
                selected_old_indices.append(old_index)
                vertex(old_index)
            for old_face in range(part['faceStart'], part['faceStart']+part['faceCount']):
                triangle([old_to_new[index] for index in old['faces'][old_face]],
                         old['faceMaterials'][old_face], old['faceTextures'][old_face])
        else:
            assert part['vertexCount'] == recipe['oldRings']*recipe['oldSides']
            assert len(part['exactMaterialRuns']) == 1
            ring_indices = []
            for ring in recipe['keepRings']:
                selected = []
                for angle in recipe['keepAngularIndices']:
                    old_index = old_first + ring*recipe['oldSides'] + angle
                    selected_old_indices.append(old_index)
                    selected.append(vertex(old_index))
                ring_indices.append(selected)
            material = part['exactMaterialRuns'][0]['material']
            polygon(list(reversed(ring_indices[0])), material)
            for lower, upper in zip(ring_indices, ring_indices[1:]):
                for index in range(len(lower)):
                    following = (index+1) % len(lower)
                    polygon([lower[index], lower[following], upper[following], upper[index]], material)
            polygon(ring_indices[-1], material)
        assert len(new_points)-first_vertex == recipe['newVerticesEach']
        assert len(faces)-first_face == recipe['newTrianglesEach']
        old_bound = bounds(old_points[old_first:old_first+part['vertexCount']])
        new_bound = bounds(new_points[first_vertex:])
        for old_value, new_value in zip(old_bound, new_bound):
            charged('componentBoundsComparisons')
            assert old_value == new_value, ('component bound changed', part['index'])
        directed = {}
        volume_terms = []
        for face in faces[first_face:]:
            charged('faceGeometryChecks')
            a, b, c = [new_points[index] for index in face]
            normal = cross(vector_sub(b, a), vector_sub(c, a))
            assert all(math.isfinite(value) for value in normal)
            squared = dot(normal, normal)
            assert math.isfinite(squared) and squared > 0, ('degenerate face', part['index'])
            charged('signedVolumeFaceTerms')
            volume_terms.append(dot(a, normal)/6)
            for left, right in zip(face, face[1:]+face[:1]):
                charged('edgeIncidenceRecords')
                directed[(left, right)] = directed.get((left, right), 0) + 1
        assert all(count == 1 and directed.get((right,left)) == 1
                   for (left,right),count in directed.items()), ('open or inconsistent winding', part['index'])
        volume = math.fsum(volume_terms)
        assert math.isfinite(volume) and volume > 0, ('nonpositive component volume', part['index'])
        provenance.append({'index':part['index'], 'name':part['name'], 'oldVertexStart':old_first,
                           'oldVertexCount':part['vertexCount'], 'oldFaceStart':part['faceStart'],
                           'oldFaceCount':part['faceCount'], 'selectedOldVertexIndices':selected_old_indices,
                           'newVertexStart':first_vertex, 'newVertexCount':len(new_points)-first_vertex,
                           'newFaceStart':first_face, 'newFaceCount':len(faces)-first_face,
                           'materialRuns':part['exactMaterialRuns'], 'recipe':recipe,
                           'closedOrientedEdges':True, 'positiveSignedVolume':volume,
                           'oldAndNewBoundsExact':old_bound})
    assert len(new_points) == 310 and len(faces) == len(materials) == len(textures) == 512
    assert len(provenance) == 27 and len(old_to_new) == 310
    text = current_raw.decode()
    lines = text.splitlines(keepends=True)
    starts = [index for index,line in enumerate(lines) if line.strip() == '[nativeDesign]']
    assert len(starts) == 1
    start = starts[0]
    end = next((index for index in range(start+1,len(lines)) if lines[index].lstrip().startswith('[')),len(lines))
    replacement = {'vertices':numeric_array(raw_points), 'faces':json.dumps(faces),
                   'faceMaterials':json.dumps(materials),
                   'faceTextures':'[' + ', '.join(face_texture(item) for item in textures) + ']',
                   'source':json.dumps(old['source'] + '; ' + METHOD + ': fixed native-only component-preserving authored candidate')}
    new_lines = list(lines)
    for key, value in replacement.items():
        matches = [index for index in range(start+1,end) if lines[index].startswith(key+' =')]
        assert len(matches) == 1
        new_lines[matches[0]] = key + ' = ' + value + '\n'
    context_lines = [index for index,line in enumerate(lines[:start]) if line.startswith('geometryContext =')]
    assert len(context_lines) == 1
    context_index = context_lines[0]
    context_value = current['geometryContext'] + ' ' + METHOD + ': new512-triangle/27-component native candidate; current coordinates and full detailed source retained; native all-view/fidelity/collision qualification UNRUN.'
    new_lines[context_index] = 'geometryContext = ' + json.dumps(context_value) + '\n'
    # Exact inverse textual restoration proves the rest of the shipping resource is untouched.
    restored = list(new_lines)
    for index in range(start,end): restored[index] = lines[index]
    restored[context_index] = lines[context_index]
    assert ''.join(restored).encode() == current_raw
    candidate = ''.join(new_lines).encode()
    provenance_record = {'status':'NEW_NATIVE512_AUTHORING_CANDIDATE_NOT_GEOMETRY_OR_GAME_QUALIFICATION',
                         'id':'SH025', 'method':METHOD, 'inputCurrentResource':spec['inputCurrentResource'],
                         'inputOriginalSource':spec['inputOriginalSource'], 'r3':spec['r3'],
                         'sourceCreatorPins':spec['sourceCreatorPins'], 'metreFrame':'Existing F01 values copied; original axes/origin and36.95309420575483 scale retained',
                         'vertices':310, 'triangles':512, 'components':provenance,
                         'unchangedComponentUVFaces':324, 'newLoftUVFaces':188,
                         'UVBasis':'Original published relative coordinates; pinned creator projection style0.85/round6/dominant-plane; changed faces have newly authored UVs.',
                         'detailedAndAllOtherResourceBytesExactByInverse':True,
                         'actualRendererFidelityClearanceAndGameplay':'UNRUN; no hidden parts, CSG/fit search, overall convex proxy or qualification claim',
                         'candidateBytes':len(candidate), 'candidateSHA256':hashlib.sha256(candidate).hexdigest()}
    return candidate, provenance_record


def main():
    global OPS, CAPS
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--authority-first', required=True)
    arguments = parser.parse_args()
    spec, authority = execution_gate(arguments.authority_first)
    CAPS = spec['operationCaps']
    OPS = {key:0 for key in CAPS}
    output = ROOT / 'current-025-native512-candidate'
    assert not output.exists() and not output.is_symlink(), 'No unchanged retry or overwrite'
    output.mkdir()
    candidate_path, provenance_path, result_path = [output/name for name in ['SH025.toml','component-provenance.json','result.json']]
    results = []
    try:
        candidate, provenance = calculate(spec)
        for target, payload in [(candidate_path,candidate),
                                (provenance_path,(json.dumps(provenance,indent=2,sort_keys=True)+'\n').encode())]:
            assert len(payload) <= spec['maximumOutputBytesEach']
            charged('outputDocuments')
            publish_exclusive(target,payload)
            results.append({'file':str(target.relative_to(ROOT)), 'bytes':len(payload),
                            'sha256':hashlib.sha256(payload).hexdigest()})
        status = 'AUTHORED_FIXED_NATIVE512_SOURCE_CANDIDATE_NOT_QUALIFICATION'
        error_text = None
    except (AssertionError, ArithmeticError, KeyError, TypeError, ValueError, OSError) as error:
        status = 'AUTHORING_STOP_OR_PUBLICATION_FAILURE'
        error_text = type(error).__name__ + ': ' + str(error)[:512]
    for destination, key in [('ownIntegerPartRecords','partRecords'), ('inputNativeFaceIndexChecks','faceIndexChecks'),
                             ('inputNativeFaceMaterialChecks','faceMaterialChecks')]:
        if key in USED: OPS[destination] = USED[key]
    receipt = {'status':status, 'method':METHOD, 'error':error_text, 'artifacts':results,
               'actualArtifactStatus':{'candidate':artifact_status(candidate_path),'provenance':artifact_status(provenance_path)},
               'used':OPS, 'caps':CAPS, 'inputSHA256':INPUT_SHA256,
               'authoringSourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               'rootAuthorityPath':arguments.authority_first,
               'retries':0, 'searches':0, 'capRaises':0, 'sourceScaleChanges':0,
               'originalCreatorImportsOrExecutions':0, 'originalSourceOrShippingResourceWrites':0,
               'nativeCompilerRendererTests':0, 'qualification':'All-view/collision/clearance/game/loaded-mass acceptance remains UNRUN'}
    try:
        charged('outputDocuments')
        receipt['used'] = dict(OPS)
        payload = (json.dumps(receipt,indent=2,sort_keys=True)+'\n').encode()
        assert len(payload) <= spec['maximumOutputBytesEach']
        publish_exclusive(result_path,payload)
    except (AssertionError,OSError) as error:
        print(json.dumps({'status':'RESULT_PUBLICATION_FAILURE', 'originalAuthoringOutcome':receipt['status'],
                          'receipt':receipt, 'used':dict(OPS), 'caps':dict(CAPS),
                          'inputSHA256':INPUT_SHA256,
                          'authoringSourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                          'rootAuthorityPath':arguments.authority_first,
                          'lastOutputAttempt':{'file':str(result_path.relative_to(ROOT)),
                                               'outputDocumentsAttempt':OPS['outputDocuments']},
                          'actualResultArtifact':artifact_status(result_path),
                          'error':type(error).__name__ + ': ' + str(error)[:512],
                          'candidate':artifact_status(candidate_path), 'provenance':artifact_status(provenance_path)}))
        raise SystemExit(1)
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
