"""Observe the existing unit child and retain failure evidence; never launch a test."""
from hashlib import sha256
from pathlib import Path
import json
import os
import re
import shlex
import shutil
import subprocess
import threading

from crash_artifacts import (ArtifactBudget, arguments, collect_reports, report_snapshot,
                             retain_test_images, same_process)


HOSTED_REPORT_WINDOW_SECONDS = 15


def hosted_validation_binding(environment, source):
    """Recognize only this repository's exact hosted validation checkout."""
    repository = environment.get('GITHUB_REPOSITORY')
    ref = environment.get('GITHUB_REF', '')
    workflow = environment.get('GITHUB_WORKFLOW_REF')
    workflow_sha = environment.get('GITHUB_WORKFLOW_SHA')
    run_id = environment.get('GITHUB_RUN_ID', '')
    attempt = environment.get('GITHUB_RUN_ATTEMPT', '')
    if (environment.get('GITHUB_ACTIONS') != 'true'
            or environment.get('RUNNER_ENVIRONMENT') != 'github-hosted'
            or environment.get('RUNNER_OS') != 'macOS'
            or environment.get('RUNNER_ARCH') != 'ARM64'
            or environment.get('GITHUB_EVENT_NAME') != 'workflow_dispatch'
            or environment.get('GITHUB_JOB') != 'isolated-units'
            or repository != 'stephenlclarke/l337'
            or not re.fullmatch(r'refs/heads/validation/[a-z0-9][a-z0-9-]*', ref)
            or workflow != f'{repository}/.github/workflows/unit-tests.yml@{ref}'
            or not re.fullmatch(r'[0-9a-f]{40}', source)
            or environment.get('GITHUB_SHA') != source
            or workflow_sha != source
            or not re.fullmatch(r'[1-9][0-9]*', run_id)
            or not re.fullmatch(r'[1-9][0-9]*', attempt)):
        return None
    return {'repository': repository, 'workflowRef': workflow, 'workflowSHA': workflow_sha,
            'ref': ref, 'source': source,
            'runID': run_id, 'runAttempt': attempt, 'job': 'isolated-units'}


def exact_test_helper(history, image, selector, swift_xml):
    """Use the original ps text for the selector and refuse competing helper identities."""
    helpers = {
        (pid, record['parent'], record['start'], record['command'])
        for pid, records in history.items()
        for record in records
        if (argv := arguments(record)) and Path(argv[0]).name == 'swiftpm-testing-helper'
    }
    if len(helpers) != 1 or not selector or swift_xml is None:
        return None
    pid, parent, start, command = next(iter(helpers))
    helper = arguments({'command': command})[0]
    expected = ' '.join([
        helper, '--test-bundle-path', image['image'], '--enable-code-coverage',
        '--filter', selector, '--xunit-output', str(swift_xml), image['image'],
        '--testing-library', 'swift-testing',
    ])
    if (not Path(helper).is_absolute() or command != expected or pid != image['pid']
            or start != image['start'] or os.path.realpath(helper) != image['helperExecutable']):
        return None
    return {pid: [{'parent': parent, 'start': start, 'command': command}]}


def snapshot():
    """Read process identities, including full start second and command, without attaching."""
    raw = subprocess.check_output(
        ['ps', '-axo', 'pid=,ppid=,lstart=,command='], text=True)
    rows = {}
    for line in raw.splitlines():
        fields = line.split(None, 7)
        if len(fields) == 8:
            rows[int(fields[0])] = {'parent': int(fields[1]),
                                   'start': ' '.join(fields[2:7]), 'command': fields[7]}
    return rows


def observe_descendants(rows, root, known, history, *, root_alive):
    """Match owned parents strictly; only a live root may exec at the same start."""
    selected = {pid for pid, record in known.items()
                if pid != root and same_process(record, rows.get(pid))}
    if root_alive and root in rows:
        previous = known.get(root)
        # Only the live Popen root may exec while retaining its original start identity.
        if previous is None or previous['start'] == rows[root]['start']:
            selected.add(root)
    while True:
        children = {pid for pid, row in rows.items()
                    if pid != root and row['parent'] in selected}
        if children <= selected:
            break
        selected |= children
    for pid in selected:
        row = rows[pid]
        if pid not in known or not same_process(known[pid], row):
            history.setdefault(pid, []).append(dict(row))
        known[pid] = dict(row)


class IsolatedCrashEvidence:
    """Read-only process observation; no debugger, signalling, retry or changed test budget."""
    def __init__(self, workspace, evidence, roots=None, read_snapshot=snapshot, *,
                 selector=None, swift_xml=None):
        self.workspace, self.evidence = Path(workspace), Path(evidence)
        resolved = self.evidence.resolve()
        if (self.evidence.is_symlink() or resolved == self.workspace.resolve()
                or not resolved.is_relative_to(self.workspace.resolve())):
            raise ValueError('Failure evidence must be a confined owned output directory.')
        if self.evidence.exists():
            shutil.rmtree(self.evidence)  # A prior run's report must never enter this run's artifact.
        self.roots = roots if roots is not None else [
            Path.home() / 'Library/Logs/DiagnosticReports',
            Path('/Library/Logs/DiagnosticReports')]
        self.baseline = report_snapshot(self.roots)
        self.read_snapshot = read_snapshot
        self.selector, self.swift_xml = selector, swift_xml
        self.known, self.history, self.errors = {}, {}, []
        self.stop = threading.Event()
        self.watcher = None

    def observe(self, rows, root, *, root_alive):
        observe_descendants(rows, root, self.known, self.history, root_alive=root_alive)
        # Compiler command lines can be enormous. Keep only live ancestry and the actual
        # test/helper/symbol identities needed by the existing failure collector.
        for pid in list(self.history):
            kept = []
            for record in self.history[pid]:
                lexer = shlex.shlex(record['command'], posix=True)
                lexer.whitespace_split = True
                executable = Path(next(lexer, '')).name
                if pid == root or executable in {
                        'swiftpm-testing-helper', 'L337PackageTests', 'dsymutil'}:
                    kept.append(record)
            if kept:
                self.history[pid] = kept
            else:
                del self.history[pid]
        # Keep the original root start anchor even after exit; it grants no authority alone.
        self.known = {pid: record for pid, record in self.known.items()
                      if pid == root or same_process(record, rows.get(pid))}

    def start(self, process):
        def observe():
            try:
                # The live Popen root is the sole initial authority; retain descendants by identity.
                if process.poll() is None:
                    rows = self.read_snapshot()
                    self.observe(rows, process.pid, root_alive=process.poll() is None)
                while not self.stop.wait(0.1):
                    rows = self.read_snapshot()
                    # Recheck Popen liveness after every snapshot, including a known root.
                    self.observe(rows, process.pid, root_alive=process.poll() is None)
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                self.errors.append({'type': type(error).__name__, 'detail': str(error)})
        self.watcher = threading.Thread(target=observe, daemon=True)
        self.watcher.start()

    def finish(self, source, failed):
        self.stop.set()
        if self.watcher:
            self.watcher.join(timeout=5)
        result = {'failureOnly': True, 'errors': list(self.errors),
                  'observerAlive': self.watcher.is_alive() if self.watcher else False}
        if not failed:
            return result
        self.evidence.mkdir(parents=True, exist_ok=True)
        def write(name, value):
            (self.evidence / name).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
        write('observed-processes.json', self.history)
        try:
            if result['observerAlive']:
                raise ValueError('Process observer did not finish; attribution unavailable.')
            budget = ArtifactBudget()
            images = retain_test_images(self.history, self.workspace, self.evidence, source, budget)
            hosted = hosted_validation_binding(os.environ, source)
            report_history, options = self.history, {}
            if hosted is not None and len(images) == 1:
                image = images[0]
                uuid = image.get('imageUUID', {}).get('uuids', {}).get('arm64')
                if image['status'] == 'retained-image' and uuid:
                    helper_history = exact_test_helper(self.history, image, self.selector, self.swift_xml)
                    if helper_history is not None:
                        helper = helper_history[image['pid']][0]
                        hosted['observedImage'] = {'pid': image['pid'], 'parent': helper['parent'],
                                                   'start': image['start'], 'helper': image['helperExecutable'],
                                                   'commandSHA256': sha256(helper['command'].encode()).hexdigest(),
                                                   'sha256': image['imageSHA256'], 'uuid': uuid}
                        report_history = helper_history
                        options = {'window': HOSTED_REPORT_WINDOW_SECONDS, 'exact_launch_second': True}
                        result['hostedValidation'] = hosted
            records, audit = collect_reports(self.roots, self.baseline, report_history,
                                            self.evidence, budget, **options)
            # Retain full reports only after exact observed PID/start/executable attribution.
            # The collector's unrelated candidates remain metadata internally, never uploaded.
            records = [record for record in records if record.get('matchedActualProcess')]
            write('native-images.json', images)
            write('crash-originals.json', records)
            write('report-discovery.json', audit)
            result['reports'] = len(records)
            result['matchedReports'] = sum(record.get('matchedActualProcess', False)
                                           for record in records)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            result['captureError'] = {'type': type(error).__name__, 'detail': str(error)}
        write('capture.json', result)
        return result
