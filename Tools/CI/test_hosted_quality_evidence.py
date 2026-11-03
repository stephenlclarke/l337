"""Offline fake-process contracts only; never authorize or execute a native quality job."""
from contextlib import ExitStack
import copy
import json
import os
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import hosted_quality_evidence as evidence
import quality_phase_checkpoints as phases
import test_quality_phase_checkpoints as phase_fixture


class HostedQualityEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.phase = phase_fixture.QualityPhaseTests()
        self.phase.setUp()
        self.addCleanup(self.phase.doCleanups)
        self.root = self.phase.root
        moved = self.root / '.build/bin'
        moved.parent.mkdir()
        self.phase.bins.rename(moved)
        self.phase.bins = moved
        self.phase.image = moved / 'Tests.xctest/Contents/MacOS/Tests'
        self.capture_root = self.root / evidence.EVIDENCE
        self.capture_root.mkdir(parents=True)
        self.job = {'assignment': {'head': self.phase.head, 'run_id': '100', 'run_attempt': '1',
                                  'job': 'native_checks', 'runner': 'fixture', 'workspace': str(self.root)},
                    'assignment_sha256': 'a' * 64, 'policy_raw_sha256': 'b' * 64}
        self.authority = SimpleNamespace(policy={'swift': 'fixed toolchain/SDK identity',
                                                 'sdk': 'fixed toolchain/SDK identity'},
                                         output=self.phase.output)

    def profile(self, _path, _checksum, phase, _environment):
        return {'kind': 'owned-phase-build-v1', 'phase': phase, 'profile': 'fixture',
                'policy_sha256': 'c' * 64, 'admission': {'explicit': 1},
                'flags': ['--jobs', '1', '-Xswiftc', '-disable-batch-mode']}

    def context(self):
        stack = ExitStack()
        stack.enter_context(self.phase.context())
        stack.enter_context(patch.dict(os.environ, GITHUB_ACTIONS='true', GITHUB_JOB='native_checks',
                                      GITHUB_SHA=self.phase.head, GITHUB_REF='refs/heads/main',
                                      GITHUB_EVENT_NAME='push'))
        stack.enter_context(patch.object(evidence, 'ROOT', self.root))
        stack.enter_context(patch.object(evidence, '_authenticated_job',
                                        side_effect=lambda: (self.authority, copy.deepcopy(self.job))))
        stack.enter_context(patch.object(evidence, 'executable_inputs',
                                        return_value={'Sources/fake.swift': 'fixed'}))
        stack.enter_context(patch.object(phases, 'reviewed_build_profile', side_effect=self.profile))
        return stack

    def record(self, name, value):
        (self.capture_root / name).write_text(json.dumps(value) + '\n')

    def seal_fake_aggregate(self, capture, exit_code=0):
        # Explicit fake make-ci ledger: tests exercise refusal/consumption, never assert real CI PASS.
        (self.capture_root / 'ci.log').write_text('fake make ci completion\n')
        command = {'command': ['make', 'ci'], 'makeExitCode': exit_code, 'exitCode': exit_code,
                   'interrupted': False, 'monitorErrors': [], 'remainingAfterCleanup': {},
                   'rawSHA256': evidence.digest(self.capture_root / 'ci.log')}
        self.record('ci.json', command)
        self.record('summary.json', {'head': self.phase.head, 'headUnchanged': True,
                                    'changedTrackedInputs': [], 'exitCode': exit_code,
                                    'attempts': [command]})
        evidence.seal_capture(capture)
        self.record('originals-manifest.json', {str(p.relative_to(self.capture_root)): evidence.digest(p)
                                               for p in self.capture_root.rglob('*') if p.is_file()})

    def complete(self):
        capture = evidence.begin_capture()
        self.phase.fail_leaks = False
        phases.run_phase('normal', self.root / 'normal-cache')
        phases.run_phase('leaks', self.root / 'leak-cache')
        self.seal_fake_aggregate(capture)
        return capture

    def test_same_authenticated_capture_consumes_each_complete_phase_without_rerunning_it(self):
        with self.context():
            self.complete()
            calls = list(self.phase.calls)
            evidence.consume_for_sonar()
            evidence.consume_for_sonar()
            self.assertEqual(self.phase.calls, calls)
            self.assertEqual(sum(c[1] == 'test' for c in calls), 1)
            self.assertEqual(sum(c[0] == '/usr/bin/leaks' for c in calls), 1)
            self.assertTrue((self.root / 'coverage.xml').is_file())
            self.assertTrue((self.root / 'coverage.lcov').is_file())

    def test_changed_run_attempt_head_assignment_or_workspace_cannot_borrow_phase(self):
        for field in ('run_id', 'run_attempt', 'head', 'workspace', 'runner'):
            with self.subTest(field=field), self.context():
                if not (self.capture_root / 'completed-job.json').exists():
                    self.complete()
                original = copy.deepcopy(self.job)
                self.job['assignment'][field] = 'changed'
                with self.assertRaises(ValueError):
                    evidence.consume_for_sonar()
                self.job = original

    def test_missing_aggregate_or_failed_make_ci_cannot_be_replaced_with_phase_success(self):
        with self.context():
            capture = evidence.begin_capture()
            self.phase.fail_leaks = False
            phases.run_phase('normal', self.root / 'normal-cache')
            phases.run_phase('leaks', self.root / 'leak-cache')
            with self.assertRaises((OSError, ValueError)):
                evidence.consume_for_sonar()
            with self.assertRaises(ValueError):
                self.seal_fake_aggregate(capture, exit_code=3)

    def test_changed_inputs_environment_sdk_or_image_refuse_without_new_phase(self):
        with self.context():
            self.complete()
            cases = [patch.object(evidence, 'executable_inputs', return_value={'Sources/fake.swift': 'changed'}),
                     patch.dict(os.environ, SWIFT_EXEC='/changed/toolchain'),
                     patch.object(self.authority, 'policy', {'swift': 'changed', 'sdk': 'fixed toolchain/SDK identity'}),
                     patch.object(self.authority, 'policy', {'swift': 'fixed toolchain/SDK identity', 'sdk': 'changed'}),
                     patch.object(self.authority, 'output', side_effect=lambda c:
                                  'changed SDK path' if '--show-sdk-path' in c else self.phase.output(c)),
                     patch.object(self.authority, 'output', side_effect=lambda c:
                                  'changed UUID' if 'dwarfdump' in c else self.phase.output(c))]
            calls = list(self.phase.calls)
            for change in cases:
                with change, self.assertRaises(ValueError):
                    evidence.consume_for_sonar()
            self.phase.image.write_bytes(b'changed executable')
            with self.assertRaises(ValueError):
                evidence.consume_for_sonar()
            self.assertEqual(self.phase.calls, calls)

    def test_missing_or_tampered_xml_coverage_or_receipt_is_not_consumed(self):
        with self.context():
            self.complete()
            _, summary = evidence._phase_candidates('normal', evidence.current_capture()[1])
            report, _ = evidence._phase_candidates('normal', evidence.current_capture()[1])
            self.assertEqual(summary['validation']['covered_lines'], 5)
            for name in ('tests-swift-testing.xml', 'coverage.xml', 'result.json'):
                path = report.parent / 'completed' / name
                original = path.read_bytes()
                path.write_bytes(b'changed')
                with self.assertRaises(ValueError):
                    evidence.consume_for_sonar()
                path.write_bytes(original)
            path = report.parent / 'completed' / 'coverage.lcov'
            path.unlink()
            with self.assertRaises(ValueError):
                evidence.consume_for_sonar()

    def test_main_push_is_required_and_missing_leak_phase_refuses_sealing(self):
        with self.context():
            capture = evidence.begin_capture()
            phases.run_phase('normal', self.root / 'normal-cache')
            with self.assertRaises(ValueError):
                self.seal_fake_aggregate(capture)
            with patch.dict(os.environ, GITHUB_REF='refs/pull/1/merge'), self.assertRaises(ValueError):
                evidence.consume_for_sonar()
            # Two completed normals are ambiguous, not permission to choose a convenient one.
            phases.run_phase('normal', self.root / 'second-normal-cache')
            with self.assertRaisesRegex(ValueError, 'Exactly one'):
                self.seal_fake_aggregate(capture)


if __name__ == '__main__':
    unittest.main()
