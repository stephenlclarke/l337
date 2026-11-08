"""One bounded15 Larvaal source-resource copy pass; no geometry math or native execution."""
from pathlib import Path
from decimal import Decimal
import hashlib
import json
import re
import tomllib


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def value(v):
    if isinstance(v, bool):
        return str(v).lower()
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, list):
        return '[' + ', '.join(value(x) for x in v) + ']'
    if isinstance(v, dict):
        return '{ ' + ', '.join(k + ' = ' + value(x) for k, x in v.items()) + ' }'
    raise TypeError(type(v))


def table(name, fields):
    return '[' + name + ']\n' + ''.join(k + ' = ' + value(v) + '\n' for k, v in fields.items())


def block(text, name):
    start = text.index('[' + name + ']')
    rest = text[start:]
    end = re.search(r'\n\[', rest)
    return rest[:end.start() if end else len(rest)].rstrip() + '\n'


base = Path(__file__).resolve().parent
repo = base.parent.parent
first = json.loads((base / 'larvaal-current-resource-input-first.json').read_text())
authoring_first = json.loads((base / 'larvaal-current-resource-authoring-first.json').read_text())
assert digest(Path(__file__).read_bytes()) == authoring_first['authoringSourceSHA256']
assert digest((base / 'larvaal-current-resource-input-first.json').read_bytes()) == authoring_first['inputSHA256']
backlog_bytes = (repo / 'docs/FLEET-BACKLOG.json').read_bytes()
assert digest(backlog_bytes) == first['backlogSHA256']
rows = {r['id']: r for r in json.loads(backlog_bytes)['entries']}
result = base / 'larvaal-current-resource-results.json'
assert not result.exists(), 'Frozen output exists; no rerun or overwrite.'
assert len(first['records']) == first['maximumRows'] == 15
prepared = []
source_parses = 0
for pin in first['records']:
    id = pin['id']
    row = rows[id]
    r3 = row['contract']
    assert row['contractSHA256'] == pin['contractSHA256']
    documents = {}
    source = {}
    display_sha = None
    for entry in pin['sourceFiles']:
        path = Path(entry['path'])
        if entry['path'] not in documents:
            raw = path.read_bytes()
            assert len(raw) == entry['bytes'] and digest(raw) == entry['sha256']
            if entry['kind'] == 'original-toml':
                text = raw.decode()
                parsed = tomllib.loads(text)
                unit = parsed['proposal'].get('coordinateUnits')
                assert unit == ('metres' if pin['metresPerSourceUnitExact'] == '1' else None)
            else:
                assert id == 'SH123' and entry['kind'] == 'accepted-display-json'
                parsed = json.loads(raw)
                assert parsed['id'] == id and parsed['sourceSHA256'] == pin['detailedSourceSHA256']
                text = None
            documents[entry['path']] = (text, parsed)
            source_parses += 1
        text, parsed = documents[entry['path']]
        if entry['role'] == 'detailed-display-only':
            detailed = parsed[entry['block']]
            source['detailed'] = (table('design', detailed), detailed, pin['detailedSourceSHA256'])
            display_sha = entry['sha256']
        else:
            source[entry['role']] = (block(text, entry['block']), parsed[entry['block']], entry['sha256'])
    detailed = source['detailed'][1]
    native = source.get('native', (None, None, None))[1]
    if native is not None:
        assert len(native['faces']) > 0 and all(len(face) == 3 for face in native['faces'])
    destination = repo / 'Sources/L337Core/Resources/Ships' / (id + '.toml')
    assert digest(destination.read_bytes()) == pin['oldResourceSHA256']
    physical = repo / 'Sources/L337Core/Resources/OriginalFleetPhysical' / (id + '.json')
    if pin['physicalRecordSHA256'] is not None:
        assert digest(physical.read_bytes()) == pin['physicalRecordSHA256']
    else:
        assert not physical.exists()
    capital = r3['capital']
    assert r3['origin'] == 'larvaal' and r3['objectKind'] == 'ship'
    assert r3['access']['purchasePolicy'] == pin['plannedPurchasePolicy']
    header = dict(id=id, name=r3['name'], shipClass='Ship', appearances='L337',
                  evidence='Current original R3 ' + pin['contractSHA256'], refit=False,
                  model='L337-' + id, modelSource='Original L337',
                  dimensions=r3['geometry']['dimensionsWHLMetres'],
                  geometryContext='Exact current original Larvaal source; no source coordinate, topology, material or appearance changes. Unit/engineering/native evidence is per-ID and unissued where absent. Display selection grants no native or physical authority.')
    metadata = dict(schemaVersion=2, family=r3['family'], aliases=[], objectKind='ship',
                    origin='alien', primaryType='alien',
                    roleWeights=[], access='normal', playerFlyable=False,
                    normalPurchaseEligible=False, purchasePolicy=pin['runtimePolicy'],
                    isCapital=capital,
                    collectionMilestone='destruction' if capital else ('blueprintAndFabrication' if pin['runtimePolicy'] == 'pendingFabrication' else 'none'),
                    damagePolicy='destructible', discoveryEligible=pin['runtimePolicy'] == 'pendingFabrication' or capital, encounterMode='authored',
                    mechanicsStatus='pending', placementStatus='pending', rarity='pending',
                    galaxies=[], regions=[], authoredSystems=[],
                    basis='Current original source replacement. Native qualification, actual actor admission, population and fabrication technology policy remain unissued. Source presence and engineering estimates grant no flight, blueprint, paid equipment or collection credit.')
    if capital:
        metadata['capitalSubtype'] = 'vessel'
    p = r3['performance']
    game_map = dict(cargo='cargoTonnes', speed='maxSpeed', acceleration='acceleration',
                    energy='energyCapacity', recharge='energyRecharge', roll='roll', pitch='pitch', yaw='yaw',
                    shield='shieldCapacityPerBank', shieldRecharge='shieldRechargePerBank',
                    jump='maxJumpLY', spool='jumpChargeSeconds', missiles='missileCapacity',
                    facings='laserFacingMask', cargoExpansion='cargoExpansionTonnes', price='hullPriceCR')
    game = {k: p[v] for k, v in game_map.items()}
    fuel = Decimal(str(p['fuelTankLY'])) * 10
    assert fuel == fuel.to_integral_value()
    game['fuel'] = int(fuel)
    game['workTools'] = [x for x in r3['fitting']['compatibleUtilities'] if x in ['miningLaser', 'salvageCutter']]
    basis = 'Current R3 ships/' + id + '.toml / ' + pin['contractSHA256'] + '. Authored requirements; no installed items or entitlement.'
    status = 'current original source; native and actual game acceptance pending'

    def field(key, label, v, unit='authored'):
        f = dict(key=key, label=label, text=value(v) if not isinstance(v, str) else v,
                 unit=unit, status=status, basis=basis)
        if isinstance(v, (int, float)) and not isinstance(v, bool):
            f['number'] = v
        return f

    standard_keys = {
        'cargo': ('cargo_tonnes', 't'),
        'speed': ('maximum_speed_project_units', 'project units/s'),
        'acceleration': ('acceleration_project_units_per_second_squared', 'project units/s^2'),
        'energy': ('hull_energy', 'native energy units'),
        'recharge': ('energy_recharge_per_second', 'native energy units/s'),
        'roll': ('roll_radians_per_second', 'rad/s'),
        'pitch': ('pitch_radians_per_second', 'rad/s'),
        'yaw': ('yaw_radians_per_second', 'rad/s'),
        'shield': ('fore_shield_max', 'native energy units'),
        'shieldRecharge': ('fore_shield_recharge_per_second', 'native energy units/s'),
        'jump': ('hyperspace_range_ly', 'LY'), 'spool': ('jump_spool_seconds', 's'),
        'missiles': ('missile_capacity', 'missiles'), 'facings': ('laser_facing_mask', 'mask'),
        'cargoExpansion': ('cargo_expansion_tonnes', 't'), 'price': ('hull_price_credits', 'CR'),
        'fuel': ('fuel_capacity_tenths_ly', '0.1 LY'), 'workTools': ('compatible_work_tools', 'capability')}
    standards = [field(standard_keys[k][0], k, v, standard_keys[k][1]) for k, v in game.items()]
    for key, v, unit in [
        ('hold_used_by_cabins', 0, 't'), ('usable_cargo_after_fit', game['cargo'], 't'),
        ('required_crew_including_commander', r3['accommodation']['minimumOperatingCrewIncludingCommander'], 'people'),
        ('reserved_crew_accommodation', r3['accommodation']['intrinsicCrewPlaces'], 'people'),
        ('equipment_capacity_units', r3['fitting']['equipmentBudgetUnits'], 'equipment units'),
        ('initial_charter_passenger_berths', 0, 'people'),
        ('utility_mounts', r3['fitting']['utilityMounts'], 'mounts')]:
        standards.append(field(key, key, v, unit))
    planning = [field('r3.' + section + '.' + k, k, v) for section in ['accommodation', 'fitting', 'acquisition']
                for k, v in r3.get(section, {}).items()]
    provenance = [field('r3.sha256', 'Current contract SHA256', pin['contractSHA256']),
                  field('original.geometry_sha256', 'Detailed source SHA256', pin['detailedSourceSHA256']),
                  field('physical.unit_scale_exact', 'Metres per source unit', pin['metresPerSourceUnitExact']),
                  field('physical.status', 'Engineering/native source status', pin['physicalStatus']),
                  field('r3.access.purchasePolicy', 'Authored future purchase policy', pin['plannedPurchasePolicy']),
                  field('r3.access.missionGate', 'Authored mission requirement; no issuer or entitlement', r3['access']['missionGate'])]
    if pin['nativeSourceSHA256'] is not None:
        provenance.append(field('original.native_geometry_sha256', 'Selected native source SHA256', pin['nativeSourceSHA256']))
    if pin['physicalRecordSHA256'] is not None:
        provenance.append(field('physical.record_sha256', 'Engineering source record SHA256', pin['physicalRecordSHA256']))
    if display_sha is not None:
        provenance.append(field('original.display_resource_sha256', 'Accepted immutable display bytes SHA256', display_sha))
    profiles = [dict(id='ORIGINAL-' + id + '-R3-STANDARD', title=r3['name'] + ' current bare specification',
                     group='project-refit-v1', context=basis, fields=standards),
                dict(id='ORIGINAL-' + id + '-R3-PLANNING', title='Original crew and fitting requirements',
                     group='l337-original-r3-planning', context=basis, fields=planning),
                dict(id='ORIGINAL-' + id + '-CURRENT-SOURCE', title='Current original source provenance',
                     group='l337-original-source-provenance', context=basis, fields=provenance)]
    output = '# Original source replacement; pending native qualification and actual game acceptance.\n'
    output += ''.join(k + ' = ' + value(v) + '\n' for k, v in header.items()) + '\n'
    output += table('catalogue', metadata) + '\n' + table('game', game) + '\n'
    output += source['detailed'][0] + '\n'
    if native is not None:
        output += source['native'][0] + '\n'
    for profile in profiles:
        output += '[[profiles]]\n' + ''.join(k + ' = ' + value(v) + '\n' for k, v in profile.items()) + '\n'
    output = output.rstrip() + '\n'
    decoded = tomllib.loads(output)
    assert decoded['design'] == detailed and decoded.get('nativeDesign') == native
    assert decoded['game'] == game and decoded['catalogue'] == metadata
    assert len(output.encode()) <= pin['maximumOutputBytes']
    prepared.append((destination, output.encode(), dict(id=id, name=r3['name'], family=r3['family'],
                    resourceSHA256=digest(output.encode()), detailedSHA256=source['detailed'][2],
                    nativeSHA256=pin['nativeSourceSHA256'], r3SHA256=pin['contractSHA256'],
                    physicalRecordSHA256=pin['physicalRecordSHA256'],
                    detailedVertices=len(detailed['vertices']), detailedFaces=len(detailed['faces']),
                    nativeFaces=len(native['faces']) if native is not None else 0, metresPerSourceUnitExact=pin['metresPerSourceUnitExact'],
                    physicalStatus=pin['physicalStatus'], displayResourceSHA256=display_sha, nativeQualification='UNRUN; missing role/scale/native/source evidence is never a default or grant', bytes=len(output.encode()))))

assert source_parses == first['maximumUniqueSourceParses']
# Commit no partial source batch before every fixed input and output has passed source equality.
for destination, output, record in prepared:
    destination.write_bytes(output)
result.write_text(json.dumps(dict(status='SOURCE_AUTHORED_UNCOMPILED_UNRUN_NOT_ACTIVATED',
                                 sourceParses=source_parses, outputParses=15, resourceWrites=len(prepared), coordinateTransformations=0,
                                 authoringSourceSHA256=digest(Path(__file__).read_bytes()), retries=0,
                                 records=[r for _, _, r in prepared]), indent=2) + '\n')
print('Authored', len(prepared), 'current Larvaal source resources; native/source-role/quest gaps remain explicit.')
