"""Consume this authenticated job's completed make-ci phases without executing them again."""
import json
import os
from pathlib import Path
import platform
import shutil
import uuid

from crash_artifacts import runtime_child_environment
from sanitizer_checkpoints import atomic_json, digest, executable_inputs, runtime_identity

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = Path('reports/quality-runtime')


def _owned_file(path, immutable=False):
    """Internal receipts must stay inside owned, non-linked storage."""
    for entry in (path, *path.parents):
        if entry.is_symlink():
            raise ValueError('Linked current-job evidence is not accepted')
    info = path.stat()
    if not path.is_file() or info.st_uid != os.getuid() or info.st_mode & 0o022:
        raise ValueError('Current-job evidence must be an owned file')
    if immutable and info.st_mode & 0o777 != 0o400:
        raise ValueError('Capture identity must remain immutable')


def _unique_fields(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate current-job evidence field')
        result[key] = value
    return result


def _json(path, immutable=False):
    _owned_file(path, immutable)
    return json.loads(path.read_text(), object_pairs_hook=_unique_fields)


def _authenticated_job():
    """Use the real installed hook, exact assignment, physical host and source checks."""
    if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('GITHUB_JOB') != 'native_checks':
        raise ValueError('Current-job evidence is restricted to the hosted quality job')
    from recoverable_shards import NativeAuthority
    import native_runner
    authority = NativeAuthority(Path(os.environ['ELITE_NATIVE_POLICY']))
    if authority.root != ROOT:
        raise ValueError('Current-job workspace differs from its owned checkout')
    return authority, {
        'assignment': native_runner.assignment_payload(authority.policy, authority.environment),
        'assignment_sha256': authority.environment['ELITE_RECOVERABLE_ASSIGNMENT_SHA256'],
        'policy_raw_sha256': digest(Path(authority.environment['ELITE_NATIVE_POLICY'])),
    }


def begin_capture():
    """Issue one fresh identity before this job's only make-ci invocation."""
    _, job = _authenticated_job()
    path = ROOT / EVIDENCE / 'job-capture.json'
    if path.exists():
        raise ValueError('This job already has a make-ci capture identity')
    capture = {'schema': 1, 'nonce': str(uuid.uuid4()), 'job': job}
    atomic_json(path, capture)
    path.chmod(0o400)
    return capture


def current_capture():
    """A previous run, attempt, assignment or workspace cannot lend its capture."""
    authority, job = _authenticated_job()
    capture = _json(ROOT / EVIDENCE / 'job-capture.json', immutable=True)
    if (set(capture) != {'schema', 'nonce', 'job'} or capture['schema'] != 1
            or type(capture['schema']) is not int
            or str(uuid.UUID(capture['nonce'])) != capture['nonce'] or capture['job'] != job):
        raise ValueError('Make-ci capture belongs to another job or assignment')
    return authority, capture


def _phase_candidates(phase, capture):
    selected = []
    for path in sorted((ROOT / 'reports/quality-phases' / phase).glob('*/summary.json')):
        summary = _json(path)
        if summary.get('identity', {}).get('job_capture') == capture:
            selected.append((path, summary))
    if len(selected) != 1:
        raise ValueError('Exactly one completed phase from this capture is required: ' + phase)
    return selected[0]


def _phase_record(phase, capture):
    """Bind a real fresh phase's result, outputs and full XML/coverage validation."""
    from quality_phase_checkpoints import successful_phase
    path, summary = _phase_candidates(phase, capture)
    head = capture['job']['assignment']['head']
    if (summary['status'] != 'passed' or summary['current_head'] != head
            or summary['tested_head'] != head or summary['reused'] or summary['attested']
            or summary['executed_test_wall_seconds'] <= 0
            or summary['identity']['phase'] != phase):
        raise ValueError('Current-job phase is not a fresh completed success')
    completed = path.parent / 'completed'
    result = successful_phase(completed, summary['identity'])
    if (result is None or result['tested_head'] != head or result['outputs'] != summary['outputs']
            or result['validation'] != summary['validation']):
        raise ValueError('Current-job phase result or outputs changed')
    return {'summary': str(path.relative_to(ROOT)), 'summary_sha256': digest(path),
            'result_sha256': digest(completed / 'result.json')}


def _aggregate(capture):
    """Retain the original complete make-ci outcome; phase success alone is insufficient."""
    root = ROOT / EVIDENCE
    summary, command = _json(root / 'summary.json'), _json(root / 'ci.json')
    if (summary['head'] != capture['job']['assignment']['head'] or not summary['headUnchanged']
            or summary['changedTrackedInputs'] or summary['exitCode'] != 0
            or len(summary['attempts']) != 1 or summary['attempts'][0] != command
            or command['command'] != ['make', 'ci'] or command['makeExitCode'] != 0
            or command['exitCode'] != 0 or command['interrupted']
            or command['monitorErrors'] or command['remainingAfterCleanup']
            or digest(root / 'ci.log') != command['rawSHA256']):
        raise ValueError('Complete current-job make-ci success is required')
    return {'summary_sha256': digest(root / 'summary.json'),
            'command_sha256': digest(root / 'ci.json')}


def seal_capture(capture):
    """Publish the bounded phase pair only after make-ci and all its gates finish."""
    _, actual = current_capture()
    if actual != capture:
        raise ValueError('Capture changed while make-ci ran')
    receipt = {'schema': 1, 'capture': capture, 'aggregate': _aggregate(capture),
               'phases': {phase: _phase_record(phase, capture) for phase in ('normal', 'leaks')}}
    path = ROOT / EVIDENCE / 'completed-job.json'
    if path.exists():
        raise ValueError('Completed job evidence already exists')
    atomic_json(path, receipt)
    path.chmod(0o400)


def _check_manifest():
    root = ROOT / EVIDENCE
    manifest = _json(root / 'originals-manifest.json')
    actual = {}
    for path in root.rglob('*'):
        if path.is_file() and path.name != 'originals-manifest.json':
            _owned_file(path)
            actual[str(path.relative_to(root))] = digest(path)
    if manifest != actual:
        raise ValueError('Current make-ci capture artifacts changed')
    for name in manifest:
        _json_file = root / name
        if _json_file.is_symlink() or not _json_file.resolve().is_relative_to(root.resolve()):
            raise ValueError('Current capture artifact escaped its owned root')


def _current_identity(identity, authority, capture):
    """Recheck current inputs and host controls without building or executing tests."""
    from quality_phase_checkpoints import reviewed_build_profile, opt_in_policy
    phase = identity['phase']
    environment = runtime_child_environment(os.environ)
    swift = shutil.which('swift')
    flags = ['--enable-code-coverage'] if phase == 'normal' else []
    profile = reviewed_build_profile(None, None, phase, environment)
    argv = [swift, 'build', *(['--build-tests'] if phase == 'normal' else []), *flags, *profile['flags']]
    if (identity['job_capture'] != capture or identity['inputs'] != executable_inputs(ROOT, '.build')
            or identity['environment'] != runtime_identity(environment)
            or identity['architecture'] != platform.machine()
            or identity['os_version'] != {'release': os.uname().release, 'version': os.uname().version}
            or identity['swift_executable'] != swift or identity['swift'] != authority.policy['swift']
            or identity['sdk'] != authority.policy['sdk']
            or identity['sdk_path'] != authority.output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'])
            or identity['flags'] != flags or identity['parallel'] != (phase == 'normal')
            or identity['build_profile'] != {**profile, 'argv': argv}):
        raise ValueError('Current source, host, SDK, environment or build profile changed')
    image = Path(identity['phase_image'])
    if (not image.is_absolute() or image != image.resolve() or not image.is_relative_to(ROOT / '.build')
            or not image.is_file() or digest(image) != identity['image_sha256']
            or authority.output(['xcrun', 'dwarfdump', '--uuid', str(image)]) != identity['image_uuid']):
        raise ValueError('Executed phase image or UUID changed')
    if phase == 'normal' and identity['opt_in_policy'] != opt_in_policy(ROOT, environment):
        raise ValueError('Normal inventory opt-in controls changed')


def consume_for_sonar():
    """Authoritative main analysis consumes this job's sealed complete proof exactly as produced."""
    if os.environ.get('GITHUB_REF') != 'refs/heads/main' or os.environ.get('GITHUB_EVENT_NAME') != 'push':
        raise ValueError('Only actual main push analysis can consume hosted quality evidence')
    from quality_phase_checkpoints import ensure_no_live_tests
    authority, capture = current_capture()
    ensure_no_live_tests()
    receipt = _json(ROOT / EVIDENCE / 'completed-job.json', immutable=True)
    _check_manifest()
    if (set(receipt) != {'schema', 'capture', 'aggregate', 'phases'} or receipt['schema'] != 1
            or type(receipt['schema']) is not int
            or receipt['capture'] != capture or receipt['aggregate'] != _aggregate(capture)
            or set(receipt['phases']) != {'normal', 'leaks'}):
        raise ValueError('Current complete job receipt differs')
    for phase in ('normal', 'leaks'):
        if receipt['phases'][phase] != _phase_record(phase, capture):
            raise ValueError('Current-job phase receipt differs')
        _, summary = _phase_candidates(phase, capture)
        _current_identity(summary['identity'], authority, capture)
    _, normal = _phase_candidates('normal', capture)
    completed = ROOT / receipt['phases']['normal']['summary']
    for name in ('coverage.xml', 'coverage.lcov'):
        shutil.copyfile(completed.parent / 'completed' / name, ROOT / name)
        if digest(ROOT / name) != normal['outputs'][name]:
            raise ValueError('Published coverage differs from the validated normal phase')
    print('Sonar: verified this job\'s complete make-ci, normal coverage and zero-leak evidence; no test rerun.')


if __name__ == '__main__':
    consume_for_sonar()
