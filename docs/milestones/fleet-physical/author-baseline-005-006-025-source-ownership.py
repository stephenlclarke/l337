"""Own bounded integer source ownership only. No creator or coordinate evaluation."""
from pathlib import Path
import hashlib
import json
import os
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parent
FIRST = {}
USED = {}


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


def charge(key, limit):
    USED[key] += 1
    assert USED[key] <= limit, (key, USED[key], limit)


def pinned(path, pin):
    raw = Path(path).read_bytes()
    assert len(raw) == pin['bytes'] and hashlib.sha256(raw).hexdigest() == pin['sha256']
    return raw


def signature(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def main():
    global FIRST, USED
    assert __debug__, 'No optimized interpreter may disable ownership checks'
    authority = json.loads((ROOT / 'baseline-005-006-025-source-ownership-authoring-first.json').read_bytes())
    pinned(Path(__file__), authority['authoringSource'])
    raw_first = pinned(ROOT / 'baseline-005-006-025-source-ownership-first.json', authority['input'])
    FIRST = json.loads(raw_first)
    assert authority['metadataOnly'] and authority['coordinateConversions'] == 0
    for pin in FIRST['allInputAndConsumerPins']:
        path = Path(pin['path'])
        if not path.is_absolute(): path = ROOT.parent.parent / path
        pinned(path, pin)
    output = ROOT / FIRST['outputDirectory']
    assert not output.exists() and not output.is_symlink(), 'No retry or overwrite'
    output.mkdir()
    USED = dict(designParses=0, partRecords=0, faceIndexChecks=0, faceMaterialChecks=0,
                currentCorrespondenceFaceComparisons=0, currentNativeFaces=0, resultRecords=0)
    results = []
    for row in FIRST['rows']:
        target = output / (row['id'] + '.json')
        publication_attempted = False
        try:
            raw = pinned(row['originalSource']['path'], row['originalSource'])
            charge('designParses', FIRST['maximumDesignParses'])
            original = tomllib.loads(raw.decode(), parse_float=str)
            current_pin = row['currentResource']
            current_raw = pinned(ROOT.parent.parent / current_pin['path'], current_pin)
            charge('designParses', FIRST['maximumDesignParses'])
            current = tomllib.loads(current_raw.decode(), parse_float=str)
            assert original['proposal']['id'] == row['id'] == current['id']
            detailed = operation_groups(row, False)
            native = operation_groups(row, True)
            check_source(detailed, original['design'], row['detailedVertexBound'], row['detailedFaceBound'])
            check_source(native, original['nativeDesign'], row['nativeVertexBound'], row['nativeFaceBound'])
            assert len(current['design']['vertices']) == row['detailedVertexBound']
            assert len(current['design']['faces']) == row['detailedFaceBound']
            assert len(current['design']['faceMaterials']) == row['detailedFaceBound']
            for index in range(row['detailedFaceBound']):
                charge('currentCorrespondenceFaceComparisons', FIRST['maximumCurrentCorrespondenceFaceComparisons'])
                assert current['design']['faces'][index] == original['design']['faces'][index], (row['id'], 'changed detailed topology', index)
                assert current['design']['faceMaterials'][index] == original['design']['faceMaterials'][index], (row['id'], 'changed detailed face material', index)
            check_source(detailed, current['design'], row['detailedVertexBound'], row['detailedFaceBound'])
            for key in ['license', 'appearanceLicense', 'materials']:
                assert current['design'][key] == original['design'][key], (row['id'], 'changed detailed declaration', key)
            selected = current['nativeDesign']
            assert 0 < len(selected['vertices']) <= row['currentNativeMaximumVertices']
            assert 0 < len(selected['faces']) <= row['currentNativeMaximumFaces']
            assert len(selected['faceMaterials']) == len(selected['faces'])
            assert selected['license'] == current['design']['license']
            assert selected['appearanceLicense'] == current['design']['appearanceLicense']
            for index, face in enumerate(selected['faces']):
                charge('currentNativeFaces', FIRST['maximumCurrentNativeFaces'])
                assert len(face) == 3
                for vertex in face:
                    charge('faceIndexChecks', FIRST['maximumFaceIndexChecks'])
                    assert type(vertex) is int and 0 <= vertex < len(selected['vertices'])
                charge('faceMaterialChecks', FIRST['maximumFaceMaterialChecks'])
                material = selected['faceMaterials'][index]
                assert type(material) is int and 0 <= material < len(selected['materials'])
            same_native = (selected['faces'] == original['nativeDesign']['faces']
                           and selected['faceMaterials'] == original['nativeDesign']['faceMaterials'])
            record = {'id': row['id'], 'status': 'INTEGER_SOURCE_COMPONENT_CORRESPONDENCE_ONLY_NOT_GEOMETRY_OR_ENGINEERING_ADOPTION',
                      'originalSource': row['originalSource'], 'currentResource': current_pin, 'r3': row['r3'],
                      'sourceRecipeBase': row['sourceRecipeBase'], 'sourceMembers': row['sourceMembers'],
                      'sourceMark': row['sourceMark'], 'sourceArchetype': row['sourceArchetype'],
                      'creatorPins': FIRST['creatorPins'],
                      'originalDetailed': {'vertices': detailed.vertices, 'faces': detailed.faces,
                                           'parts': detailed.parts, 'creatorDeclaredDriveCasingPartIndices': detailed.drive_parts},
                      'originalNative': {'vertices': native.vertices, 'faces': native.faces,
                                        'parts': native.parts, 'creatorDeclaredDriveCasingPartIndices': native.drive_parts},
                      'currentDetailed': {'integerTopologyAndMaterialIndicesMatchOriginal': True,
                                          'declaredMaterialsAndLicencesMatchOriginal': True,
                                          'coordinateTransformationEvaluated': False,
                                          'vertices': len(current['design']['vertices']), 'faces': len(current['design']['faces']),
                                          'sourceMetadata': {key: current['design'].get(key) for key in ['source','appearanceSource','paletteName']},
                                          'appearanceTokenSignatures': {key: {'original': signature(original['design'].get(key)), 'current': signature(current['design'].get(key)),
                                                                            'exactTokenEquality': original['design'].get(key) == current['design'].get(key)}
                                                                       for key in ['faceTextures','textures']}},
                      'currentNative': {'vertices': len(selected['vertices']), 'faces': len(selected['faces']),
                                        'integerGlobalIndexAndMaterialBoundsChecked': True,
                                        'sameOriginalNativeTopologyAndMaterials': same_native,
                                        'componentOwnership': 'ORIGINAL_NATIVE_INTEGER_MAP_ONLY' if same_native else 'UNISSUED_CURRENT_CUSTOM_NATIVE_APPEND_PROVENANCE',
                                        'nativeQualification': 'NOT_EVALUATED; index/cap checks alone confer no qualification'},
                      'retainedCalibrationExactText': row['retainedCurrentCalibrationExact'],
                      'currentGeometryContext': row['currentGeometryContext'],
                      'stockRoles': 'NEW proposed named-operation opaque14/glazing5 kg/m2 roles, not colour inference, measurements, mass results or Root adoption.',
                      'hardware': 'UNISSUED: explicit engine_pair named casings retained as metadata; no mechanism counts/masses/anchors adopted.',
                      'coordinateConversions': 0, 'geometryAreaMassTensorEvaluations': 0,
                      'remaining': 'Current coordinate/scale and any custom-native append/correction provenance remain separate; no original-native substitution, occupied/loaded mass or admission grant.'}
            encoded = (json.dumps(record, indent=2, sort_keys=True) + '\n').encode()
            assert len(encoded) <= FIRST['maximumRecordBytes']
            charge('resultRecords', FIRST['maximumResultRecords'])
            publication_attempted = True
            publish_exclusive(target, encoded)
            results.append({'id': row['id'], 'status': record['status'], 'file': str(target.relative_to(ROOT)),
                            'bytes': len(encoded), 'sha256': hashlib.sha256(encoded).hexdigest(),
                            'originalDetailedFaces': detailed.faces, 'currentNativeFaces': len(selected['faces']),
                            'currentNativeOwnership': record['currentNative']['componentOwnership']})
        except (AssertionError, KeyError, TypeError, ValueError, OSError) as error:
            artifact = artifact_status(target)
            status = ('SOURCE_CORRESPONDENCE_STOP_NO_RECORD' if not publication_attempted and artifact['presence'] == 'ABSENT'
                      else 'PUBLICATION_FAILED' if publication_attempted else 'SOURCE_STOP_ARTIFACT_UNCERTAIN')
            results.append({'id': row['id'], 'status': status, 'artifact': artifact,
                            'error': type(error).__name__ + ': ' + str(error)[:512]})
    receipt = {'status': 'ONE_OWN_INTEGER_METADATA_PASS_NO_GEOMETRY_OR_ENGINEERING_EVALUATION',
               'results': results, 'used': USED, 'inputSHA256': hashlib.sha256(raw_first).hexdigest(),
               'authoringSourceSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               'coordinateConversions': 0, 'geometryAreaMassTensorEvaluations': 0,
               'sourceGeometryWrites': 0, 'originalCreatorImportsOrExecutions': 0,
               'nativeCompilerRendererTests': 0, 'retries': 0}
    target = output / 'result.json'
    try:
        publish_exclusive(target, (json.dumps(receipt, indent=2, sort_keys=True) + '\n').encode())
    except OSError as error:
        print(json.dumps({'status': 'RESULT_PUBLICATION_FAILED', 'artifact': artifact_status(target),
                          'error': str(error)[:512], 'results': results}))
        raise SystemExit(1)
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
