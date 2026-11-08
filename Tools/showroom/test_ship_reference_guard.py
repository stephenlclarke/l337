"""Exercise closed compiler/asset bounds with fake children and no host sampling."""
from contextlib import contextmanager
import importlib.util
import io
import shlex
import subprocess
import sys
import tempfile
from types import SimpleNamespace
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location(
    'ship_reference_guard', Path(__file__).with_name('ship-reference.py'))
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


class ShipReferenceGuardTests(unittest.TestCase):
    def command(self):
        return ['/bound/toolchain/swift', 'build', '--build-tests', '--enable-code-coverage',
                '--jobs', '1', '-Xswiftc', '-disable-batch-mode']

    def guarded(self, resident, profile=None, command=None):
        process = Mock(pid=987654, returncode=None)
        def completed():
            process.returncode = 0
            return 0
        process.poll.side_effect = completed
        rows = {987654: {'parent': 0, 'group': 987654, 'start': 'unit-start', 'rss': resident}}
        with patch.object(reference.subprocess, 'Popen', return_value=process) as launch, \
                patch.object(reference, 'process_memory', return_value=rows) as sample, \
                patch.object(reference, 'stop_renderer', return_value=(True, False)) as cleanup, \
                patch.object(reference.time, 'monotonic', return_value=10):
            options = {} if profile is None else {'profile': profile}
            code = reference.run_renderer(self.command() if command is None else command, Path('/unit'), io.BytesIO(), (), 100,
                                          **options)
            launch.assert_called_once()
            sample.assert_called_once()
            cleanup.assert_called_once()
            return code

    def test_default_asset_budget_preserves_its_inclusive_limit_and_refusal_cleanup(self):
        self.assertEqual(reference.ASSET_RSS, 2415919104)
        self.assertEqual(self.guarded(reference.ASSET_RSS), 0)
        self.assertEqual(self.guarded(reference.ASSET_RSS + 1), 1)

    def test_asset_build_and_render_share_one_guard_without_overlap(self):
        @contextmanager
        def lock(_path):
            yield SimpleNamespace(fileno=lambda: 17)

        for build_exit in (0, 1):
            with self.subTest(build_exit=build_exit), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                custody = root / 'control' / 'custody'
                guard = SimpleNamespace(file_claim=lock, worker_limit=Mock())
                native = SimpleNamespace(diagnostic_custody_root=lambda: custody)
                vm_stat = (
                    b'page size of 16384 bytes\nPages free: 2000000.\n'
                    b'Pages inactive: 0.\nPages speculative: 0.\n'
                )
                with patch.dict(sys.modules, {'native_runner': native, 'recoverable_shards': guard}), \
                        patch.object(sys, 'path', list(sys.path)), \
                        patch.object(reference.Path, 'cwd', return_value=root), \
                        patch.object(reference.subprocess, 'check_output', return_value=vm_stat), \
                        patch.object(reference, 'run_renderer', side_effect=[build_exit, 0]) as execute:
                    if build_exit:
                        with self.assertRaisesRegex(RuntimeError, 'Ship media build exited 1'):
                            reference.render_media(['SH005', 'SH058'])
                    else:
                        staged = reference.render_media(['SH005', 'SH058'])
                calls = [call.args for call in execute.call_args_list]
                options = ['--build-system', 'native', '--jobs', '1', '-Xswiftc', '-disable-batch-mode']
                self.assertEqual(calls[0][0], ['swift', 'build', *options, '--product', 'L337'])
                self.assertEqual(execute.call_count, 1 if build_exit else 2)
                if not build_exit:
                    self.assertEqual(calls[1][0], [
                        'swift', 'run', *options, '--skip-build', 'L337',
                        '--ship-media-directory', str(staged), '--ship-media', 'SH005', 'SH058'])
                    self.assertEqual(calls[0][1:], calls[1][1:])
                self.assertEqual(calls[0][1], root)
                self.assertEqual(calls[0][3], [17, 17])
                self.assertTrue(all(not call.kwargs for call in execute.call_args_list))
                guard.worker_limit.assert_called_once()
                self.assertEqual(guard.worker_limit.call_args.kwargs['peak_per_worker'], reference.ASSET_RSS)

    def test_compiler_has_its_own_inclusive_six_gib_limit_and_keeps_cleanup(self):
        self.assertEqual(reference.NORMAL_COMPILER_RSS, 6442450944)
        self.assertEqual(reference.NORMAL_RSS, 3221225472)
        for resident in [reference.NORMAL_RSS + 1, reference.NORMAL_COMPILER_RSS]:
            with self.subTest(resident=resident):
                self.assertEqual(self.guarded(resident, 'normal-compiler'), 0)
        self.assertEqual(self.guarded(reference.NORMAL_COMPILER_RSS + 1, 'normal-compiler'), 1)
        self.assertEqual(self.guarded(reference.NORMAL_RSS + 1), 1)

    def test_test_and_game_commands_cannot_claim_the_compiler_allowance(self):
        for command in [self.driver_command(),
                        [self.command()[0], 'test', '--enable-code-coverage', 'list', '--skip-build'],
                        ['/unit/L337'], ['/usr/bin/make', 'ci']]:
            with self.subTest(command=command), patch.object(reference.subprocess, 'Popen') as launch, \
                    patch.object(reference, 'process_memory') as sample:
                with self.assertRaises(ValueError):
                    reference.run_renderer(command, Path('/unit'), io.BytesIO(), (), 100,
                                           profile='normal-compiler')
                launch.assert_not_called()
                sample.assert_not_called()

    def driver_command(self):
        return ['/bound/toolchain/swift', 'test', '--enable-code-coverage', '--skip-build',
                '--xunit-output', '/unit/tests.xml', '--filter', 'Suite/method']

    def test_explicit_native_backend_preserves_focused_phase_bounds_and_exact_options(self):
        build = self.command() + [
            '-Xlinker', '-O0', '-Xswiftc', '-driver-batch-size-limit', '-Xswiftc', '1',
            '--disable-index-store',
        ]
        discovery = [build[0], 'test', '--enable-code-coverage', 'list', '--skip-build']
        for original, profile in (
                (build, 'normal-compiler'), (discovery, 'normal-test'),
                (self.driver_command(), 'normal-test')):
            backend = ['--build-system', 'native']
            exact = original[:2] + backend + original[2:]
            with self.subTest(command=exact):
                limit = reference.NORMAL_COMPILER_RSS if profile == 'normal-compiler' else reference.NORMAL_RSS
                self.assertEqual(self.guarded(limit, profile, exact), 0)
                self.assertEqual(self.guarded(limit + 1, profile, exact), 1)
            for changed in (
                    original[:2] + ['--build-system', 'swiftbuild'] + original[2:],
                    exact[:4] + backend + exact[4:], original + backend, exact[:-1]):
                with self.subTest(command=changed), patch.object(reference.subprocess, 'Popen') as launch:
                    with self.assertRaises(ValueError):
                        reference.run_renderer(changed, Path('/unit'), io.BytesIO(), (), 100,
                                               profile=profile)
                    launch.assert_not_called()

    def test_mission_pack_gate_retains_validation_with_one_native_compiler_job(self):
        root = Path(__file__).resolve().parents[2]
        commands = subprocess.check_output(
            ['/usr/bin/make', '-n', 'mission-packs-check'], cwd=root, text=True).strip().splitlines()
        self.assertEqual([shlex.split(command) for command in commands], [
            ['swift', 'build', '--build-system', 'native', '--jobs', '1',
             '-Xswiftc', '-disable-batch-mode', '--product', 'L337'],
            ['swift', 'run', '--build-system', 'native', '--jobs', '1',
             '-Xswiftc', '-disable-batch-mode', '--skip-build', 'L337',
             '--validate-mission-pack', 'docs/mission-packs/courier.toml'],
        ])
        self.assertEqual(reference.execution_rss_limit(shlex.split(commands[0]), 'normal-compiler'),
                         reference.NORMAL_COMPILER_RSS)
        with self.assertRaises(ValueError):
            reference.execution_rss_limit(shlex.split(commands[1]), 'normal-compiler')

    def ci_rows(self, compiler=None):
        # Entirely synthetic kernel/RSS rows: no subprocess or host resource sampling.
        observer, leader, worker, frontend = 55, 100, 101, 102
        command = compiler or (
            '/bound/toolchain/swift-build --build-tests --build-system native '
            '--enable-code-coverage --jobs 1 -Xswiftc -disable-batch-mode -Xlinker -O0 '
            '-Xswiftc -driver-batch-size-limit -Xswiftc 1 --disable-index-store')
        def row(parent, text, rss=0):
            return {'parent': parent, 'group': 100, 'start': 'unit-start', 'rss': rss, 'command': text}
        rows = {observer: row(0, '/bound/python3 observer.py'),
                leader: row(observer, '/usr/bin/make ci'), worker: row(leader, command),
                frontend: row(worker, '/bound/toolchain/swift-frontend -frontend -c source.swift')}
        return observer, leader, worker, frontend, rows

    def test_make_ci_recognizes_only_exact_actual_pure_compiler_commands(self):
        flags = ['--jobs', '1', '-Xswiftc', '-disable-batch-mode', '-Xlinker', '-O0',
                 '-Xswiftc', '-driver-batch-size-limit', '-Xswiftc', '1', '--disable-index-store']
        normal = ['/bound/toolchain/swift', 'build', '--build-tests', '--build-system', 'native',
                  '--enable-code-coverage', *flags]
        leaks = ['/bound/toolchain/swift', 'build', '--build-system', 'native', *flags]
        for command in (normal, leaks):
            with self.subTest(command=command):
                self.assertEqual(reference.execution_rss_limit(command, 'normal-compiler'),
                                 reference.NORMAL_COMPILER_RSS)
        for command in (normal + ['--jobs', '2'], normal + ['--build-system', 'native'],
                        normal[:-1], ['/bound/toolchain/swift', 'run', 'L337']):
            with self.subTest(command=command), self.assertRaises(ValueError):
                reference.execution_rss_limit(command, 'normal-compiler')

    def test_make_ci_exclusive_compiler_branch_counts_all_rss_at_six_gib(self):
        observer, leader, worker, frontend, rows = self.ci_rows()
        # Observer overhead is never subtracted from the whole selected aggregate.
        rows[observer]['rss'] = 17
        for delta, expected in ((0, 0), (1, 1)):
            with self.subTest(delta=delta):
                rows[frontend]['rss'] = reference.NORMAL_COMPILER_RSS - 17 + delta
                process = Mock(pid=leader, returncode=None)
                def completed():
                    process.returncode = 0
                    return 0
                process.poll.side_effect = completed
                with patch.object(reference.subprocess, 'Popen', return_value=process), \
                        patch.object(reference, 'process_memory', return_value=rows) as sample, \
                        patch.object(reference, 'stop_renderer', return_value=(True, False)), \
                        patch.object(reference.os, 'getpid', return_value=observer), \
                        patch.object(reference.time, 'monotonic', return_value=10):
                    code = reference.run_renderer(['/usr/bin/make', 'ci'], Path('/unit'),
                                                  io.BytesIO(), (), 100, profile='normal-ci')
                self.assertEqual(code, expected)
                self.assertTrue(sample.call_args.kwargs['include_command'])

    def test_make_ci_rechecks_runtime_cap_after_compiler_finishes_in_the_same_guard(self):
        observer, leader, worker, frontend, compiling = self.ci_rows()
        compiling[frontend]['rss'] = 4 * 1024 ** 3
        for extra, expected in ((0, 0), (1, 1)):
            runtime = {pid: dict(row) for pid, row in compiling.items() if pid not in (worker, frontend)}
            runtime[103] = {'parent': leader, 'group': 100, 'start': 'unit-runtime',
                            'rss': reference.NORMAL_RSS + extra,
                            'command': '/bound/toolchain/swift-test --skip-build'}
            process = Mock(pid=leader, returncode=None)
            polls = iter((None, 0))
            def completed():
                process.returncode = next(polls)
                return process.returncode
            process.poll.side_effect = completed
            with self.subTest(extra=extra), \
                    patch.object(reference.subprocess, 'Popen', return_value=process), \
                    patch.object(reference, 'process_memory', side_effect=(compiling, runtime)) as sample, \
                    patch.object(reference, 'stop_renderer', return_value=(True, False)), \
                    patch.object(reference.os, 'getpid', return_value=observer), \
                    patch.object(reference.time, 'monotonic', return_value=10), \
                    patch.object(reference.time, 'sleep'):
                code = reference.run_renderer(['/usr/bin/make', 'ci'], Path('/unit'),
                                              io.BytesIO(), (), 100, profile='normal-ci')
            self.assertEqual(code, expected)
            self.assertEqual(sample.call_count, 2)

    def test_make_ci_unknown_overlap_and_completed_compiler_cannot_raise_runtime_limit(self):
        observer, leader, worker, frontend, original = self.ci_rows()
        self.assertEqual(reference.normal_ci_sample_rss_limit(leader, set(original), original, observer),
                         reference.NORMAL_COMPILER_RSS)
        scenarios = []
        runtime = {pid: dict(row) for pid, row in original.items() if pid not in (worker, frontend)}
        runtime[103] = {'parent': leader, 'group': 100, 'start': 'unit-runtime', 'rss': 0,
                        'command': '/bound/swift-test --skip-build'}
        scenarios.append(runtime)
        overlap = {pid: dict(row) for pid, row in original.items()}
        overlap[103] = runtime[103]
        scenarios.append(overlap)
        unknown = {pid: dict(row) for pid, row in original.items()}
        unknown[worker]['command'] += ' --jobs 8'
        scenarios.append(unknown)
        sibling = {pid: dict(row) for pid, row in original.items()}
        sibling[103] = dict(runtime[103], command='/bound/python3 unrelated.py')
        scenarios.append(sibling)
        two_builds = {pid: dict(row) for pid, row in original.items()}
        two_builds[103] = dict(original[worker])
        scenarios.append(two_builds)
        malformed = {pid: dict(row) for pid, row in original.items()}
        malformed[worker]['command'] = '"unfinished'
        scenarios.append(malformed)
        orphan = {pid: dict(row) for pid, row in original.items()}
        orphan[worker]['parent'] = 99999
        scenarios.append(orphan)
        for index, rows in enumerate(scenarios):
            with self.subTest(index=index):
                self.assertEqual(reference.normal_ci_sample_rss_limit(leader, set(rows), rows, observer),
                                 reference.NORMAL_RSS)
        noncompiler_overflow = {pid: dict(row) for pid, row in original.items()}
        noncompiler_overflow[observer]['rss'] = reference.NORMAL_RSS + 1
        self.assertEqual(reference.normal_ci_sample_rss_limit(
            leader, set(noncompiler_overflow), noncompiler_overflow, observer), reference.NORMAL_RSS)
        # A real swift dispatcher may retain one normalized swift-build child.
        dispatched = {pid: dict(row) for pid, row in original.items()}
        dispatched[worker]['command'] = original[worker]['command'].replace('/swift-build ', '/swift build ', 1)
        dispatched[103] = dict(original[worker], parent=worker)
        dispatched[frontend]['parent'] = 103
        self.assertEqual(reference.normal_ci_sample_rss_limit(
            leader, set(dispatched), dispatched, observer), reference.NORMAL_COMPILER_RSS)
        # The one exact current sampler is allowed, but its RSS still enters the aggregate.
        sampled = {pid: dict(row) for pid, row in original.items()}
        sampled[104] = {'parent': observer, 'group': 55, 'start': 'unit-ps', 'rss': 20,
                        'command': '/bin/ps -ww -axo pid=,ppid=,pgid=,lstart=,rss=,command='}
        self.assertEqual(reference.normal_ci_sample_rss_limit(leader, set(sampled), sampled, observer),
                         reference.NORMAL_COMPILER_RSS)

    def test_make_ci_runtime_and_unknown_descendants_never_inherit_compiler_allowance(self):
        observer, leader, worker, frontend, original = self.ci_rows()
        for command in (
                '/bound/toolchain/swift-test --skip-build',
                '/bound/toolchain/swift test --skip-build',
                '/bound/toolchain/swift-run --skip-build L337',
                '/bound/toolchain/L337 --validate-mission-pack docs/mission-packs/courier.toml',
                '/bound/toolchain/L337PackageTests.xctest',
                '/bound/toolchain/python3 unknown.py',
                '/different/toolchain/swift-frontend -frontend -c source.swift'):
            rows = {pid: dict(row) for pid, row in original.items()}
            rows[103] = dict(original[frontend], parent=frontend, command=command)
            with self.subTest(command=command):
                self.assertEqual(reference.normal_ci_sample_rss_limit(
                    leader, set(rows), rows, observer), reference.NORMAL_RSS)

    def test_make_ci_nested_builds_only_allow_exact_direct_swift_dispatch_pair(self):
        observer, leader, worker, frontend, original = self.ci_rows()
        # Two real swift-build processes are never dispatcher duplication.
        nested = {pid: dict(row) for pid, row in original.items()}
        nested[103] = dict(original[worker], parent=worker)
        self.assertEqual(reference.normal_ci_sample_rss_limit(
            leader, set(nested), nested, observer), reference.NORMAL_RSS)
        # A swift dispatcher with a matching direct swift-build child is one build.
        dispatched = {pid: dict(row) for pid, row in original.items()}
        dispatched[worker]['command'] = original[worker]['command'].replace('/swift-build ', '/swift build ', 1)
        dispatched[103] = dict(original[worker], parent=worker)
        dispatched[frontend]['parent'] = 103
        self.assertEqual(reference.normal_ci_sample_rss_limit(
            leader, set(dispatched), dispatched, observer), reference.NORMAL_COMPILER_RSS)
        for command in (original[worker]['command'].replace('--build-tests ', '', 1),
                        '/bound/toolchain/swift-build --build-system native --jobs 1 '
                        '-Xswiftc -disable-batch-mode --product L337',
                        original[worker]['command'] + ' --jobs 2'):
            changed = {pid: dict(row) for pid, row in dispatched.items()}
            changed[103]['command'] = command
            with self.subTest(command=command):
                self.assertEqual(reference.normal_ci_sample_rss_limit(
                    leader, set(changed), changed, observer), reference.NORMAL_RSS)
        extra = {pid: dict(row) for pid, row in dispatched.items()}
        extra[104] = dict(original[worker], parent=103)
        self.assertEqual(reference.normal_ci_sample_rss_limit(
            leader, set(extra), extra, observer), reference.NORMAL_RSS)
        indirect = {pid: dict(row) for pid, row in dispatched.items()}
        indirect[103]['parent'] = frontend
        indirect[frontend]['parent'] = worker
        self.assertEqual(reference.normal_ci_sample_rss_limit(
            leader, set(indirect), indirect, observer), reference.NORMAL_RSS)

    def test_full_make_ci_keeps_the_same_normal_bound_and_exact_entry_point(self):
        command = ['/usr/bin/make', 'ci']
        self.assertEqual(reference.execution_admission_peak(command, 'normal-ci'),
                         reference.NORMAL_COMPILER_RSS)
        self.assertEqual(reference.execution_rss_limit(command, 'normal-ci'), reference.NORMAL_RSS)
        self.assertEqual(self.guarded(reference.NORMAL_RSS, 'normal-ci', command), 0)
        self.assertEqual(self.guarded(reference.NORMAL_RSS + 1, 'normal-ci', command), 1)
        for changed in (['make', 'ci'], ['/usr/bin/make', 'coverage-check'],
                        command + ['ELITE_SANITIZERS=0'], command + ['-j2']):
            with self.subTest(command=changed), patch.object(reference.subprocess, 'Popen') as launch:
                with self.assertRaises(ValueError):
                    reference.run_renderer(changed, Path('/unit'), io.BytesIO(), (), 100,
                                           profile='normal-ci')
                launch.assert_not_called()

    def test_normal_driver_keeps_the_existing_inclusive_normal_phase_budget(self):
        for resident, expected in [((reference.ASSET_RSS + reference.NORMAL_RSS) // 2, 0),
                                   (reference.NORMAL_RSS, 0), (reference.NORMAL_RSS + 1, 1)]:
            with self.subTest(resident=resident):
                self.assertEqual(self.guarded(resident, 'normal-test', self.driver_command()), expected)

    def test_serial_normal_driver_requires_the_exact_flag_placement(self):
        command = self.driver_command()
        serial = command[:4] + ['--no-parallel'] + command[4:]
        self.assertEqual(self.guarded(reference.NORMAL_RSS, 'normal-test', serial), 0)
        self.assertEqual(self.guarded(reference.NORMAL_RSS + 1, 'normal-test', serial), 1)
        for changed in (command + ['--no-parallel'],
                        command[:4] + ['--parallel'] + command[4:],
                        serial[:5] + ['--no-parallel'] + serial[5:]):
            with self.subTest(command=changed), patch.object(reference.subprocess, 'Popen') as launch:
                with self.assertRaises(ValueError):
                    reference.run_renderer(changed, Path('/unit'), io.BytesIO(), (), 100,
                                           profile='normal-test')
                launch.assert_not_called()

    def test_discovery_uses_the_same_normal_limit_and_rejects_other_shapes(self):
        command = ['/bound/toolchain/swift', 'test', '--enable-code-coverage', 'list', '--skip-build']
        self.assertEqual(self.guarded(reference.NORMAL_RSS, 'normal-test', command), 0)
        self.assertEqual(self.guarded(reference.NORMAL_RSS + 1, 'normal-test', command), 1)
        for changed in [command[:-1], command + ['--jobs', '2'],
                        [command[0], 'test', 'list', '--skip-build'],
                        [command[0], 'test', '--enable-code-coverage', '--skip-build', 'list']]:
            with self.subTest(command=changed), patch.object(reference.subprocess, 'Popen') as launch:
                with self.assertRaises(ValueError):
                    reference.run_renderer(changed, Path('/unit'), io.BytesIO(), (), 100,
                                           profile='normal-test')
                launch.assert_not_called()

    def test_normal_driver_rejects_unsupported_options_and_outputs_before_launch(self):
        command = self.driver_command()
        relative = command.copy()
        relative[5] = 'tests.xml'
        renamed = command.copy()
        renamed[5] = '/unit/other.xml'
        empty_filter = command.copy()
        empty_filter[7] = ''
        reordered = command.copy()
        reordered[2], reordered[3] = reordered[3], reordered[2]
        variants = [command[:-2], command + ['--jobs', '2'], relative, renamed, empty_filter,
                    reordered, [x for x in command if x != '--enable-code-coverage'],
                    [x for x in command if x != '--skip-build'], self.command()]
        for changed in variants:
            with self.subTest(command=changed), patch.object(reference.subprocess, 'Popen') as launch:
                with self.assertRaises(ValueError):
                    reference.run_renderer(changed, Path('/unit'), io.BytesIO(), (), 100,
                                           profile='normal-test')
                launch.assert_not_called()

    def test_unknown_profiles_refuse_before_any_child_or_sample(self):
        for profile in ['', 'normal', 'unlimited', None, 3221225472]:
            with self.subTest(profile=profile), \
                    patch.object(reference.subprocess, 'Popen') as launch, \
                    patch.object(reference, 'process_memory') as sample:
                with self.assertRaises(ValueError):
                    reference.run_renderer(self.command(), Path('/unit'), io.BytesIO(), (), 100,
                                           profile=profile)
                launch.assert_not_called()
                sample.assert_not_called()

    def test_missing_extra_reordered_and_noncompiler_arguments_refuse_before_launch(self):
        command = self.command()
        variants = [[], command[:-1], command + ['--jobs', '2'],
                    [command[0], 'test', *command[2:]],
                    [command[0], *command[2:4], command[1], *command[4:]],
                    ['/bound/python3', *command[1:]],
                    [x for x in command if x != '--enable-code-coverage']]
        for changed in variants:
            with self.subTest(command=changed), \
                    patch.object(reference.subprocess, 'Popen') as launch:
                with self.assertRaises(ValueError):
                    reference.run_renderer(changed, Path('/unit'), io.BytesIO(), (), 100,
                                           profile='normal-compiler')
                launch.assert_not_called()


    def test_passive_identity_uses_the_existing_rss_sample_and_same_cleanup_deadline(self):
        process = Mock(pid=987654, returncode=None)
        def completed():
            process.returncode = 1
            return 1
        process.poll.side_effect = completed
        rows = {987654: {'parent': 0, 'group': 987654, 'start': 'unit-start',
                         'rss': 1024, 'command': '/bound/toolchain/swift test'}}
        capture = Mock()
        factory = Mock(return_value=capture)
        module = SimpleNamespace(PassiveFailureEvidence=factory)
        requested = {'directory': '/unit/test-failure-evidence', 'image': {'unit': 'frozen'}}
        with patch.dict(sys.modules, {'passive_failure_evidence': module}), \
                patch.object(reference.subprocess, 'Popen', return_value=process), \
                patch.object(reference, 'process_memory', return_value=rows) as sample, \
                patch.object(reference, 'stop_renderer', return_value=(True, False)) as cleanup, \
                patch.object(reference.time, 'monotonic', return_value=10):
            self.assertEqual(reference.run_renderer(self.driver_command(), Path('/unit'), io.BytesIO(), (), 100,
                             profile='normal-test', failure_evidence=requested), 1)
        factory.assert_called_once_with('/unit/test-failure-evidence', {'unit': 'frozen'}, deadline=96)
        sample.assert_called_once_with(1, include_command=True)
        capture.observe.assert_called_once_with(rows, {987654}, 987654)
        cleanup.assert_called_once_with(process, {987654: 'unit-start'}, 14)
        capture.finish.assert_called_once_with(True, 14)

    def test_live_observation_io_failure_preserves_natural_success_and_nonzero_exit(self):
        for error_type in (OSError, ValueError):
            for natural_exit in (0, 7):
                with self.subTest(error=error_type.__name__, naturalExit=natural_exit):
                    process = Mock(pid=987654, returncode=None)
                    polls = []
                    def poll():
                        polls.append(True)
                        if len(polls) == 1:return None
                        process.returncode = natural_exit
                        return natural_exit
                    process.poll.side_effect = poll
                    rows = {987654: {'parent': 0, 'group': 987654, 'start': 'unit-start',
                                    'rss': 1024, 'command': '/bound/toolchain/swift test'}}
                    capture = Mock(directory=Path('/unit/test-failure-evidence'))
                    capture.observe.side_effect = error_type('live persist unavailable')
                    module = SimpleNamespace(PassiveFailureEvidence=Mock(return_value=capture))
                    def cleanup(*args):
                        self.assertEqual(len(polls), 2)
                        self.assertEqual(process.returncode, natural_exit)
                        return True, False
                    with patch.dict(sys.modules, {'passive_failure_evidence': module}), \
                            patch.object(reference.subprocess, 'Popen', return_value=process) as launch, \
                            patch.object(reference, 'process_memory', return_value=rows) as sample, \
                            patch.object(reference, 'stop_renderer', side_effect=cleanup) as stop, \
                            patch.object(reference.time, 'monotonic', return_value=10), \
                            patch.object(reference.time, 'sleep') as sleep, \
                            patch.object(reference.os, 'kill') as kill, \
                            patch.object(reference.os, 'killpg') as killpg, \
                            patch.object(reference.Path, 'write_text', side_effect=OSError('unavailable')):
                        result = reference.run_renderer(self.driver_command(), Path('/unit'), io.BytesIO(), (), 100,
                            profile='normal-test', failure_evidence={'directory': '/unit/test-failure-evidence', 'image': {}})
                    self.assertEqual(result, natural_exit)
                    launch.assert_called_once()
                    self.assertEqual(sample.call_count, 2)
                    self.assertEqual(sample.call_args_list[0].kwargs, {'include_command': True})
                    self.assertEqual(sample.call_args_list[1].kwargs, {})
                    capture.observe.assert_called_once()
                    capture.finish.assert_not_called()
                    stop.assert_called_once_with(process, {987654: 'unit-start'}, 14)
                    sleep.assert_called_once_with(.1)
                    kill.assert_not_called()
                    killpg.assert_not_called()

    def test_passive_artifact_failure_does_not_replace_the_original_child_exit(self):
        process = Mock(pid=987654, returncode=None)
        def completed():
            process.returncode = 1
            return 1
        process.poll.side_effect = completed
        rows = {987654: {'parent': 0, 'group': 987654, 'start': 'unit-start',
                         'rss': 1024, 'command': '/bound/toolchain/swift test'}}
        capture = Mock(directory=Path('/unit/test-failure-evidence'))
        capture.finish.side_effect = ValueError('artifact unavailable')
        module = SimpleNamespace(PassiveFailureEvidence=Mock(return_value=capture))
        with patch.dict(sys.modules, {'passive_failure_evidence': module}), \
                patch.object(reference.subprocess, 'Popen', return_value=process), \
                patch.object(reference, 'process_memory', return_value=rows), \
                patch.object(reference, 'stop_renderer', return_value=(True, False)), \
                patch.object(reference.time, 'monotonic', return_value=10), \
                patch.object(reference.Path, 'write_text', side_effect=OSError('unavailable')):
            self.assertEqual(reference.run_renderer(self.driver_command(), Path('/unit'), io.BytesIO(), (), 100,
                profile='normal-test', failure_evidence={'directory': '/unit/test-failure-evidence', 'image': {}}), 1)

    def test_passive_collection_cannot_expand_to_compiler_asset_or_discovery_commands(self):
        for command, profile in [(self.command(), 'normal-compiler'), (self.driver_command(), 'asset'),
                                 ([self.command()[0], 'test', '--enable-code-coverage', 'list', '--skip-build'], 'normal-test')]:
            with patch.object(reference.subprocess, 'Popen') as launch, patch.object(reference, 'process_memory') as sample:
                with self.assertRaises(ValueError):
                    reference.run_renderer(command, Path('/unit'), io.BytesIO(), (), 100, profile=profile,
                                           failure_evidence={'directory': '/unit/test-failure-evidence', 'image': {}})
                launch.assert_not_called()
                sample.assert_not_called()

    def test_passive_destination_must_be_the_exact_current_report_sibling(self):
        with patch.object(reference.subprocess, 'Popen') as launch:
            with self.assertRaises(ValueError):
                reference.run_renderer(self.driver_command(), Path('/unit'), io.BytesIO(), (), 100,
                    profile='normal-test', failure_evidence={'directory': '/other/evidence', 'image': {}})
            launch.assert_not_called()

    def test_optional_full_command_metadata_preserves_rss_and_start_with_one_ps_call(self):
        raw = b'11 10 10 Tue Nov 14 22:13:20 2023 1234 /tool/helper --filter selected name\n'
        with patch.object(reference.subprocess, 'check_output', return_value=raw) as sample:
            rows = reference.process_memory(include_command=True)
        self.assertEqual(rows[11]['command'], '/tool/helper --filter selected name')
        self.assertEqual(rows[11]['start'], 'Tue Nov 14 22:13:20 2023')
        self.assertEqual(rows[11]['rss'], 1234 * 1024)
        sample.assert_called_once()
        self.assertIn('pid=,ppid=,pgid=,lstart=,rss=,command=', sample.call_args.args[0])
        self.assertIn('-ww', sample.call_args.args[0])


if __name__ == '__main__':
    unittest.main()
