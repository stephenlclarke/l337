"""Synthetic processes/files only; no Swift child, native test, debugger or ps is executed."""
from datetime import datetime, timedelta
from hashlib import sha256
import io
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

import crash_artifacts
import isolated_crash_evidence as evidence
import isolated_units as units


def row(parent, command='owned', start='Thu Oct 22 01:00:00 2026'):
    return {'parent': parent, 'command': command, 'start': start}


class IsolatedCrashEvidenceTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)

    def capture_snapshots(self, snapshots):
        process = SimpleNamespace(pid=10, exit_code=None)
        process.poll = lambda: process.exit_code
        samples = iter(snapshots)

        def read_snapshot():
            rows, process.exit_code = next(samples)
            return rows

        capture = evidence.IsolatedCrashEvidence(
            self.root, self.root / 'evidence', roots=[], read_snapshot=read_snapshot)
        # Run the observer synchronously against synthetic snapshots, without a thread or ps.
        with patch.object(evidence.threading, 'Thread') as thread, \
                patch.object(capture.stop, 'wait',
                             side_effect=[False] * (len(snapshots) - 1) + [True]):
            thread.return_value.start.side_effect = lambda: thread.call_args.kwargs['target']()
            capture.start(process)
        self.assertEqual(capture.errors, [])
        return capture

    def test_live_root_exec_keeps_both_commands_and_discovers_new_test_descendants(self):
        original = row(1, '/tool/swift test --filter selected')
        executed = row(1, '/tool/swift-test --filter selected')
        helper = row(10, '/tool/swiftpm-testing-helper --test-bundle-path native')
        native = row(11, '/build/L337PackageTests')
        capture = self.capture_snapshots([
            ({10: original}, None),
            ({10: executed, 11: helper}, None),
            ({10: executed, 11: helper, 12: native, 90: row(1, 'foreign')}, None),
        ])
        self.assertEqual(capture.history, {10: [original, executed], 11: [helper], 12: [native]})
        self.assertEqual(capture.known, {10: executed, 11: helper, 12: native})

    def test_exited_root_cannot_reenrol_even_with_the_same_start_and_command(self):
        original = row(1, '/tool/swift test --filter selected')
        capture = self.capture_snapshots([
            ({10: original}, None),
            ({}, 0),
            ({10: original, 11: row(10, '/tool/swiftpm-testing-helper')}, 0),
        ])
        self.assertEqual(capture.history, {10: [original]})

    def test_root_exit_during_first_snapshot_never_establishes_authority(self):
        capture = self.capture_snapshots([
            ({10: row(1, '/tool/swift test'),
              11: row(10, '/tool/swiftpm-testing-helper')}, 0),
        ])
        self.assertEqual(capture.history, {})
        self.assertEqual(capture.known, {})

    def test_live_poll_cannot_authorize_a_changed_start_root(self):
        original = row(1, '/tool/swift test --filter selected')
        replacement = row(1, '/tool/swift-test --filter selected', start='later')
        capture = self.capture_snapshots([
            ({10: original}, None),
            ({10: replacement, 11: row(10, '/tool/swiftpm-testing-helper')}, None),
        ])
        self.assertEqual(capture.history, {10: [original]})
        self.assertEqual(capture.known[10], original)

    def test_old_evidence_is_cleared_and_foreign_or_symbolic_roots_refused(self):
        directory = self.root / 'evidence'
        directory.mkdir()
        (directory / 'stale.ips').write_text('old run')
        evidence.IsolatedCrashEvidence(self.root, directory, roots=[])
        self.assertFalse(directory.exists())
        directory.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            evidence.IsolatedCrashEvidence(self.root, directory, roots=[])
        self.assertTrue(self.root.is_dir())
        with self.assertRaises(ValueError):
            evidence.IsolatedCrashEvidence(self.root, self.root.parent / 'outside', roots=[])

    def test_only_live_owned_ancestry_enters_history(self):
        rows = {10: row(1), 11: row(10, 'swift helper'), 12: row(11, 'native test'),
                90: row(1, 'unrelated'), 91: row(90, 'other test')}
        known, history = {}, {}
        evidence.observe_descendants(rows, 10, known, history, root_alive=True)
        self.assertEqual(set(history), {10, 11, 12})
        evidence.observe_descendants(rows, 10, known, history, root_alive=True)
        self.assertTrue(all(len(records) == 1 for records in history.values()))

    def test_reused_root_or_child_pid_cannot_confer_ownership(self):
        known, history = {}, {}
        evidence.observe_descendants({10: row(1), 11: row(10)}, 10, known, history,
                                     root_alive=True)
        reused = {10: row(1, start='later'), 11: row(1, start='later'), 12: row(11)}
        evidence.observe_descendants(reused, 10, known, history, root_alive=True)
        self.assertEqual(set(history), {10, 11})
        self.assertEqual(known[10]['start'], 'Thu Oct 22 01:00:00 2026')

    def test_changed_unowned_command_does_not_match_old_identity(self):
        known, history = {}, {}
        evidence.observe_descendants({10: row(1), 11: row(10)}, 10, known, history,
                                     root_alive=True)
        evidence.observe_descendants({11: row(1, command='unrelated exec'), 12: row(11)},
                                     10, known, history, root_alive=True)
        self.assertNotIn(12, history)
        self.assertEqual(history[11][0]['command'], 'owned')

    def test_completed_compiler_commands_are_not_retained_as_crash_history(self):
        capture = evidence.IsolatedCrashEvidence(self.root, self.root / 'evidence', roots=[])
        rows = {10: row(1, '/tool/swift test'),
                11: row(10, '/tool/swift-frontend ' + 'large-file.swift ' * 1000),
                12: row(10, '/tool/swiftpm-testing-helper --test-bundle-path native')}
        capture.observe(rows, 10, root_alive=True)
        self.assertEqual(set(capture.history), {10, 12})
        capture.observe({10: rows[10]}, 10, root_alive=True)
        self.assertEqual(set(capture.known), {10})
        self.assertEqual(set(capture.history), {10, 12})

    def test_snapshot_preserves_start_and_full_arguments_without_running_ps(self):
        text = ' 10 1 Thu Oct 22 01:00:00 2026 /tool/swift helper --filter selected name\n'
        with patch.object(evidence.subprocess, 'check_output', return_value=text) as read:
            rows = evidence.snapshot()
        self.assertEqual(rows[10]['start'], 'Thu Oct 22 01:00:00 2026')
        self.assertEqual(rows[10]['command'], '/tool/swift helper --filter selected name')
        self.assertNotIn('timeout',read.call_args.kwargs)

    def test_failure_retains_only_exact_attributed_reports_and_existing_images(self):
        capture = evidence.IsolatedCrashEvidence(self.root, self.root / 'evidence', roots=[])
        capture.history = {10: [row(1)]}
        matched = {'matchedActualProcess': True, 'retained': 'matched-crashes/owned.ips'}
        other = {'matchedActualProcess': False, 'name': 'unrelated.ips'}
        with patch.object(evidence, 'retain_test_images', return_value=['existing image']) as images, \
                patch.object(evidence, 'collect_reports', return_value=([matched, other], {})) as reports:
            result = capture.finish('a' * 40, failed=True)
        self.assertEqual(result['reports'], 1)
        self.assertEqual(result['matchedReports'], 1)
        saved = json.loads((capture.evidence / 'crash-originals.json').read_text())
        self.assertEqual(saved, [matched])
        self.assertNotIn('observed_images', reports.call_args.kwargs)
        self.assertEqual(images.call_args.args[0], capture.history)

    def hosted_environment(self):
        ref = 'refs/heads/validation/swift-612-isolated-fault'
        return {
            'GITHUB_ACTIONS': 'true', 'RUNNER_ENVIRONMENT': 'github-hosted',
            'RUNNER_OS': 'macOS', 'RUNNER_ARCH': 'ARM64',
            'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_JOB': 'isolated-units',
            'GITHUB_REPOSITORY': 'stephenlclarke/l337', 'GITHUB_REF': ref,
            'GITHUB_WORKFLOW_REF': f'stephenlclarke/l337/.github/workflows/unit-tests.yml@{ref}',
            'GITHUB_SHA': 'a' * 40, 'GITHUB_WORKFLOW_SHA': 'a' * 40,
            'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1',
        }

    def retained_image(self):
        return {
            'status': 'retained-image', 'pid': 11, 'start': 'Thu Oct 22 01:00:00 2026',
            'helperExecutable': '/tool/swiftpm-testing-helper', 'imageSHA256': 'b' * 64,
            'image': str(self.root.resolve() / '.build/Tests.xctest/Contents/MacOS/Tests'),
            'imageUUID': {'uuids': {'arm64': '8DC3D7A8-EFE3-39F0-9F57-E2FC2AA81C6A'}},
        }

    def hosted_capture(self, roots=()):
        workspace = self.root.resolve()
        return evidence.IsolatedCrashEvidence(
            workspace, workspace / 'evidence', roots=roots,
            selector=r'(?:^|\.)Example/test\(',
            swift_xml=workspace / 'reports/isolated-units/tests-swift-testing.xml')

    def helper_row(self, capture, image):
        command = ' '.join([
            image['helperExecutable'], '--test-bundle-path', image['image'],
            '--enable-code-coverage', '--filter', capture.selector,
            '--xunit-output', str(capture.swift_xml), image['image'],
            '--testing-library', 'swift-testing',
        ])
        return row(10, command, image['start'])

    def test_hosted_validation_retains_late_owned_report_but_refuses_adjacent_launch_second(self):
        directory = self.root.resolve() / 'DiagnosticReports'
        directory.mkdir()
        capture = self.hosted_capture([directory])
        image = self.retained_image()
        helper = self.helper_row(capture, image)
        # Repeated snapshots are one helper identity. Other owned children do not qualify.
        capture.history = {11: [helper, dict(helper)], 12: [row(10, '/tool/dsymutil', image['start'])]}
        launch = datetime.strptime(image['start'], '%a %b %d %H:%M:%S %Y').astimezone()
        report = {'pid': 11, 'procPath': image['helperExecutable'],
                  'procLaunch': (launch + timedelta(milliseconds=125)).isoformat()}
        adjacent = report | {'procLaunch': (launch + timedelta(seconds=1)).isoformat()}
        self.assertTrue(crash_artifacts.attributed_report(adjacent, capture.history))
        other_owned = report | {'pid': 12, 'procPath': '/tool/dsymutil'}
        self.assertTrue(crash_artifacts.attributed_report(other_owned, capture.history))
        raw = json.dumps(report)
        elapsed = 0.0

        def sleep(seconds):
            nonlocal elapsed
            elapsed += seconds
            if elapsed == 4.0:
                (directory / 'owned.ips').write_text(raw)
                (directory / 'adjacent.ips').write_text(json.dumps(adjacent))
                (directory / 'other-owned.ips').write_text(json.dumps(other_owned))

        with patch.dict(evidence.os.environ, self.hosted_environment(), clear=True), \
                patch.object(evidence, 'retain_test_images', return_value=[image]), \
                patch.object(crash_artifacts.time, 'monotonic', side_effect=lambda: elapsed), \
                patch.object(crash_artifacts.time, 'sleep', side_effect=sleep):
            result = capture.finish('a' * 40, failed=True)
        self.assertEqual(elapsed, evidence.HOSTED_REPORT_WINDOW_SECONDS)
        self.assertEqual(result['hostedValidation']['runID'], '123')
        self.assertEqual(result['hostedValidation']['runAttempt'], '1')
        self.assertEqual(result['hostedValidation']['workflowSHA'], 'a' * 40)
        self.assertEqual(result['hostedValidation']['observedImage'], {
            'pid': 11, 'parent': 10, 'start': image['start'], 'helper': image['helperExecutable'],
            'commandSHA256': sha256(helper['command'].encode()).hexdigest(),
            'sha256': image['imageSHA256'], 'uuid': image['imageUUID']['uuids']['arm64'],
        })
        self.assertEqual(result['matchedReports'], 1)
        records = json.loads((capture.evidence / 'crash-originals.json').read_text())
        self.assertEqual([record['identity']['pid'] for record in records], [11])
        self.assertEqual((capture.evidence / records[0]['retained']).read_text(), raw)
        self.assertFalse(list(capture.evidence.rglob('*adjacent.ips')))
        self.assertFalse(list(capture.evidence.rglob('*other-owned.ips')))

    def test_same_bundle_with_another_helper_or_wrong_argv_stays_on_ordinary_collection(self):
        image = self.retained_image()
        capture = self.hosted_capture()
        helper = self.helper_row(capture, image)
        wrong = row(10, f"{image['helperExecutable']} --test-bundle-path {image['image']}", image['start'])
        for history in ({11: [wrong]}, {11: [helper], 12: [helper]}, {11: [helper], 12: [wrong]}):
            with self.subTest(history=history):
                capture = self.hosted_capture()
                capture.history = history
                with patch.dict(evidence.os.environ, self.hosted_environment(), clear=True), \
                        patch.object(evidence, 'retain_test_images', return_value=[image]), \
                        patch.object(evidence, 'collect_reports', return_value=([], {})) as collect:
                    result = capture.finish('a' * 40, failed=True)
                self.assertEqual(collect.call_args.args[2], history)
                self.assertEqual(collect.call_args.kwargs, {})
                self.assertNotIn('hostedValidation', result)

    def test_different_workflow_sha_stays_on_ordinary_collection(self):
        capture = self.hosted_capture()
        image = self.retained_image()
        capture.history = {11: [self.helper_row(capture, image)]}
        environment = self.hosted_environment() | {'GITHUB_WORKFLOW_SHA': 'd' * 40}
        with patch.dict(evidence.os.environ, environment, clear=True), \
                patch.object(evidence, 'retain_test_images', return_value=[image]), \
                patch.object(evidence, 'collect_reports', return_value=([], {})) as collect:
            result = capture.finish('a' * 40, failed=True)
        self.assertEqual(collect.call_args.kwargs, {})
        self.assertNotIn('hostedValidation', result)

    def test_extended_collection_refuses_other_events_revisions_or_unbound_images(self):
        for label, changes, images in (
                ('pull request', {'GITHUB_EVENT_NAME': 'pull_request'}, [self.retained_image()]),
                ('self-hosted', {'RUNNER_ENVIRONMENT': 'self-hosted'}, [self.retained_image()]),
                ('wrong workflow', {'GITHUB_WORKFLOW_REF': 'other'}, [self.retained_image()]),
                ('wrong checkout', {'GITHUB_SHA': 'd' * 40}, [self.retained_image()]),
                ('no image', {}, []),
                ('no arm64 UUID', {}, [self.retained_image() | {'imageUUID': {'uuids': {}}}]),
                ('ambiguous images', {}, [self.retained_image(), self.retained_image()])):
            with self.subTest(label=label):
                capture = self.hosted_capture()
                capture.history = {11: [self.helper_row(capture, self.retained_image())]}
                with patch.dict(evidence.os.environ, self.hosted_environment() | changes, clear=True), \
                        patch.object(evidence, 'retain_test_images', return_value=images), \
                        patch.object(evidence, 'collect_reports', return_value=([], {})) as collect:
                    result = capture.finish('a' * 40, failed=True)
                self.assertNotIn('window', collect.call_args.kwargs)
                self.assertNotIn('hostedValidation', result)

    def test_live_observer_and_capture_failures_keep_full_error_details_in_raw_evidence(self):
        detail='fixture observer: '+('\u754c'*5000)+' exact-final-detail'
        capture=evidence.IsolatedCrashEvidence(self.root,self.root/'evidence',roots=[],
            read_snapshot=lambda:(_ for _ in ()).throw(OSError(detail)))
        process=SimpleNamespace(pid=10,poll=lambda:None)
        with patch.object(evidence.threading,'Thread') as thread:
            thread.return_value.start.side_effect=lambda:thread.call_args.kwargs['target']()
            thread.return_value.is_alive.return_value=False
            capture.start(process)
        self.assertEqual(capture.errors,[{'type':'OSError','detail':detail}])
        collector_detail='fixture collector: '+('x'*9000)+' original-suffix'
        with patch.object(evidence,'retain_test_images',side_effect=ValueError(collector_detail)):
            result=capture.finish('c'*40,failed=True)
        self.assertEqual(result['errors'],[{'type':'OSError','detail':detail}])
        self.assertEqual(result['captureError'],{'type':'ValueError','detail':collector_detail})
        self.assertNotIn('matchedReports',result)
        saved=json.loads((capture.evidence/'capture.json').read_text())
        self.assertEqual(saved['errors'],result['errors'])
        self.assertEqual(saved['captureError'],result['captureError'])

    def test_success_does_not_collect_reports_or_copy_images(self):
        capture = evidence.IsolatedCrashEvidence(self.root, self.root / 'evidence', roots=[])
        with patch.object(evidence, 'collect_reports') as reports, \
                patch.object(evidence, 'retain_test_images') as images:
            result = capture.finish('b' * 40, failed=False)
        reports.assert_not_called()
        images.assert_not_called()
        self.assertFalse(result['observerAlive'])
        self.assertFalse(capture.evidence.exists())

    def test_capture_error_is_reported_without_invented_crash_attribution(self):
        capture = evidence.IsolatedCrashEvidence(self.root, self.root / 'evidence', roots=[])
        with patch.object(evidence, 'retain_test_images', side_effect=OSError('fixture refusal')):
            result = capture.finish('c' * 40, failed=True)
        self.assertEqual(result['captureError']['type'], 'OSError')
        self.assertNotIn('matchedReports', result)

    def test_original_failed_unit_exit_and_child_environment_survive_capture_error(self):
        process = SimpleNamespace(stdout=iter(['fixture output\n']), wait=lambda: 10)
        class Child:
            def __enter__(self): return process
            def __exit__(self, *args): return False
        with patch.object(units, 'ROOT', self.root), \
                patch.object(units.subprocess, 'check_output', return_value='d' * 40), \
                patch.object(units.subprocess, 'Popen', return_value=Child()) as launch, \
                patch.object(units, 'IsolatedCrashEvidence') as hook, \
                patch.object(units, 'inspect_report') as inspect, \
                patch.dict(units.os.environ, {'FIXTURE_SECRET': 'never log this'}), \
                patch('sys.stdout', new=io.StringIO()):
            hook.return_value.finish.side_effect = OSError('fixture refusal')
            result = units.main()
        self.assertEqual(result, 10)
        inspect.assert_not_called()
        saved = json.loads((self.root / 'reports/isolated-units/result.json').read_text())
        self.assertEqual(saved['exit_code'], 10)
        self.assertEqual(saved['status'], 'failed')
        self.assertNotIn('never log this', json.dumps(saved))
        child_env = launch.call_args.kwargs['env']
        self.assertEqual(child_env['FIXTURE_SECRET'], 'never log this')
        self.assertIn('enable=no', child_env['SWIFT_BACKTRACE'])
        self.assertIn('interactive=no', child_env['SWIFT_BACKTRACE'])
        hook.return_value.start.assert_called_once_with(process)
        hook.return_value.finish.assert_called_once_with('d' * 40, failed=True)


if __name__ == '__main__':
    unittest.main()
