"""One six-source integer ownership pass; no original creator or geometry evaluation."""
from pathlib import Path
import hashlib
import json
import tomllib

ROOT = Path(__file__).resolve().parent
FIRST = json.loads((ROOT / 'distinct-creator-ownership-first.json').read_text())
SOURCE = Path(FIRST['sourceRoot'])
OUTPUT = ROOT / 'distinct-creator-ownership-records'
assert not OUTPUT.exists(), 'No overwrite or repeated authoring pass'
USED = dict(sourceParses=0, partRecords=0, faceIndexChecks=0, faceMaterialChecks=0)
for pin in FIRST['creators']:
    raw = (SOURCE / pin['path']).read_bytes()
    assert len(raw) == pin['bytes'] and hashlib.sha256(raw).hexdigest() == pin['sha256']


class Parts:
    def __init__(self, domain):
        self.domain = domain
        self.parts = []
        self.vertices = 0
        self.faces = 0
        self.propulsion = []
        self.sensory = []

    def add(self, name, vertices, faces, materials, method, role='opaque-stock'):
        USED['partRecords'] += 1
        assert USED['partRecords'] <= FIRST['maximumPartRecords']
        part = dict(index=len(self.parts), name=name, vertexStart=self.vertices,
                    vertexCount=vertices, faceStart=self.faces, faceCount=faces,
                    allowedSourceMaterials=materials, creatorMethod=method,
                    creatorDomain=self.domain, role=role,
                    stockKgPerSquareMetre=5 if role == 'explicit-glass-stock' else 14)
        self.parts.append(part)
        self.vertices += vertices
        self.faces += faces
        return part['index']

    def loft(self, name, rings, sides, material, role='opaque-stock'):
        return self.add(name, rings * sides, 2 * rings * sides - 4, [material],
                        'Hull.loft / Hull.solid', role)

    def plate(self, name, material):
        self.add(name, 8, 12, [material], 'Hull.panel or vulture.plate',
                 'explicit-glass-stock' if material == 4 else 'opaque-stock')

    def belt(self, name, rings, sides, material):
        self.add(name, 2 * rings * sides, 4 * rings * sides, [material], 'vulture.cockpit_band',
                 'explicit-glass-stock' if material == 4 else 'opaque-stock')


def vulture(native):
    h = Parts('generate.py vulture(mark, native), exact mirrored append operations')
    n = 12 if native else 20
    belt_n = 24 if native else 48
    h.loft('primary stocky pressure hull', 6, n, 0)
    h.loft('rounded connected cockpit support body', 5, n, 3)
    h.belt('continuous 360-degree cockpit viewing belt', 3, belt_n, 4)
    h.belt('lower hollow viewing-belt rail', 2, belt_n, 3)
    h.belt('upper hollow viewing-belt rail', 2, belt_n, 3)
    half = Parts('generate.py vulture literal half before reflection')
    for angle in range(6):
        for z in range(4):
            half.plate('cockpit deck inlay ' + str(angle) + '-' + str(z), 4)
    half.plate('planar shoulder bridge', 0)
    for column in range(2 if native else 4):
        for row in range(2 if native else 3):
            half.plate('shoulder service patch ' + str(column) + '-' + str(row), 6)
            if not native:
                for i in range(3):
                    half.plate('shoulder recessed strip ' + str(i), 3)
    drive = half.loft('heavy drive pod casing', 4, n, 3)
    half.loft('heavy drive pod luminous throat', 2, n, 5)
    for angle in range(9):
        for z in range(3):
            half.plate('forward pod armour ' + str(angle) + '-' + str(z), 0)
            if not native:
                for i in range(3):
                    half.plate('recessed pod armour strip ' + str(i), 3)
    for angle in range(4):
        for z in range(4):
            half.plate('main body service patch ' + str(angle) + '-' + str(z), 6)
            if not native:
                for i in range(3):
                    half.plate('main body recessed strip ' + str(i), 3)
    half.loft('forward barrel sensor', 2, n, 2)
    for sign in ['positive X original half', 'negative X reflected half']:
        start = len(h.parts)
        for part in half.parts:
            h.add(sign + '/' + part['name'], part['vertexCount'], part['faceCount'],
                  part['allowedSourceMaterials'], part['creatorMethod'], part['role'])
        h.propulsion.append(start + drive)
    return h


def sovereign(native):
    h = Parts('sovereign_design.py build(native)')
    sweep_v, sweep_f = (480, 960) if native else (3456, 6912)
    ellipsoid_v, ellipsoid_f = (602, 1200) if native else (3746, 7488)

    def sweep(name, material):
        h.add(name, sweep_v, sweep_f, [material], 'Hull.sweep / Hull.raw')

    def ellipsoid(name, material):
        return h.add(name, ellipsoid_v, ellipsoid_f, [material], 'Hull.ellipsoid / Hull.raw')

    for side in ['negative side', 'positive side']:
        sweep(side + '/longitudinal crescent carapace', 0)
        sweep(side + '/smooth inset crescent fold', 1)
        ellipsoid(side + '/end growth', 0)
    sweep('arched oval vault', 0)
    sweep('raised oval vault lip', 4)
    ellipsoid('central living core', 5)
    for i in range(3):
        sweep('central reserve structural collar ' + str(i), 1)
    for side in ['negative side', 'positive side']:
        # The exact creator explicitly calls these sensory organs, not engine pods.
        h.sensory.append(ellipsoid(side + '/recessed rear sensory organ', 5))
    return h


def drone(design):
    h = Parts('generate.py larvaal(native), explicit four closed shell intervals and one core')
    starts = [0]
    materials = design['faceMaterials']
    for face in range(1, len(materials)):
        previous, current = materials[face - 1], materials[face]
        if (previous == 1 and current in [0, 3, 4]) or (previous != 2 and current == 2):
            starts.append(face)
    assert len(starts) == 5, ('drone interval boundary count', len(starts))
    for i, start in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else len(materials)
        indices = [index for face in design['faces'][start:end] for index in face]
        low, high = min(indices), max(indices) + 1
        assert low == h.vertices
        name = 'closed jade shell source interval ' + str(i) if i < 4 else 'single complete gold core sphere'
        h.add(name, high - low, end - start, [0, 1, 3, 4] if i < 4 else [2],
              'larvaal.patch outer/inner/edge closure' if i < 4 else 'larvaal.patch complete core')
    return h


def medusa(native, design):
    h = Parts('selected organic generate.py design(native), selected source provenance')
    steps = 20 if native else 36

    def tube(name, material, sides=None):
        return h.loft(name, steps, sides if sides is not None else (16 if native else 28), material)

    tube('central grown seed carapace', 0, 48 if native else 72)
    for i in range(4):
        tube('central flowing surface fold ' + str(i), 3, 8 if native else 12)
    for i in range(2):
        tube('central crown connected cartilage ' + str(i), 4)
    for i in range(8):
        # Explicit creator declaration: eight seed-like propulsion organs, not a default count.
        h.propulsion.append(tube('curved seed propulsion organ ' + str(i), 0))
        tube('propulsion organ connected stem ' + str(i), 1)
        for fold in range(3):
            tube('propulsion organ breathing fold ' + str(i) + '-' + str(fold), 3, 8 if native else 12)
        h.loft('inward forward gland ' + str(i), steps, 12 if native else 20, 6)
        tube('warm outer tendon ' + str(i), 2, 8 if native else 10)
    rows, sides = (144, 16) if native else (256, 24)
    h.add('continuous rounded elliptical living crown', rows * sides, 2 * rows * sides, [5],
          'Hull.grown_crown / Hull.raw')
    for i in range(8):
        h.loft('inward rear glowing blob ' + str(i), 12 if native else 20, 12 if native else 20, 6)
    # The creator's projection spacing uses evaluated arc lengths. Do not reevaluate
    # those curves. Read the exact remaining appended dot inventory as integers only.
    dot_v, dot_f = (42, 80) if native else (62, 120)
    remaining_v = len(design['vertices']) - h.vertices
    remaining_f = len(design['faces']) - h.faces
    assert remaining_v >= 0 and remaining_v % dot_v == 0
    assert remaining_f == (remaining_v // dot_v) * dot_f
    for i in range(remaining_v // dot_v):
        h.add('appended luminous projection dot ' + str(i), dot_v, dot_f, [6],
              'Hull.forward_projection_trails/rear_projection_trails / Hull.glowing_dot')
    return h


def verify(h, design):
    assert len(design['vertices']) == h.vertices <= FIRST['maximumVerticesPerDesign']
    assert len(design['faces']) == h.faces <= FIRST['maximumFacesPerDesign']
    assert len(design['faceMaterials']) == h.faces
    for part in h.parts:
        for index in range(part['faceStart'], part['faceStart'] + part['faceCount']):
            USED['faceMaterialChecks'] += 1
            assert USED['faceMaterialChecks'] <= FIRST['maximumFaceMaterialChecks']
            assert design['faceMaterials'][index] in part['allowedSourceMaterials'], (
                h.domain, part['name'], 'material', index, design['faceMaterials'][index])
            face = design['faces'][index]
            assert len(face) == 3
            for vertex in face:
                USED['faceIndexChecks'] += 1
                assert USED['faceIndexChecks'] <= FIRST['maximumFaceIndexChecks']
                assert part['vertexStart'] <= vertex < part['vertexStart'] + part['vertexCount'], (
                    h.domain, part['name'], 'owned index', index, vertex)


records, stops = [], []
for row in FIRST['rows']:
    try:
        raw = (SOURCE / row['geometryPath']).read_bytes()
        assert len(raw) == row['geometryBytes'] and hashlib.sha256(raw).hexdigest() == row['geometrySHA256']
        USED['sourceParses'] += 1
        assert USED['sourceParses'] <= FIRST['maximumSourceParses']
        document = tomllib.loads(raw.decode(), parse_float=str)
        models = {}
        for key, native in [('design', False), ('nativeDesign', True)]:
            design = document[key]
            if row['id'] in ['SH037', 'SH038', 'SH039']:
                h = vulture(native)
            elif row['id'] == 'SH123':
                h = sovereign(native)
            elif row['id'] == 'SH125':
                h = drone(design)
            elif row['id'] == 'SH171':
                h = medusa(native, design)
            else:
                raise ValueError('No creator domain')
            verify(h, design)
            models[key] = dict(parts=h.parts, creatorDeclaredPropulsionPartIndices=h.propulsion,
                               creatorDeclaredSensoryPartIndices=h.sensory,
                               vertices=h.vertices, faces=h.faces)
        records.append(dict(id=row['id'], geometrySHA256=row['geometrySHA256'],
                            contractSHA256=row['contractSHA256'],
                            status='EXACT_SOURCE_OWNERSHIP_NEW_STOCK_DECLARATIONS_NOT_PHYSICAL_QUALIFICATION',
                            models=models, proposedStock='New explicit structural/organ-envelope stock equivalent14kg/m2; named Vulture glass equivalent5kg/m2 only. No recovered tissue/density or mechanism mass.',
                            units='Exact frame evidence is separate; no source scale or coordinates evaluated.',
                            hardware='Source organ/casing function recorded where explicit; no human system defaults or mass granted.'))
    except (AssertionError, KeyError, ValueError) as error:
        stops.append(dict(id=row['id'], status='STOP_NO_RETRY_NO_GEOMETRY_CHANGE', reason=str(error)))

OUTPUT.mkdir()
for record in records:
    (OUTPUT / (record['id'] + '.json')).write_text(json.dumps(record, indent=2) + '\n')
result = dict(status='SOURCE_ONLY_FIRST_PASS_NO_GEOMETRY_OR_PHYSICS_EXECUTION', records=len(records),
              stops=stops, operations=USED, coordinateConversions=0, spanAreaMassTensorEvaluations=0,
              originalCreatorImportsOrExecutions=0, geometryWrites=0, nativeExecutions=0)
(ROOT / 'distinct-creator-ownership-results.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
