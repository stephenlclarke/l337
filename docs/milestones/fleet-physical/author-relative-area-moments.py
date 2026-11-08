"""One Root-authorized bounded82-source engineering pass; no native/helper execution."""
from pathlib import Path
from fractions import Fraction
import hashlib
import json
import math
import tomllib

ROOT = Path(__file__).resolve().parent
INPUT = ROOT / 'relative-area-moment-roles-first.json'
EXPECTED = '5283fe8d7b64ebe47c7ca5e7245d7c4b9f3c7da4e58112b5583d6f9f494b2c33'
raw_input = INPUT.read_bytes()
assert hashlib.sha256(raw_input).hexdigest() == EXPECTED
FIRST = json.loads(raw_input)
SOURCE = Path(FIRST['sourceRoot'])
OUTPUT = ROOT / 'calculated-relative-records'
RESULT = ROOT / 'relative-area-moment-results.json'
assert not OUTPUT.exists() and not RESULT.exists(), 'No overwrite or repeated numerical pass'
OUTPUT.mkdir()
TOTAL = {k: 0 for k in FIRST['totalOperationBounds']}
MAXIMUM_RECORD_BYTES = 1_048_576
results = []


def approximately(a, b):
    return math.isfinite(a) and math.isfinite(b) and abs(a-b) <= 1e-9*max(1, abs(a), abs(b))


for row in FIRST['rows']:
    used = {k: 0 for k in row['operationBounds']}

    def charge(key, count=1):
        assert used[key]+count <= row['operationBounds'][key], (row['id'], key, 'row bound')
        assert TOTAL[key]+count <= FIRST['totalOperationBounds'][key], (key, 'whole bound')
        used[key] += count
        TOTAL[key] += count

    try:
        source = row['source']
        raw = (SOURCE/source['geometryPath']).read_bytes()
        assert len(raw) == source['geometryBytes']
        assert hashlib.sha256(raw).hexdigest() == source['geometrySHA256']
        ownership_raw = Path(row['ownershipPath']).read_bytes()
        assert hashlib.sha256(ownership_raw).hexdigest() == row['ownershipSHA256']
        ownership = json.loads(ownership_raw)
        assert ownership['id'] == row['id']
        components = ownership['models']['design']['parts']
        assert row['frame']['declaredForwardAxis'] == '+Z' and row['frame']['declaredUpAxis'] == '+Y'
        charge('sourceParses')
        document = tomllib.loads(raw.decode(), parse_float=str)
        assert document['proposal']['id'] == row['id']
        design = document['design']
        assert len(design['vertices']) == row['detailedVertices']
        assert len(design['faces']) == len(design['faceMaterials']) == row['detailedFaces']
        vertices = []
        for original in design['vertices']:
            assert len(original) == 3
            charge('coordinateConversions', 3)
            point = [float(x) for x in original]
            assert all(math.isfinite(x) for x in point)
            vertices.append(point)
        low = high = vertices[0][2]
        low_token = high_token = design['vertices'][0][2]
        for point, original in zip(vertices, design['vertices']):
            charge('spanComparisons', 2)
            if point[2] < low:
                low, low_token = point[2], original[2]
            if point[2] > high:
                high, high_token = point[2], original[2]
        span = Fraction(str(high_token))-Fraction(str(low_token))
        target = Fraction(str(row['targetDetailedLengthMetres']))
        assert span > 0 and target > 0
        ratio = target/span
        scale = float(ratio)
        assert math.isfinite(scale) and scale > 0
        physical = []
        for point in vertices:
            charge('scaledCoordinateEvaluations', 3)
            physical.append([x*scale for x in point])
        parts = []
        next_face = next_vertex = 0
        for component in components:
            assert component['faceStart'] == next_face and component['vertexStart'] == next_vertex
            density = component['stockKgPerSquareMetre']
            assert density in [5, 14]
            allowed = component.get('allowedSourceMaterials')
            if allowed is None:
                allowed = [r['material'] for r in component['exactMaterialRuns']]
            area_terms, mass_terms = [], []
            area_first = [[] for _ in range(3)]
            first = [[] for _ in range(3)]
            second = [[] for _ in range(9)]
            check_second = [[] for _ in range(9)]
            end = component['vertexStart']+component['vertexCount']
            for index in range(component['faceStart'], component['faceStart']+component['faceCount']):
                face = design['faces'][index]
                assert len(face) == 3
                for vertex in face:
                    charge('faceIndexChecks')
                    assert type(vertex) is int and component['vertexStart'] <= vertex < end
                charge('faceMaterialChecks')
                assert design['faceMaterials'][index] in allowed
                a, b, c = [physical[v] for v in face]
                charge('triangleAreaEvaluations')
                u, v = [b[i]-a[i] for i in range(3)], [c[i]-a[i] for i in range(3)]
                cross = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
                area = math.sqrt(math.fsum(x*x for x in cross))/2
                assert math.isfinite(area) and area > 0, (row['id'], component['name'], index, 'nonpositive area')
                mass = area*density
                sums = [math.fsum([a[i], b[i], c[i]]) for i in range(3)]
                area_terms.append(area)
                mass_terms.append(mass)
                for i in range(3):
                    area_first[i].append(area*sums[i]/3)
                    first[i].append(mass*sums[i]/3)
                charge('analyticMomentEvaluations')
                for i in range(3):
                    for j in range(3):
                        second[3*i+j].append(mass*math.fsum([
                            sums[i]*sums[j], a[i]*a[j], b[i]*b[j], c[i]*c[j]])/12)
                # Independent degree2 quadrature; source arithmetic only, never a native query.
                corners = [a, b, c]
                for heavy in range(3):
                    charge('quadratureMomentEvaluations')
                    point = [math.fsum(corners[k][i]*(2/3 if k == heavy else 1/6)
                                       for k in range(3)) for i in range(3)]
                    for i in range(3):
                        for j in range(3):
                            check_second[3*i+j].append((mass/3)*(point[i]*point[j]))
            area = math.fsum(area_terms)
            mass = math.fsum(mass_terms)
            m1 = [math.fsum(x) for x in first]
            m2 = [math.fsum(x) for x in second]
            q2 = [math.fsum(x) for x in check_second]
            assert area > 0 and mass > 0 and all(math.isfinite(x) for x in m1+m2+q2)
            assert all(approximately(a, b) for a, b in zip(m2, q2)), (
                row['id'], component['name'], 'analytic/quadrature second moment')
            parts.append(dict(index=component['index'], name=component['name'],
                              faceStart=component['faceStart'], faceCount=component['faceCount'],
                              areaSquareMetres=area, stockKgPerSquareMetre=density, stockMassKg=mass,
                              areaCentroidMetres=[math.fsum(x)/area for x in area_first],
                              massFirst=m1, massSecond=m2, verificationSecond=q2))
            next_face += component['faceCount']
            next_vertex += component['vertexCount']
        assert next_face == len(design['faces']) and next_vertex == len(physical)
        stock_mass = math.fsum(p['stockMassKg'] for p in parts)
        stock_first = [math.fsum(p['massFirst'][i] for p in parts) for i in range(3)]
        stock_second = [math.fsum(p['massSecond'][i] for p in parts) for i in range(9)]
        hardware = []
        for item in row['intrinsicHardware']:
            charge('hardwareAllocations')
            part = parts[item['anchorComponent']]
            assert part['name'] == item['anchorName']
            point = part['areaCentroidMetres']
            mass = item['eachKg']*item['count']
            assert type(item['count']) is int and item['count'] > 0 and mass > 0
            hardware.append(dict(**item, massKg=mass, anchorMetres=point))
        hardware_mass = math.fsum(h['massKg'] for h in hardware)
        mass = stock_mass+hardware_mass
        first = [math.fsum([stock_first[i]]+[h['massKg']*h['anchorMetres'][i] for h in hardware]) for i in range(3)]
        second = [math.fsum([stock_second[3*i+j]]+[
            h['massKg']*(h['anchorMetres'][i]*h['anchorMetres'][j]) for h in hardware])
            for i in range(3) for j in range(3)]
        assert math.isfinite(mass) and mass > 0
        centre = [x/mass for x in first]
        trace = math.fsum([second[0], second[4], second[8]])
        origin = [(trace if i == j else 0)-second[3*i+j] for i in range(3) for j in range(3)]
        squared = math.fsum(x*x for x in centre)
        tensor = [origin[3*i+j]-mass*((squared if i == j else 0)-centre[i]*centre[j])
                  for i in range(3) for j in range(3)]
        assert all(math.isfinite(x) for x in centre+origin+tensor)
        for i in range(3):
            for j in range(3):
                assert approximately(tensor[3*i+j], tensor[3*j+i])
        a, b, c, d, e, f, g, h, i = tensor
        minors = [a, a*e-b*d, a*(e*i-f*h)-b*(d*i-f*g)+c*(d*h-e*g)]
        assert all(math.isfinite(x) and x > 0 for x in minors)
        rounded = math.ceil(mass)
        reserve = rounded-mass
        assert 0 <= reserve < 1
        charge('resultRecords')
        record = dict(schemaVersion=1, id=row['id'], status='NEW_AUTHORED_SOURCE_BUDGET_NOT_NATIVE_QUALIFICATION',
                      contractSHA256=row['contractSHA256'], detailedSourceSHA256=source['geometrySHA256'],
                      componentSourceSHA256=row['ownershipSHA256'], roleMapSHA256=EXPECTED,
                      policyProposalSHA256=FIRST['policyProposalSHA256'], coordinateUnits='metres',
                      sourceCoordinateUnits='Relative original units; no recovered SI declaration.',
                      metresPerSourceUnit=scale, metresPerSourceUnitExact=str(ratio),
                      sourceZSpanExact=str(span), sourceMinZToken=str(low_token), sourceMaxZToken=str(high_token),
                      targetDetailedLengthMetres=row['targetDetailedLengthMetres'],
                      scaleStatus='NEW_ROOT_ADOPTED_UNIFORM_ENGINEERING_SCALE_NOT_RECOVERED',
                      sourceOriginUnchanged=True, sourceGeometryNotEdited=True,
                      sourceStockAreaSquareMetres=math.fsum(p['areaSquareMetres'] for p in parts),
                      stockMassKg=stock_mass, intrinsicHardwareMassKg=hardware_mass, unroundedMassKg=mass,
                      dryMassKilograms=rounded, roundingReserveKg=reserve, reserveLocationMetres=centre,
                      centreOfMassMetres=centre, inertiaAboutCentreOfMassKgM2=tensor,
                      sourceOriginInertiaBeforeReserveKgM2=origin, positiveLeadingPrincipalMinors=minors,
                      stockComponents=parts, intrinsicHardware=hardware, zeroAreaSourceFaces=0,
                      operations=dict(used), objectKind=row['objectKind'], origin=row['origin'],
                      actualNativePopulation='UNISSUED_BY_THIS_BUDGET; neither zero people nor automation is inferred.',
                      occupiedPeopleCabinsPaidEquipmentGranted=False, actualPortsProvidersOrServiceRightsGranted=False,
                      nativeQualification='UNRUN; this engineering model grants no actor/physical/native qualification.')
        encoded = (json.dumps(record, separators=(',', ':'), allow_nan=False)+'\n').encode()
        assert len(encoded) <= MAXIMUM_RECORD_BYTES
        path = OUTPUT/(row['id']+'.json')
        path.write_bytes(encoded)
        results.append(dict(id=row['id'], status='AUTHORED_SOURCE_BUDGET', file=str(path.relative_to(ROOT)),
                            bytes=len(encoded), sha256=hashlib.sha256(encoded).hexdigest(),
                            dryMassKg=rounded, metresPerSourceUnit=scale, metresPerSourceUnitExact=str(ratio),
                            operations=dict(used)))
    except Exception as error:
        results.append(dict(id=row['id'], status='STOPPED_NO_MASS_RECORD',
                            error=type(error).__name__+': '+str(error)[:512], operations=dict(used)))

summary = dict(status='ONE_BOUNDED_82_SOURCE_ENGINEERING_PASS_NOT_NATIVE_QUALIFICATION',
               roleMapSHA256=EXPECTED, authoringSourceSHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               results=results, operations=TOTAL, caps=FIRST['totalOperationBounds'], retries=0,
               sourceGeometryWrites=0, originalCreatorImportsOrExecutions=0, nativeCompilerRendererTests=0)
RESULT.write_text(json.dumps(summary, indent=2)+'\n')
print('Source budgets authored:', sum(r['status']=='AUTHORED_SOURCE_BUDGET' for r in results),
      'stopped:', sum(r['status']!='AUTHORED_SOURCE_BUDGET' for r in results))
for result in results:
    if result['status'] != 'AUTHORED_SOURCE_BUDGET':
        print(result['id'], result['error'])
