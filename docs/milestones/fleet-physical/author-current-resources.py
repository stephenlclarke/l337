"""One bounded source-authoring pass; no geometry changes or native qualification."""
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
first = json.loads((base / 'resource-replacement-first.json').read_text())
backlog_bytes = (repo / 'docs/FLEET-BACKLOG.json').read_bytes()
assert digest(backlog_bytes) == first['backlogSHA256']
rows = {r['id']: r for r in json.loads(backlog_bytes)['entries']}
root = Path(first['sourceRoot'])
result = base / 'resource-replacement-results.json'
assert not result.exists(), 'Frozen output exists; no rerun or overwrite.'
assert len(first['records']) == first['maximumRows'] == 49
prepared = []
for pin in first['records']:
    id = pin['id']
    row = rows[id]
    r3 = row['contract']
    assert row['contractSHA256'] == pin['contractSHA256']
    source = {}
    for entry in pin['sources']:
        raw = (root / entry['path']).read_bytes()
        assert len(raw) == entry['bytes'] and digest(raw) == entry['sha256']
        text = raw.decode()
        parsed = tomllib.loads(text)
        assert parsed['proposal']['coordinateUnits'] == 'metres'
        source[entry['role']] = (text, parsed, entry)
    detailed = source['detailed'][1]['design']
    native = source['native'][1]['nativeDesign']
    assert 0 < len(native['faces']) <= 512
    assert all(len(face) == 3 for face in native['faces'])
    destination = repo / 'Sources/L337Core/Resources/Ships' / (id + '.toml')
    assert digest(destination.read_bytes()) == pin['oldResourceSHA256']
    physical = repo / 'Sources/L337Core/Resources/OriginalFleetPhysical' / (id + '.json')
    assert digest(physical.read_bytes()) == pin['physicalRecordSHA256']
    capital = r3['capital']
    assert r3['origin'] == 'human' and r3['objectKind'] == 'ship'
    assert r3['access']['purchasePolicy'] == ('never' if capital else 'blueprintFabrication')
    header = dict(id=id, name=r3['name'], shipClass='Ship', appearances='L337',
                  evidence='Current original R3 ' + pin['contractSHA256'], refit=False,
                  model='L337-' + id, modelSource='Original L337',
                  dimensions=r3['geometry']['dimensionsWHLMetres'],
                  geometryContext='Original detailed and selected native metre source; unchanged coordinates, axes, origin, indices and appearance. Native qualification and actual game acceptance pending.')
    metadata = dict(schemaVersion=2, family=r3['family'], aliases=[], objectKind='ship',
                    origin='human', primaryType=r3['classification'], primaryRole=r3['classification'],
                    roleWeights=[], access='normal', playerFlyable=False,
                    normalPurchaseEligible=False, purchasePolicy='never' if capital else 'pendingFabrication',
                    isCapital=capital,
                    collectionMilestone='destruction' if capital else 'blueprintAndFabrication',
                    damagePolicy='destructible', discoveryEligible=True, encounterMode='authored',
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

    standards = [field('game.' + k, k, v) for k, v in game.items()]
    for key, v, unit in [
        ('cargo_tonnes', game['cargo'], 't'), ('cargo_expansion_tonnes', game['cargoExpansion'], 't'),
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
                  field('original.geometry_sha256', 'Detailed source SHA256', source['detailed'][2]['sha256']),
                  field('original.native_geometry_sha256', 'Selected native source SHA256', source['native'][2]['sha256']),
                  field('physical.unit_scale_exact', 'Metres per source unit', '1'),
                  field('physical.record_sha256', 'Engineering source record SHA256', pin['physicalRecordSHA256'])]
    profiles = [dict(id='ORIGINAL-' + id + '-R3-STANDARD', title=r3['name'] + ' current bare specification',
                     group='project-refit-v1', context=basis, fields=standards),
                dict(id='ORIGINAL-' + id + '-R3-PLANNING', title='Original crew and fitting requirements',
                     group='l337-original-r3-planning', context=basis, fields=planning),
                dict(id='ORIGINAL-' + id + '-CURRENT-SOURCE', title='Current original source provenance',
                     group='l337-original-source-provenance', context=basis, fields=provenance)]
    output = '# Original source replacement; pending native qualification and actual game acceptance.\n'
    output += ''.join(k + ' = ' + value(v) + '\n' for k, v in header.items()) + '\n'
    output += table('catalogue', metadata) + '\n' + table('game', game) + '\n'
    output += block(source['detailed'][0], 'design') + '\n' + block(source['native'][0], 'nativeDesign') + '\n'
    for profile in profiles:
        output += '[[profiles]]\n' + ''.join(k + ' = ' + value(v) + '\n' for k, v in profile.items()) + '\n'
    decoded = tomllib.loads(output)
    assert decoded['design'] == detailed and decoded['nativeDesign'] == native
    assert decoded['game'] == game and decoded['catalogue'] == metadata
    prepared.append((destination, output.encode(), dict(id=id, name=r3['name'], family=r3['family'],
                    resourceSHA256=digest(output.encode()), detailedSHA256=source['detailed'][2]['sha256'],
                    nativeSHA256=source['native'][2]['sha256'], r3SHA256=pin['contractSHA256'],
                    physicalRecordSHA256=pin['physicalRecordSHA256'],
                    detailedVertices=len(detailed['vertices']), detailedFaces=len(detailed['faces']),
                    nativeFaces=len(native['faces']), bytes=len(output.encode()))))

# Commit no partial source batch before every fixed input and output has passed source equality.
for destination, output, record in prepared:
    destination.write_bytes(output)
result.write_text(json.dumps(dict(status='SOURCE_AUTHORED_UNCOMPILED_UNRUN_NOT_ACTIVATED',
                                 sourceParses=98, resourceWrites=len(prepared), coordinateTransformations=0,
                                 records=[r for _, _, r in prepared]), indent=2) + '\n')
print('Authored', len(prepared), 'exact current resources; no native execution or geometry changes.')
