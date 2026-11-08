"""Synthetic identity/report fixtures only; no host process, real report, native image or debugger."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import passive_failure_evidence as evidence

UUID = '11111111-1111-1111-1111-111111111111'
IMAGE = dict(path='/owned/.build/L337CoreTests.xctest/Contents/MacOS/L337CoreTests',
             sha256='1' * 64, uuids=[UUID])
EPOCH = 1700000000
START = datetime.fromtimestamp(EPOCH).strftime('%a %b %d %H:%M:%S %Y')
LAUNCH = datetime.fromtimestamp(EPOCH, timezone.utc).strftime('%Y-%m-%d %H:%M:%S %z')


def owned(command='/tool/swiftpm-testing-helper', start=START, parent=10):
    return dict(parent=parent, group=10, start=start, command=command, rss=1024)


class PassiveFailureEvidenceTests(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.root = Path(folder.name).resolve(strict=True)
        self.reports = self.root / 'reports'
        self.reports.mkdir()

    def capture(self, name='evidence'):
        return evidence.PassiveFailureEvidence(self.root / name, IMAGE, roots=[self.reports], clock=lambda: 1)

    def report(self, name='swiftpm-testing-helper-2026-11-04-233000.ips', **changes):
        value = dict(pid=11, procPath='/tool/swiftpm-testing-helper', procLaunch=LAUNCH,
                     usedImages=[dict(path=IMAGE['path'], uuid=UUID)])
        value.update(changes)
        path = self.reports / name
        raw = json.dumps(value).encode()
        path.write_bytes(raw)
        return path, raw

    def observe(self, capture):
        rows = {10: owned('/tool/swift test --filter selected', parent=1),
                11: owned(), 90: owned('/foreign/swiftpm-testing-helper', parent=1)}
        capture.observe(rows, {10, 11}, 10)
        return rows

    def test_exact_owned_identity_and_test_uuid_preserve_unchanged_natural_report(self):
        capture = self.capture()
        rows = self.observe(capture)
        stored = json.loads((capture.directory / 'observed-processes.json').read_text())
        self.assertEqual(set(stored['processes']), {'10', '11'})
        self.assertEqual(stored['processes']['11'][0]['command'], rows[11]['command'])
        path, raw = self.report()
        result = capture.finish(True, 10)
        self.assertEqual(result['matchedReports'], 1)
        retained = capture.directory / result['reports'][0]['retained']
        self.assertEqual(retained.read_bytes(), raw)
        self.assertEqual(path.read_bytes(), raw)
        self.assertEqual(result['reports'][0]['sha256'], hashlib.sha256(raw).hexdigest())

    def test_pid_reuse_launch_and_executable_mismatch_never_retain_a_report(self):
        for index, changes in enumerate([
                {'pid': 90}, {'procLaunch': '2000-01-01 00:00:00 +0000'},
                {'procPath': '/foreign/swiftpm-testing-helper'}]):
            capture = self.capture(str(index))
            self.observe(capture)
            self.report(name=f'swiftpm-testing-helper-2026-11-04-23300{index}.ips', **changes)
            result = capture.finish(True, 10)
            self.assertEqual(result['matchedReports'], 0)
            self.assertFalse(any('retained' in row for row in result['reports']))

    def test_exact_pid_start_path_without_the_frozen_test_uuid_is_unknown(self):
        for index, images in enumerate([[], [dict(path=IMAGE['path'], uuid='2' * 36)],
                                       [dict(path='/foreign/test', uuid=UUID)]]):
            capture = self.capture(str(index))
            self.observe(capture)
            self.report(name=f'swiftpm-testing-helper-2026-11-04-23400{index}.ips', usedImages=images)
            result = capture.finish(True, 10)
            self.assertEqual(result['matchedReports'], 0)
            self.assertTrue(all(row['status'] == 'unproved-frozen-test-uuid' for row in result['reports']))

    def test_existing_report_and_success_do_not_trigger_body_reads_or_old_report_hunts(self):
        self.report()
        capture = self.capture()
        self.observe(capture)
        with patch.object(evidence, 'report_identity') as decode:
            self.assertEqual(capture.finish(True, 10)['reports'], [])
            decode.assert_not_called()
        other = self.capture('success')
        with patch.object(other, 'report_inventory') as inventory, patch.object(evidence, 'report_identity') as decode:
            self.assertEqual(other.finish(False, 10)['reports'], [])
            inventory.assert_not_called()
            decode.assert_not_called()

    def test_fresh_directory_and_symbolic_report_roots_are_not_overwritten_or_read(self):
        capture = self.capture()
        with self.assertRaises(ValueError):
            self.capture()
        alias = self.root / 'alias'
        alias.symlink_to(self.reports, target_is_directory=True)
        other = evidence.PassiveFailureEvidence(self.root / 'other', IMAGE, roots=[alias], clock=lambda: 1)
        self.assertIn('symbolic-report-root', other.errors)
        source, _ = self.report()
        link = self.reports / 'swiftpm-testing-helper-2026-11-04-235000.ips'
        link.symlink_to(source)
        self.observe(capture)
        result = capture.finish(True, 10)
        self.assertFalse(any(row['name'] == link.name for row in result['reports']))

    def test_large_exact_report_is_retained_after_legacy_deadline_without_process_probes(self):
        capture=self.capture()
        self.observe(capture)
        path,raw=self.report()
        raw+=b' '*(1024*1024+1)
        path.write_bytes(raw)
        result=capture.finish(True,0)
        self.assertEqual(result['matchedReports'],1)
        self.assertEqual((capture.directory/result['reports'][0]['retained']).read_bytes(),raw)
        preparation=evidence.PassiveFailureEvidence(self.root/'expired-legacy-deadline',IMAGE,
            roots=[self.reports],clock=lambda:1,deadline=0)
        self.assertNotIn('report-inventory-deadline',preparation.errors)

    def test_elapsed_legacy_deadline_during_validation_or_hashing_keeps_verified_report(self):
        for index, phase in enumerate(['validation', 'hashing']):
            with self.subTest(phase=phase):
                capture = self.capture(phase)
                self.observe(capture)
                source, raw = self.report(name=f'swiftpm-testing-helper-2026-11-04-23500{index}.ips')
                now = [1]
                capture.clock = lambda: now[0]
                if phase == 'validation':
                    def validated(*args):
                        now[0] = 11
                        return True
                    with patch.object(evidence, 'report_has_test_uuid', side_effect=validated) as validate:
                        result = capture.finish(True, 10)
                    validate.assert_called_once()
                    expected_status = 'report-validation-deadline'
                else:
                    original_hash = hashlib.sha256
                    def hashed(*args):
                        value = original_hash(*args)
                        now[0] = 11
                        return value
                    with patch.object(evidence.hashlib, 'sha256', side_effect=hashed) as digest:
                        result = capture.finish(True, 10)
                    digest.assert_called_once()
                    expected_status = 'report-persist-deadline'
                self.assertEqual(result['matchedReports'],1)
                self.assertEqual((capture.directory/result['reports'][0]['retained']).read_bytes(),raw)
                self.assertEqual(source.read_bytes(), raw)

    def test_long_commands_and_all_selected_records_are_retained_with_exact_identity(self):
        capture=self.capture()
        command='/tool/swiftpm-testing-helper '+'x'*9000
        capture.observe({11:owned(command)},{11},10)
        self.assertFalse(capture.truncated)
        self.assertEqual(capture.history['11'][0]['command'],command)
        rows={pid:owned() for pid in range(100,200)}
        capture.observe(rows,set(rows),10)
        self.assertEqual(sum(map(len,capture.history.values())),101)
        self.assertEqual(len(capture.history),101)
        self.assertEqual(json.loads((capture.directory/'observed-processes.json').read_text())['processes'],capture.history)

    def test_all_inventory_errors_survive_owned_observation_and_raw_capture(self):
        capture=self.capture()
        # Feed real inventory failures through the existing source, rather than
        # directly testing a list slice or inventing a successful capture.
        with patch.object(evidence.os,'scandir',side_effect=PermissionError('fixture denied')):
            for _ in range(24):capture.report_inventory()
        expected=['PermissionError']*24
        self.assertEqual(capture.errors,expected)
        self.observe(capture)
        observed=json.loads((capture.directory/'observed-processes.json').read_text())
        self.assertEqual(observed['errors'],expected)
        self.assertEqual(set(observed['processes']),{'10','11'})
        result=capture.finish(False)
        self.assertEqual(result['errors'],expected)
        self.assertEqual(json.loads((capture.directory/'capture.json').read_text())['errors'],expected)
        self.assertEqual(result['reports'],[])
        self.assertTrue(result['noDebugger'])
        self.assertTrue(result['noExtraProcessSamples'])

    def test_same_pid_start_exec_versions_remain_exact_but_unselected_rows_never_enter_history(self):
        capture = self.capture()
        rows = self.observe(capture)
        rows[11] = owned('/tool/swiftpm-testing-helper --testing-library swift-testing')
        capture.observe(rows, {10, 11}, 10)
        self.assertEqual(len(capture.history['11']), 2)
        self.assertNotIn('90', capture.history)
        _, raw = self.report()
        result = capture.finish(True, 10)
        self.assertEqual(result['matchedReports'], 1)
        self.assertEqual((capture.directory / result['reports'][0]['retained']).read_bytes(), raw)


if __name__ == '__main__':
    unittest.main()
