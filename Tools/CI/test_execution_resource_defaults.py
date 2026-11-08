"""Uncapped execution still requires exact command, ownership and image/lifecycle proof."""
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import native_runner
import recoverable_shards as shards
from crash_artifacts import ArtifactBudget

spec = importlib.util.spec_from_file_location('uncapped_ship_reference', Path(__file__).resolve().parents[1] / 'showroom/ship-reference.py')
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


class ExecutionResourceDefaultsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(dir='/tmp')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def test_admission_has_no_resource_sample_or_threshold_even_with_legacy_zero_fields(self):
        authority = SimpleNamespace(config={'admission': dict(explicit=0,cpu_budget=0,
            ram_available=0,ram_reserve=10**30,peak_per_worker=10**30,
            disk_available=0,disk_reserve=10**30,disk_per_worker=10**30)},
            phase_profile=lambda phase: {'build_profile':'toolchain-defaults-v1','admission':{}},
            output=Mock(side_effect=AssertionError('Resource probing must not occur')))
        with patch.object(native_runner,'require_diagnostic_custody_clear') as custody:
            self.assertEqual(shards.NativeAuthority.admission(authority),{})
            self.assertEqual(shards.NativeAuthority.admission(authority,'normal'),{})
            self.assertEqual(custody.call_count,2)
        authority.output.assert_not_called()
        self.assertIsNone(shards.worker_limit(**authority.config['admission']))

    def test_custody_and_phase_authorization_still_refuse_before_admission(self):
        authority=SimpleNamespace(phase_profile=lambda phase:None)
        with patch.object(native_runner,'require_diagnostic_custody_clear'),self.assertRaises(ValueError):
            shards.NativeAuthority.admission(authority,'normal')
        with patch.object(native_runner,'require_diagnostic_custody_clear',side_effect=ValueError('unresolved custody')),self.assertRaises(ValueError):
            shards.NativeAuthority.admission(authority)

    def test_execution_wait_ignores_legacy_timeout_and_retains_real_exit_and_observer(self):
        attempt=self.root/'attempt';attempt.mkdir()
        process=Mock(pid=800,returncode=0)
        process.wait.return_value=37
        observer=Mock();observer.finish.return_value=True
        with patch.object(shards.subprocess,'Popen',return_value=process) as launch:
            code=shards.execute_process(['bound-child'],self.root,attempt,-1,(),{},observer,isolate_environment=False)
        self.assertEqual(code,37)
        process.wait.assert_called_once_with()
        observer.start.assert_called_once_with(800)
        observer.finish.assert_called_once_with(True)
        self.assertEqual(launch.call_args.kwargs['start_new_session'],True)
        self.assertEqual(json.loads((attempt/'child-exit.json').read_text())['exit_code'],37)
        self.assertFalse((attempt/'timeout.json').exists())

    def test_renderer_has_no_rss_log_or_live_deadline_ceiling_and_keeps_cleanup(self):
        command=['/bound/swift','build','--build-tests','--enable-code-coverage']
        for code in (0,23):
            process=Mock(pid=800,returncode=None)
            def poll():
                process.returncode=code
                return code
            process.poll.side_effect=poll
            log=Mock();log.tell.return_value=10**30
            rows={800:dict(parent=0,group=800,start='bound-start',rss=10**30)}
            with patch.object(reference.subprocess,'Popen',return_value=process), \
                    patch.object(reference,'process_memory',return_value=rows) as sample, \
                    patch.object(reference,'stop_renderer',return_value=(True,False)) as cleanup, \
                    patch.object(reference.time,'monotonic',return_value=10**20):
                self.assertEqual(reference.run_renderer(command,self.root,log,(),-1,profile='normal-compiler'),code)
            cleanup.assert_called_once()
            sample.assert_called_once_with(None)
            log.tell.assert_not_called()
        self.assertIsNone(reference.execution_admission_peak(command,'normal-compiler'))

    def test_uncapped_renderer_still_refuses_unauthorized_commands_before_spawn(self):
        for profile,command in [('unknown',['swift','build']),('normal-compiler',['swift','run','L337']),
                                ('normal-test',['swift','test','--skip-build']),
                                ('normal-ci',['make','ci'])]:
            with self.subTest(profile=profile,command=command),patch.object(reference.subprocess,'Popen') as launch,self.assertRaises(ValueError):
                reference.run_renderer(command,self.root,io.BytesIO(),(),None,profile=profile)
            launch.assert_not_called()

    def test_monitor_tracks_owned_identities_without_resident_budget_or_probe(self):
        attempt=self.root/'monitor';attempt.mkdir()
        rows={800:dict(parent=1,group=800,start='owned',command='/bound/python phase'),
              801:dict(parent=800,group=800,start='child',command='/bound/large-child',rss_bytes=10**30)}
        profile={'build_profile':'toolchain-defaults-v1','admission':{}}
        authority=SimpleNamespace(snapshot=Mock(return_value=rows),phase_profile=lambda phase:profile)
        monitor=shards.NativeMonitor(authority,attempt,self.root,phase='normal')
        monitor.root_identity={'pid':800,**rows[800]};monitor.known={800:rows[800]}
        observed=monitor.observe()
        self.assertEqual(set(observed),{800,801})
        self.assertIsNone(monitor.memory)
        authority.snapshot.assert_called_once_with()
        record=json.loads((attempt/'processes.json').read_text())
        self.assertEqual(record['execution_resources'],'os-toolchain-defaults-v1')
        self.assertEqual(record['phase_profile_sha256'],shards.fingerprint(profile))
        self.assertEqual(record['processes']['801']['start'],'child')

    def phase_proof(self):
        profile={'build_profile':'toolchain-defaults-v1','admission':{}}
        row=dict(parent=1,group=800,start='owned',command='bound phase')
        identity=dict(phase='normal',image_sha256='a'*64,image_uuid='UUID: AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA (arm64) /bound/image')
        origin=dict(tested_head='b'*40,authorization=dict(role='native_phase',phase='normal',head='b'*40,workspace=str(self.root)))
        value=dict(child=dict(pid=800),terminal=dict(pid=800,exit_code=0),processes=dict(running=False,
            workspace=str(self.root),root={'pid':800,**row},processes={'800':row},
            execution_resources='os-toolchain-defaults-v1',phase='normal',phase_profile_sha256=shards.fingerprint(profile),
            observed_images={'image':dict(sha256='a'*64,uuid=shards.fingerprint({'arm64':'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'}))}))
        return value,identity,profile,origin

    def test_phase_proof_needs_no_memory_ceiling_but_requires_full_identity_lifecycle(self):
        value,identity,profile,origin=self.phase_proof()
        shards.validate_phase_memory(value,identity,profile,origin)
        for field,bad in [('running',True),('workspace','/foreign'),('phase','leaks'),
                          ('phase_profile_sha256','f'*64),('execution_resources','fixed-six')]:
            changed=json.loads(json.dumps(value));changed['processes'][field]=bad
            with self.subTest(field=field),self.assertRaises(ValueError):
                shards.validate_phase_memory(changed,identity,profile,origin)
        for mutation in ('image','root','exit'):
            changed=json.loads(json.dumps(value))
            if mutation=='image':changed['processes']['observed_images']={}
            elif mutation=='root':changed['processes']['root']['start']='reused-pid'
            else:changed['terminal']['exit_code']=1
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):
                shards.validate_phase_memory(changed,identity,profile,origin)

    def test_sanitizer_modes_and_isolated_scratch_remain_without_job_or_parallel_caps(self):
        for mode,scratch in [('thread','.build/tsan'),('address','.build/asan')]:
            self.assertEqual(shards.local_sanitizer_flags(mode),['--scratch-path',scratch,'--sanitize='+mode])
            command=shards.legacy.batch_command('swift',[],mode,self.root,['Module.Suite/test()'])
            self.assertNotIn('--no-parallel',command)
            self.assertNotIn('--jobs',command)
            self.assertIn('--filter',command)

    def test_crash_retention_uses_actual_storage_without_a_project_byte_quota(self):
        budget=ArtifactBudget(limit=1)
        budget.used=10**30
        self.assertIsNone(budget.limit)
        self.assertTrue(budget.permits(10**40))
        self.assertFalse(budget.permits(-1))

    def test_actual_make_and_workflow_entrypoints_do_not_reapply_resource_caps(self):
        root=Path(__file__).resolve().parents[2]
        make=(root/'Makefile').read_text()
        for token in ['--jobs','-disable-batch-mode','--no-parallel']:
            self.assertNotIn(token,make)
        self.assertIn('--sanitize=thread',make)
        self.assertIn('--sanitize=address',make)
        self.assertIn('--validate-mission-pack',make)
        for path in (root/'.github/workflows').glob('*.yml'):
            self.assertNotIn('timeout-minutes:',path.read_text())
            self.assertNotIn('max-parallel:',path.read_text())


if __name__=='__main__':
    unittest.main()
