#!/usr/bin/env python3
"""Incremental renderer GIFs and Markdown from the exact runtime ship TOMLs."""
import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import signal
import shlex
import sys
import tempfile
import time
from contextlib import ExitStack
import re
from pathlib import Path
import subprocess

_spec=importlib.util.spec_from_file_location('ship_files',Path(__file__).with_name('ship-files.py'))
ship_files=importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ship_files)
MEDIA=Path('docs/ships')
SETTINGS=b'right-on-ship-gif-v1:256-square:24-frames:0.1s:cyan-shaded:camera400:focal340'
LABELS={'cargo':'Cargo (t)','speed':'Top speed','acceleration':'Acceleration (speed/s)','energy':'Energy capacity','recharge':'Energy recharge /s','roll':'Roll (rad/s)','pitch':'Pitch (rad/s)','yaw':'Yaw (rad/s)','shield':'Each shield','shieldRecharge':'Shield recharge /s','fuel':'Fuel tank (LY)','jump':'Base jump (LY)','spool':'Jump charge (s)','missiles':'Missile pylons','facings':'Laser mounts','cargoExpansion':'Cargo bay upgrade (t)','price':'Hull price (CR)'}


def digest(data):
    """Use content identity rather than path or modification time."""
    return hashlib.sha256(data).hexdigest()


# exportShipMedia -> Display.shipPortrait -> CatalogueShip.previewMesh / Display.draw
# -> imageFor / drawFrame (Quartz CPU path; no ShipPanelRenderer is supplied).
# Keep this boundary in sync when that call path gains a dependency. See docs/archive/work-items/fleet/PR-75.md.
RENDER_FILES = (
    'Package.swift', 'Package.resolved',
    'Sources/L337Core/AutoTargetControl.swift',  # Basis3 and SpaceBody.modelVector
    'Sources/L337Core/CockpitDisplay.swift',  # Frame.label
    'Sources/L337Core/Display.swift',  # palette, bitmap font, frame and Display.draw
    'Sources/L337Core/Geometry.swift',
    'Sources/L337Core/Graphics.swift',
    'Sources/L337Core/OriginalShipTextureAssets.swift',
    'Sources/L337Core/ShipAppearance.swift',
    'Sources/L337Core/ShipCatalogue.swift',
    'Sources/L337Core/ShipCatalogueMetadata.swift',
    'Sources/L337Core/ShipPerformance.swift',
    'Sources/L337Core/ShipPortrait.swift',
    'Sources/L337Core/ShipRendering.swift',
    'Sources/L337Core/ShipTextureAssets.swift',
    'Sources/L337Core/ShipTextureRaster.swift',
    'Sources/L337Core/ShowroomGeometry.swift',
    'Sources/L337Core/ScriptNPCRendering.swift',  # Display.draw's beam guard
    'Sources/L337Mac/NativeGraphics.swift',
    'Sources/L337Mac/ShipMedia.swift',
)
TEXTURE_FOLDERS = (
    'Sources/L337Core/Resources/ShipTextures',
    'Sources/L337Core/Resources/OriginalShipTextures',
)
# The portrait explicitly sets .front and .shadedPanels and supplies its own mesh.
# Only this view transform is read from Game.swift by that fixed drawing path.
# Missing, renamed, duplicate or reversed declaration boundaries fail closed.
VIEW_START = '  public func viewPosition(_ p: Vector3) -> Vector3 {\n'
VIEW_END = '  private mutating func moveBodies(dt: Double, c01MotionStartTime: Double) {\n'


def view_transform(root):
    """Read the renderer's Game transform without hashing unrelated simulation methods."""
    text = (root/'Sources/L337Core/Game.swift').read_text()
    if text.count(VIEW_START) != 1 or text.count(VIEW_END) != 1:
        raise ValueError('Update ship media view-transform dependency boundaries')
    start = text.index(VIEW_START)
    end = text.index(VIEW_END)
    if end <= start:
        raise ValueError('Invalid ship media view-transform dependency boundaries')
    return text[start:end].encode()


def shared_hash(root=Path('.')):
    """Hash the maintained portrait path, settings and both authenticated texture trees."""
    paths = [root/name for name in RENDER_FILES]
    for folder in TEXTURE_FOLDERS:
        textures = root/folder
        if textures.is_dir():
            paths.extend(path for path in textures.rglob('*') if path.is_file())
    h = hashlib.sha256(b'ship-media-render-dependencies-v2')

    def add(name, data):
        # Framing prevents a file boundary/name change from aliasing concatenated bytes.
        name = name.encode()
        h.update(len(name).to_bytes(8, 'big'))
        h.update(name)
        h.update(len(data).to_bytes(8, 'big'))
        h.update(data)

    add('settings', SETTINGS)
    add('Sources/L337Core/Game.swift#viewPosition', view_transform(root))
    for path in sorted(paths):
        add(path.relative_to(root).as_posix(), path.read_bytes())
    return h.hexdigest()


def fingerprint(spec_bytes, shared):
    """An individual specification or embedded design edit invalidates that GIF."""
    return digest(spec_bytes+shared.encode())


def needs_render(expected_input, previous, gif):
    """Also detect missing or tampered generated media."""
    return (previous.get('input') != expected_input
            or not gif.is_file() or previous.get('output') != digest(gif.read_bytes()))


def escape(text):
    """Keep source facts inside portable Markdown table cells."""
    escaped = str(text).replace('|','\\|').replace('\n',' ').strip() or '(empty)'
    return re.sub(r'(?<![<(])https?://[^\s<>]*[^\s<>.,;)]', r'<\g<0>>', escaped)


def spec_text(key, number):
    """Use player units and ordinary decimals, not source bitmasks/scientific notation."""
    if key=='fuel':return format(number/10,'.1f')
    if key=='facings':return ', '.join(name for bit,name in [(1,'Front'),(2,'Rear'),(4,'Left'),(8,'Right')] if number & bit)
    if key in {'cargo','cargoExpansion','missiles','price'}:return format(number,',.0f')
    return format(number,'.1f')


def references(ships, write=True):
    """Generate tables from authoritative gameplay values, with source detail separate."""
    ship_files.fleet_source_contract.require_current_fleet(ships)
    example = next(ship for ship in ships if ship['id'] == 'SH025')
    speed_example = spec_text('speed', example['game']['speed']) + ' for ' + example['name']
    lines=['# Ship catalogue','', 'Generated by `make ships` from [the authoritative TOML folder](../Sources/L337Core/Resources/Ships). Each animation uses the actual game renderer and embedded design. Do not edit this document or GIFs by hand.','',
           f"All values below are standard hull values. Carried equipment modifies them in the game. Top speed uses the cockpit scale ({speed_example}); world travel is speed x 18 units/second. Shields and energy are native game pools. See [conversions, fitting and economics](SHIP-FILES.md) and [source/design provenance](SHIP-PROVENANCE.md).",'',
           'Exchange at a main station: new hull price less 75% of your current hull price. Compatible equipment, cargo, fuel and mission property transfer unchanged; conflicts block the trade. There are no free missiles, lasers or fuel. Normal fabrication requires actual paid EMP disable of the selected hull, authorized empty-section cutting and physical receiving of at least 50 kg, followed by a current arrival at a qualified living main station. Destruction, disable alone and targeting grant no purchase. Catalogue capability is separate from commander knowledge. XYZZY-only hulls are excluded from normal purchase and discovery; pending native mechanics are labelled explicitly.','']
    provenance=['# Ship source and design provenance','', '<!-- markdownlint-disable MD024 MD033 -->', '', 'Generated from the same TOMLs as the game. Original designs are interpretations, not historical or authentic source geometry. MIT covers project-authored geometry; imported designs retain their listed terms and [original notices](../NOTICE.md). Dimensions may be estimates and are not SI docking-clearance measurements.','']
    for ship in ships:
        identity=ship['id'];design=ship['design'];game=ship.get('game')
        lines += ['## '+identity+' - '+ship['name'],'', '![Rotating '+ship['name']+'](ships/'+identity+'.gif)','',
                  '**Class:** '+ship['shipClass']+' | [Definition](../Sources/L337Core/Resources/Ships/'+identity+'.toml) | [Provenance](SHIP-PROVENANCE.md#'+identity.lower()+')','', '| Game specification | Value |','| --- | --- |']
        metadata=ship['catalogue']
        primary=metadata.get('primaryType')
        role_label='Bounty hunter' if primary=='bountyHunter' else (primary or 'None').capitalize()
        lines += ['| Project family | '+escape(metadata['family'])+' |',
                  '| Primary display type | '+escape(role_label)+' |',
                  '| Functional AI role | '+escape(metadata.get('primaryRole') or 'None')+' |',
                  '| Object kind / origin | '+escape(metadata['objectKind']+' / '+metadata['origin'])+' |',
                  '| Capital parent / subtype | '+('Yes / '+escape(metadata['capitalSubtype']) if metadata['isCapital'] else 'No')+' |',
                  '| Catalogue discovery eligibility | '+('Yes' if metadata['discoveryEligible'] else 'No')+' |',
                  '| Encounter provision | '+escape(metadata['encounterMode']+'; mechanics '+metadata['mechanicsStatus'])+' |',
                  '| Rarity | '+escape(metadata['rarity'])+' |',
                  '| Player flyable | '+('Yes' if metadata['playerFlyable'] else 'No')+' |',
                  '| Normal purchase capability | '+('Yes' if metadata['normalPurchaseEligible'] else 'No')+' |',
                  '| Purchase policy | '+escape(metadata['purchasePolicy'])+' |',
                  '| Minimum displayed build Tech Level | '+str(metadata.get('minimumBuildTechLevel', 'Not applicable'))+' |',
                  '| Collection milestone | '+escape(metadata['collectionMilestone'])+' |',
                  '| Damage policy | '+escape(metadata['damagePolicy'])+' |']
        if metadata.get('habitat'):
            habitat=metadata['habitat']
            lines += ['| Natural habitat | Government '+escape(','.join(str(g) for g in habitat['governments']))+'; displayed Tech Level '+str(habitat['minimumDisplayedTechLevel'])+'+; independent of fabrication |']
        if game:
            lines += ['| '+label+' | '+spec_text(key,game[key])+' |' for key,label in LABELS.items()]
            power=game['energy']+2*game['shield']+32*game['recharge']+64*game['missiles']+128*game['facings'].bit_count()
            lines += ['| Power index | '+format(power,'.1f')+' |','| Trade-in (CR) | '+format(game['price']*.75,'.1f')+' |']
        else:lines += ['| Native gameplay profile | '+escape(metadata['mechanicsStatus'])+'; no player performance profile |']
        lines += ['| Design | '+str(len(design['vertices']))+' vertices; '+str(len(design['faces']))+' faces |','']
        provenance += ['<a id="'+identity.lower()+'"></a>','', '## '+identity+' - '+ship['name'],'', '**Design:** '+design['source']+'; '+design['license']+'.','', ship['geometryContext'],'',
                       '**Appearances:** '+ship['appearances']+'; **evidence:** '+ship['evidence']+'.','']
        if 'recipe' in design:
            provenance += ['Original project interpretation: '+design['recipe']['family']+' family, individual sweep/components/envelope. Full authored geometry and recipe are embedded in the TOML. No gameplay statistic was inferred from the invented shape.','']
            if design['recipe']['family'] == 'liberator-dsv2':
                provenance += ['[Liberator visual references, palette and chosen native mechanics](LIBERATOR.md). Three radial nacelles, forward probes and an aft green engine; no external artwork or model asset is redistributed.','']
        else:provenance += ['Imported numerical geometry and complete custody metadata are embedded in the TOML; original source files/notices remain separately attributable. Six zero-area source triangles across three assemblies are harmless and skipped by back-face projection.','']
        if 'nativeHull' in ship:
            provenance += ['**Original encounter variant:** '+ship['nativeHull']+'. The game loads this retained variant from the same TOML; player adaptations above remain distinct.','']
            if 'nativeDesign' in ship:
                native=ship['nativeDesign']
                provenance += [native['source']+'; '+native['license']+'. '+str(len(native['vertices']))+' vertices, '+str(len(native['faces']))+' faces, '+str(len(native.get('details',[])))+' wire details. Original coordinate/face/detail digests are checked independently.','']
            if 'nativeCombat' in ship:
                provenance += ['| Original NPC field | Value |','| --- | --- |']
                provenance += ['| '+key+' | '+str(value)+' |' for key,value in ship['nativeCombat'].items()]
                provenance.append('')
        for profile in ship['profiles']:
            provenance += ['### '+profile['title'],'',profile['context'],'','| Field | Source value | Status / basis |','| --- | --- | --- |']
            provenance += ['| '+escape(f['label'])+' | '+escape(f['text'])+' | '+escape(f['status']+'; '+f['basis'])+' |' for f in profile['fields']]
            provenance.append('')
    documents = {'docs/SHIP-CATALOGUE.md':'\n'.join(lines),'docs/SHIP-PROVENANCE.md':'\n'.join(provenance)}
    if write:
        for path, text in documents.items():Path(path).write_text(text)
    return documents


# Execution uses OS/toolchain resource defaults. Identity, leases and cleanup remain.
# None is deliberate: no large replacement memory/time/output ceiling is installed.
ASSET_RSS = None
# Compiler, test and renderer RSS are unrestricted by the project.
NORMAL_RSS = None
NORMAL_COMPILER_RSS = None
ASSET_SECONDS = None
ASSET_CLEANUP = 4
ASSET_OUTPUT = None


def process_memory(timeout=None, *, include_command=False):
    """One existing kernel/RSS sample; optional owned failure attribution never changes RSS ownership."""
    columns='pid=,ppid=,pgid=,lstart=,rss='
    command=['/bin/ps','-axo',columns]
    if include_command:command=['/bin/ps','-ww','-axo',columns+',command=']
    raw=subprocess.check_output(command,stderr=subprocess.PIPE).decode()
    rows={}
    for line in raw.splitlines():
        fields=line.split(None,9) if include_command else line.split()
        if len(fields) not in ((9,10) if include_command else (9,)):
            raise RuntimeError('Incomplete process/RSS sample')
        pid,parent,group=map(int,fields[:3])
        rows[pid]={'parent':parent,'group':group,'start':' '.join(fields[3:8]),'rss':int(fields[8])*1024}
        if include_command:rows[pid]['command']=fields[9] if len(fields)==10 else ''
    return rows


def owned_processes(pid,known,rows,leader_unreaped):
    """Discover visible children and retain their kernel identities across exec/reparenting."""
    selected={key for key,start in known.items() if key in rows and rows[key]['start']==start}
    # Until Popen reaps its leader, that PID cannot be reused as a new group.
    if leader_unreaped:
        selected.update(key for key,row in rows.items() if row['group']==pid)
        if pid in rows and pid not in known:selected.add(pid)
    while True:
        added={key for key,row in rows.items() if row['parent'] in selected}-selected
        if not added:break
        selected.update(added)
    for key in selected:known[key]=rows[key]['start']
    return selected


def stop_renderer(process,known,deadline):
    """Bound cancellation/reaping; unbound surviving group members also block success."""
    signalled=False;unbound=[]
    def observe():
        rows=process_memory(min(1,max(.001,deadline-time.monotonic())))
        selected=owned_processes(process.pid,known,rows,process.returncode is None)
        group={pid for pid,row in rows.items() if row['group']==process.pid}
        return rows,selected,group-selected
    for signum in (signal.SIGTERM,signal.SIGKILL):
        if time.monotonic()>=deadline:break
        # Discover the original group before any wait/poll can reap its leader.
        try:rows,selected,unbound=observe()
        except Exception:selected=set()
        if process.returncode is None:
            try:os.killpg(process.pid,signum);signalled=True
            except ProcessLookupError:pass
            except OSError as error:print('Renderer session signal failed: '+type(error).__name__,file=sys.stderr)
        for pid in sorted(selected,key=lambda value:value==process.pid):
            if time.monotonic()>=deadline:break
            try:
                fresh=process_memory(min(1,deadline-time.monotonic())).get(pid)
                if fresh and fresh['start']==known[pid]:
                    try:os.kill(pid,signum);signalled=True
                    except ProcessLookupError:pass
            except Exception:pass
        end=min(deadline,time.monotonic()+2)
        while time.monotonic()<end:
            # Retain ordinary group followers before reaping a leader that TERM ended.
            if process.returncode is None:
                try:observe()
                except Exception:pass
            try:process.wait(timeout=min(.1,max(.001,end-time.monotonic())))
            except subprocess.TimeoutExpired:pass
            if time.monotonic()<deadline:
                try:
                    rows,remaining,unbound=observe()
                    if process.returncode is not None and not remaining and not unbound:return True,signalled
                except Exception:pass
            time.sleep(min(.05,max(0,end-time.monotonic())))
    if process.returncode is None:
        try:process.wait(timeout=0)
        except subprocess.TimeoutExpired:pass
    print('Renderer cleanup incomplete for leader '+str(process.pid)+'; unresolved group members '+str(sorted(unbound)),file=sys.stderr)
    return False,signalled


def execution_rss_limit(command, profile):
    """Validate the closed command interface; no project RSS ceiling is applied."""
    if profile == 'asset':return None
    if profile == 'normal-ci' and command == ['/usr/bin/make', 'ci']:return None
    if not isinstance(command,list) or not command or Path(command[0]).name != 'swift':
        raise ValueError('Unknown execution profile or unsupported normal command')
    args=command[1:]
    if args[1:3]==['--build-system','native']:args=args[:1]+args[3:]
    if args[:4]==['build','--build-tests','--build-system','native']:args=args[:2]+args[4:]
    if profile=='normal-compiler' and args in (
            ['build','--build-tests','--enable-code-coverage'],
            ['build','--product','L337','--enable-code-coverage'],
            ['build'],['build','--product','L337']):return None
    if profile=='normal-test':
        if args==['test','--enable-code-coverage','list','--skip-build']:return None
        prefix=['test','--enable-code-coverage','--skip-build','--xunit-output']
        if len(args)==len(prefix)+3 and args[:len(prefix)]==prefix:
            output,selector,expression=args[len(prefix):]
            if Path(output).is_absolute() and Path(output).name=='tests.xml' and selector=='--filter' and isinstance(expression,str) and expression:
                return None
    raise ValueError('Unknown execution profile or unsupported normal command')


def execution_admission_peak(command, profile):
    execution_rss_limit(command, profile)
    return None


def normal_ci_sample_rss_limit(leader, selected, rows, observer):
    """Legacy telemetry API: neither compiler nor runtime has an RSS ceiling."""
    return None


def run_renderer(command,root,log,descriptors,deadline=None,*,profile='asset',failure_evidence=None):
    """Authorize the command and retain owned-process cleanup, without resource ceilings."""
    execution_rss_limit(command,profile)
    evidence=None
    if failure_evidence is not None:
        if profile!='normal-test' or len(command)!=8 or command[6]!='--filter':
            raise ValueError('Passive failure evidence requires the existing exact selected normal-test driver')
        expected_directory=Path(command[5]).parent/'test-failure-evidence'
        if (not isinstance(failure_evidence,dict) or set(failure_evidence)!={'directory','image'}
                or Path(failure_evidence['directory'])!=expected_directory):
            raise ValueError('Failure evidence must use this exact run output sibling')
        from passive_failure_evidence import PassiveFailureEvidence
        evidence=PassiveFailureEvidence(failure_evidence['directory'],failure_evidence['image'],
                                        deadline=None)
    process=None;known={};code=1;cancelled=[None];handlers={}
    evidence_active=evidence is not None
    evidence_error=None
    def retain_capture_unknown():
        if evidence is None or evidence_error is None:return
        try:
            (evidence.directory/'capture-error.json').write_text(json.dumps(evidence_error)+'\n')
        except OSError:pass
    def cancel(signum,frame):
        # Recording cancellation never raises inside startup or bounded cleanup.
        if cancelled[0] is None:cancelled[0]=signum
    try:
        for signum in (signal.SIGINT,signal.SIGTERM):
            previous=signal.getsignal(signum)
            signal.signal(signum,cancel);handlers[signum]=previous
        if cancelled[0] is not None:return 128+cancelled[0]
        process=subprocess.Popen(command,cwd=root,stdout=log,stderr=subprocess.STDOUT,
            start_new_session=True,pass_fds=tuple(descriptors))
        while True:
            if cancelled[0] is not None:code=128+cancelled[0];break
            sample_timeout=None
            rows=process_memory(sample_timeout,include_command=True) if evidence_active or profile=='normal-ci' else process_memory(sample_timeout)
            selected=owned_processes(process.pid,known,rows,process.returncode is None)
            if evidence_active:
                try:evidence.observe(rows,selected,process.pid)
                except Exception as error:
                    # Optional artifact I/O must never stop or replace the live child's outcome.
                    evidence_active=False
                    evidence_error={'status':'UNKNOWN','stage':'observe','error':type(error).__name__}
                    retain_capture_unknown()
            selected.update(pid for pid,row in rows.items() if pid==os.getpid() or row['parent']==os.getpid())
            aggregate = sum(rows[pid]['rss'] for pid in selected)
            # First observation precedes poll: even a short-lived leader reserves its group.
            if process.poll() is not None:code=process.returncode;break
            time.sleep(.1)
    except KeyboardInterrupt:
        code=130
    except Exception as error:
        print('Ship render failed: '+str(error),file=sys.stderr)
        code=124 if isinstance(error,TimeoutError) else 1
    finally:
        try:
            cleanup_deadline=time.monotonic()+ASSET_CLEANUP
            if process is not None:
                clean,signalled=stop_renderer(process,known,cleanup_deadline)
                if not clean or (code==0 and signalled):code=125
            if evidence_active:
                try:evidence.finish(code!=0,cleanup_deadline)
                except Exception as error:
                    evidence_error={'status':'UNKNOWN','stage':'finish','error':type(error).__name__}
            if evidence_error is not None:
                evidence_error.update(childExit=process.returncode if process is not None else None,guardExit=code)
                retain_capture_unknown()

        finally:
            for signum,previous in handlers.items():signal.signal(signum,previous)
    if cancelled[0] is not None and code==0:code=128+cancelled[0]
    return code


def render_media(ids, *, readme_medusa=False):
    """Use asset identity leases and default toolchain resources for both media paths."""
    root=Path.cwd()
    sys.path.insert(0,str(root/'Tools/CI'))
    from recoverable_shards import file_claim
    import native_runner
    controls=native_runner.diagnostic_custody_root().parent
    deadline=None
    with ExitStack() as stack:
        locks=[stack.enter_context(file_claim(path)) for path in (
            controls/'recoverable-control.lock',controls/'sanitizer-checkpoints/executor.lock')]
        # Preserve any existing historical hold. Fresh developer Macs need no diagnostic bootstrap.
        if native_runner.diagnostic_custody_root().exists():native_runner.require_diagnostic_custody_clear()
        (root/'.build').mkdir(exist_ok=True)
        directory=Path(tempfile.mkdtemp(prefix='ship-media-',dir=root/'.build'))
        # Use SwiftPM defaults; preserve build-before-skip-build-render ordering.
        # Finish and reap the compiler before starting a no-build renderer under the same lease.
        options = []
        output = directory / 'output'
        arguments = ['--readme-media', '--medusa-only'] if readme_medusa else [
            '--ship-media-directory', str(output), '--ship-media', *ids]
        phases = (
            ('build', ['swift', 'build', *options, '--product', 'L337']),
            ('render', ['swift', 'run', *options, '--skip-build', 'L337',
                        *arguments]),
        )
        log_path = directory / 'render.log'
        descriptors = [lock.fileno() for lock in locks]
        with log_path.open('wb', buffering=0) as log:
            for phase, command in phases:
                code = run_renderer(command, root, log, descriptors, deadline)
                if code:
                    raise RuntimeError(f'Ship media {phase} exited {code}; log: {log_path}')
        return output


def scan_media_inputs():
    """Authenticate the current fleet and bind every renderer fingerprint."""
    ships = ship_files.read_ships()
    ship_files.fleet_source_contract.require_current_fleet(ships)
    shared = shared_hash()
    inputs = {
        ship['id']: fingerprint((ship_files.SHIP_FOLDER / (ship['id'] + '.toml')).read_bytes(), shared)
        for ship in ships
    }
    return ships, inputs


def pending_media(inputs, manifest_path):
    previous = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    return [
        ship_id for ship_id, expected in inputs.items()
        if needs_render(expected, previous.get(ship_id, {}), MEDIA / (ship_id + '.gif'))
    ]


def isolated_media_plan():
    """Reap the Python process holding the decoded fleet before native compilation."""
    result = subprocess.run(
        [sys.executable, str(Path(__file__).resolve()), '--asset-plan'],
        check=True, stdout=subprocess.PIPE, text=True,
    )
    inputs = json.loads(result.stdout)
    if (not isinstance(inputs, dict) or len(inputs) != 171
            or any(not re.fullmatch(r'SH[0-9]{3}', key) or not isinstance(value, str)
                   or not re.fullmatch(r'[0-9a-f]{64}', value) for key, value in inputs.items())):
        raise ValueError('Invalid isolated ship media input plan')
    return inputs


def main():
    """Render changed ships first, then rebuild the central reference deterministically."""
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--readme-medusa', action='store_true')
    mode.add_argument('--asset-plan', action='store_true', help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.readme_medusa:
        render_media([], readme_medusa=True)
        return
    manifest_path = MEDIA / 'manifest.json'
    if args.asset_plan:
        _, inputs = scan_media_inputs()
        print(json.dumps(inputs))
        return
    if args.check:
        ships, inputs = scan_media_inputs()
        changed = pending_media(inputs, manifest_path)
        assert not changed, 'Stale or missing GIFs: ' + ', '.join(changed)
        for path, text in references(ships, write=False).items():
            assert Path(path).read_text() == text, 'Stale generated reference: ' + path
        doc = Path('docs/SHIP-CATALOGUE.md').read_text()
        for ship in ships:
            assert doc.count('## ' + ship['id'] + ' - ') == 1
            assert '(ships/' + ship['id'] + '.gif)' in doc
        print('All', len(ships), 'TOMLs/GIFs/reference sections current')
        return
    planned_inputs = isolated_media_plan()
    changed = pending_media(planned_inputs, manifest_path)
    staged = render_media(changed) if changed else None
    ships, inputs = scan_media_inputs()
    if inputs != planned_inputs:
        raise RuntimeError('Ship media inputs changed after planning; reference and manifest not published')
    if MEDIA.is_symlink():
        raise RuntimeError('Ship media destination must be a directory in the checkout')
    MEDIA.mkdir(parents=True, exist_ok=True)
    staged_outputs = {}
    if staged is not None:
        names = [ship_id + '.gif' for ship_id in changed] + ['overview.png']
        staged_outputs = {MEDIA / name: staged / name for name in names}
        if any(not file.is_file() or file.is_symlink() for file in staged_outputs.values()):
            raise RuntimeError('Ship renderer did not produce every staged output')
        if staged.stat().st_dev != MEDIA.stat().st_dev:
            raise RuntimeError('Staged ship media must share the output filesystem')
    gif_destinations = {ship_id: MEDIA / (ship_id + '.gif') for ship_id in inputs}
    for destination in [*gif_destinations.values(), MEDIA / 'overview.png', manifest_path]:
        if destination.is_symlink() or (destination.exists() and not destination.is_file()):
            raise RuntimeError(f'Invalid ship media destination: {destination}')
    manifest = {
        ship_id: dict(input=inputs[ship_id],
                      output=digest(staged_outputs.get(destination, destination).read_bytes()))
        for ship_id, destination in gif_destinations.items()
    }
    documents = references(ships, write=False)
    text_outputs = {Path(name): content for name, content in documents.items()}
    text_outputs[manifest_path] = json.dumps(manifest, indent=2, sort_keys=True) + '\n'
    for destination in text_outputs:
        if destination.is_symlink() or (destination.exists() and not destination.is_file()):
            raise RuntimeError(f'Invalid ship reference destination: {destination}')
        if destination.parent.stat().st_dev != MEDIA.stat().st_dev:
            raise RuntimeError('Ship reference destinations must share the output filesystem')
    with tempfile.TemporaryDirectory(prefix='.publish-', dir=MEDIA) as directory:
        publications = staged_outputs.copy()
        for index, (destination, content) in enumerate(text_outputs.items()):
            prepared = Path(directory) / str(index)
            prepared.write_text(content)
            publications[destination] = prepared
        # Input/output preflight precedes all replacements. A later filesystem fault can
        # still interrupt this per-file atomic sequence; the manifest is replaced last.
        for destination, file in publications.items():
            file.replace(destination)
    print('Rendered', len(changed), 'ships; reused', len(ships) - len(changed), '; reference:', len(ships), 'ships')


if __name__ == '__main__':
    main()
