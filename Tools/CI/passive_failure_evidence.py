"""Preserve natural failure evidence from existing owned RSS samples; never launch or attach."""
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import time

from crash_artifacts import attributed_report, confined, report_identity

HISTORY_LIMIT = 65536
COMMAND_LIMIT = 8192
RECORD_LIMIT = 64
REPORT_LIMIT = 1024 * 1024
REPORT_COUNT = 8
DIRECTORY_LIMIT = 4096
NAME = re.compile(r'\.?swiftpm-testing-helper-\d{4}-\d{2}-\d{2}-\d{6}\.(ips|crash)$')


def report_has_test_uuid(payload, raw, suffix, image):
    """Require the actual frozen bundle UUID/path in addition to PID/start/executable attribution."""
    expected = set(image['uuids'])
    if suffix == '.ips':
        for row in payload.get('usedImages', []):
            path = row.get('path') if isinstance(row, dict) else None
            if (isinstance(path, str) and Path(path).is_absolute()
                    and os.path.realpath(path) == os.path.realpath(image['path'])
                    and str(row.get('uuid', '')).upper() in expected):
                return True
        return False
    pattern = r'^.*<([0-9a-fA-F-]{36})>\s+' + re.escape(image['path']) + r'\s*$'
    return any(match[1].upper() in expected for match in re.finditer(pattern, raw, re.M))


class PassiveFailureEvidence:
    """No polling thread, debugger, symbols helper, retry, signal, budget extension or old-report hunt."""
    def __init__(self, directory, image, roots=None, clock=time.monotonic, deadline=None):
        self.directory = Path(directory)
        if not self.directory.is_absolute() or self.directory.exists() or self.directory.is_symlink():
            raise ValueError('Require a fresh absolute run-owned evidence directory')
        if (set(image) != {'path', 'sha256', 'uuids'} or not Path(image['path']).is_absolute()
                or not re.fullmatch(r'[0-9a-f]{64}', image['sha256'])
                or not image['uuids'] or any(not isinstance(value, str) or not re.fullmatch(
                    r'[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}', value) for value in image['uuids'])):
            raise ValueError('Require frozen actual test path/hash/UUID identity')
        self.image = dict(image)
        self.roots = tuple(map(Path, roots)) if roots is not None else (
            Path.home() / 'Library/Logs/DiagnosticReports', Path('/Library/Logs/DiagnosticReports'))
        self.clock = clock
        self.history = {}
        self.truncated = False
        self.errors = []
        self.directory.mkdir(mode=0o700)
        self.baseline = self.report_inventory(deadline)
        self.persist()

    def report_inventory(self, deadline=None):
        """Filename/stat baseline only in two fixed report roots; no report bodies before failure."""
        result = {}
        for root in self.roots:
            if deadline is not None and self.clock() >= deadline:
                self.errors.append('report-inventory-deadline')
                break
            if root.is_symlink():
                self.errors.append('symbolic-report-root')
                continue
            try:
                with os.scandir(root) as entries:
                    for count, entry in enumerate(entries):
                        if count >= DIRECTORY_LIMIT:
                            self.errors.append('report-directory-entry-cap')
                            break
                        if deadline is not None and self.clock() >= deadline:
                            self.errors.append('report-inventory-deadline')
                            break
                        if not NAME.fullmatch(entry.name) or entry.is_symlink() or not entry.is_file(follow_symlinks=False):
                            continue
                        stat = entry.stat(follow_symlinks=False)
                        result[str(root / entry.name)] = (stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns)
                        if len(result) >= REPORT_COUNT * 4:
                            self.errors.append('report-candidate-cap')
                            return result
            except FileNotFoundError:
                continue
            except OSError as error:
                self.errors.append(type(error).__name__)
        return result

    def persist(self):
        """Atomically retain bounded exact identities while the existing child is alive."""
        value = dict(schema=1, image=self.image, processes=self.history,
                     truncated=self.truncated, errors=self.errors[-16:])
        raw = (json.dumps(value, sort_keys=True) + '\n').encode()
        if len(raw) > HISTORY_LIMIT:
            raise ValueError('Owned identity metadata cap exceeded')
        pending = self.directory / 'observed-processes.pending'
        pending.write_bytes(raw)
        pending.replace(self.directory / 'observed-processes.json')

    def observe(self, rows, selected, leader):
        """Consume only the guard's already-owned sample; no process query is performed here."""
        changed = False
        for pid in sorted(selected):
            row = rows[pid]
            command = row.get('command', '')
            try:
                executable = Path(shlex.split(command)[0]).name
            except (ValueError, IndexError):
                continue
            if pid != leader and executable not in {'swiftpm-testing-helper', 'L337CoreTests', 'L337PackageTests'}:
                continue
            if len(command.encode()) > COMMAND_LIMIT or not row.get('start'):
                self.truncated = True
                continue
            record = {key: row[key] for key in ['parent', 'group', 'start', 'command']}
            records = self.history.get(str(pid), [])
            if record in records:
                continue
            if sum(map(len, self.history.values())) >= RECORD_LIMIT:
                self.truncated = True
                continue
            records.append(record)
            self.history[str(pid)] = records
            probe = json.dumps(dict(schema=1, image=self.image, processes=self.history,
                                    truncated=self.truncated, errors=self.errors[-16:])).encode()
            if len(probe) + 1 > HISTORY_LIMIT:
                records.pop()
                if not records:self.history.pop(str(pid), None)
                self.truncated = True
                continue
            changed = True
        if changed or self.truncated:
            self.persist()

    def finish(self, failed, deadline):
        """One natural-failure inventory inside the existing cleanup deadline; never wait for a report."""
        records = []
        if failed and not self.history:
            self.errors.append('no-observed-owned-process-identity')
        if failed and self.history:
            candidates = self.report_inventory(deadline)
            changed = [name for name, value in candidates.items() if self.baseline.get(name) != value]
            for name in sorted(changed)[:REPORT_COUNT]:
                if self.clock() >= deadline:
                    self.errors.append('report-read-deadline')
                    break
                row = dict(name=Path(name).name, matched=False)
                records.append(row)
                try:
                    path = confined(name, Path(name).parent)
                    if path.stat().st_size > REPORT_LIMIT:
                        row['status'] = 'report-byte-cap'
                        continue
                    with path.open('rb') as stream:
                        raw = stream.read(REPORT_LIMIT + 1)
                    stat = path.stat()
                    signature = (stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns)
                    if len(raw) > REPORT_LIMIT or signature != candidates[name] or len(raw) != stat.st_size:
                        row['status'] = 'changed-or-oversized-report'
                        continue
                    if self.clock() >= deadline:
                        row['status'] = 'report-read-deadline'
                        break
                    text = raw.decode('utf-8', errors='replace')
                    payload = report_identity(text, path.suffix)
                    if not attributed_report(payload, self.history):
                        row['status'] = 'unproved-pid-start-executable'
                        continue
                    if not report_has_test_uuid(payload, text, path.suffix, self.image):
                        row['status'] = 'unproved-frozen-test-uuid'
                        continue
                    if self.clock() >= deadline:
                        row['status'] = 'report-validation-deadline'
                        break
                    digest = hashlib.sha256(raw).hexdigest()
                    target = self.directory / (digest[:16] + '-' + path.name)
                    if self.clock() >= deadline:
                        row['status'] = 'report-persist-deadline'
                        break
                    with target.open('xb') as stream:
                        stream.write(raw)
                    row.update(status='retained-exact-pid-start-path-test-uuid', matched=True,
                               retained=target.name, sha256=digest, bytes=len(raw),
                               pid=payload['pid'], executable=payload['procPath'], launch=payload['procLaunch'])
                except (OSError, ValueError, KeyError, TypeError) as error:
                    row['status'] = type(error).__name__
        self.persist()
        value = dict(schema=1, failure=failed, image=self.image, reports=records,
                     matchedReports=sum(row['matched'] for row in records),
                     errors=self.errors[-16:], historyTruncated=self.truncated,
                     attribution='Only exact PID/start/executable plus frozen test UUID; missing evidence remains UNKNOWN',
                     noDebugger=True, noExtraProcessSamples=True, noRetry=True,
                     limits=dict(historyBytes=HISTORY_LIMIT, reportBytes=REPORT_LIMIT,
                                 reportCount=REPORT_COUNT, directoryEntries=DIRECTORY_LIMIT),
                     deadline=deadline, finishedMonotonic=self.clock())
        (self.directory / 'capture.json').write_text(json.dumps(value, indent=2) + '\n')
        return value
