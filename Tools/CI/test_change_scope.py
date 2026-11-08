"""Offline Git and workflow contracts; no Swift, runner, network or game execution."""
import json
import os
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

import change_scope as scope

ROOT = Path(__file__).resolve().parents[2]


def bootstrap(name='ci.yml'):
    source = (ROOT / '.github/workflows' / name).read_text()
    return source.split("          python3 - <<'PY'\n", 1)[1].split('          PY\n', 1)[0].replace('\n          ', '\n').removeprefix('          ')


class ChangeScopeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.repo = Path(self.directory.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Scope Test')
        self.git('config', 'user.email', 'scope@example.invalid')
        self.write('README.md', b'# Game\n\n## Build and run\n')
        self.write('Tools/CI/change_scope.py', (ROOT / 'Tools/CI/change_scope.py').read_bytes())
        self.write('docs/meridian/story.md', b'Original story\n')
        self.base = self.commit()

    def git(self, *args):
        return subprocess.check_output(['git', '-c', 'core.hooksPath=/dev/null', *args], cwd=self.repo, stderr=subprocess.DEVNULL).decode().strip()

    def write(self, name, value=b'changed\n'):
        p = self.repo / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(value)

    def commit(self):
        self.git('add', '-A')
        self.git('commit', '-qm', 'test: record controlled paths')
        return self.git('rev-parse', 'HEAD')

    def event(self, head=None, base=None, name='pull_request'):
        head, base = head or self.git('rev-parse', 'HEAD'), base or self.base
        return {'pull_request': {'base': {'sha': base}, 'head': {'sha': head}}} if name == 'pull_request' else {'before': base, 'after': head}

    def needed(self, head=None, base=None, name='pull_request'):
        return scope.requires_build(self.repo, name, self.event(head, base, name))

    def test_documentation_images_definitions_and_unusual_names_skip_both_event_builds(self):
        for p in ('story.md', 'missions/definition.toml', 'assets/image.png', 'spaces and\nnewlines.md', 'évidence.md'):
            self.write('docs/meridian/' + p)
        head = self.commit()
        self.assertFalse(self.needed(head))
        self.assertFalse(self.needed(head, name='push'))

    def test_every_non_meridian_build_input_requires_the_build(self):
        for path in ('Sources/game.swift', 'Tests/game.swift', 'Makefile', 'Package.swift', 'Package.resolved',
                     '.github/workflows/ci.yml', 'Tools/CI/change_scope.py', 'docs/meridian-lookalike/a.md',
                     'config/flight-controls.json', 'docs/OTHER.md', 'README.md'):
            with self.subTest(path=path):
                self.git('reset', '--hard', self.base)
                self.git('clean', '-fdq')
                self.write(path)
                self.assertTrue(self.needed(self.commit()))

    def test_mixed_documentation_and_code_requires_full_checks(self):
        self.write('docs/meridian/story.md')
        self.write('Sources/game.swift')
        self.assertTrue(self.needed(self.commit()))

    def test_documentation_deletion_is_documentation(self):
        (self.repo / 'docs/meridian/story.md').unlink()
        self.assertFalse(self.needed(self.commit()))

    def test_renames_into_and_out_of_meridian_retain_full_checks(self):
        self.write('Sources/ship.swift')
        start = self.commit()
        self.git('mv', 'Sources/ship.swift', 'docs/meridian/ship.swift')
        moved = self.commit()
        self.assertTrue(self.needed(moved, start))
        self.git('mv', 'docs/meridian/ship.swift', 'Sources/ship.swift')
        self.assertTrue(self.needed(self.commit(), moved))

    def test_rename_within_meridian_can_skip(self):
        self.git('mv', 'docs/meridian/story.md', 'docs/meridian/renamed.md')
        self.assertFalse(self.needed(self.commit()))

    def test_empty_unknown_manual_zero_and_missing_history_require_full_checks(self):
        self.assertTrue(self.needed())
        for name, event in [('workflow_dispatch', {}), ('unknown', {}), ('pull_request', {}),
                            ('push', {'before': '0' * 40, 'after': self.base}),
                            ('push', {'before': 'f' * 40, 'after': self.base}),
                            ('push', {'before': '--help', 'after': self.base}),
                            ('push', {'before': None, 'after': self.base})]:
            with self.subTest(name=name, event=event):
                self.assertTrue(scope.requires_build(self.repo, name, event))

    def test_git_failure_timeout_and_truncated_path_stream_require_full_checks(self):
        self.write('docs/meridian/story.md')
        self.commit()
        for failure in (OSError('missing git'), subprocess.TimeoutExpired('git', 30),
                        subprocess.CalledProcessError(1, 'git')):
            with self.subTest(failure=type(failure).__name__), patch.object(scope, 'git', side_effect=failure):
                self.assertTrue(self.needed(name='push'))
        with patch.object(scope, 'git', return_value=b'docs/meridian/incomplete.md'):
            self.assertTrue(self.needed(name='push'))

    def test_pr_compares_entire_branch_not_only_last_commit(self):
        self.write('Sources/game.swift')
        self.commit()
        self.write('docs/meridian/story.md')
        self.assertTrue(self.needed(self.commit()))

    def test_pr_merge_base_excludes_unrelated_new_main_code(self):
        self.write('docs/meridian/story.md')
        head = self.commit()
        self.git('checkout', '--detach', self.base)
        self.write('Sources/unrelated-main.swift')
        advanced_base = self.commit()
        self.assertFalse(self.needed(head, advanced_base))

    def test_exact_readme_story_link_companion_skips_but_other_edits_do_not(self):
        original = (self.repo / 'README.md').read_bytes()
        after = original.replace(b'## Build and run', scope.STORY_LINK + b'## Build and run')
        self.write('README.md', after)
        self.write('docs/meridian/story.md')
        self.assertFalse(self.needed(self.commit()))
        self.write('README.md', after + b'Other change\n')
        self.assertTrue(self.needed(self.commit()))

    def execute_bootstrap(self, event=None, name='pull_request'):
        path = self.repo / '.git/event.json'
        path.write_text(json.dumps(event or self.event()))
        output = self.repo / '.git/output'
        output.unlink(missing_ok=True)
        env = dict(os.environ, GITHUB_EVENT_PATH=str(path), GITHUB_EVENT_NAME=name, GITHUB_OUTPUT=str(output))
        subprocess.run(['python3', '-I', '-c', bootstrap()], cwd=self.repo, env=env, check=True, capture_output=True, timeout=10)
        return output.read_text()

    def test_bootstrap_uses_trusted_base_not_modified_pr_classifier(self):
        self.write('Tools/CI/change_scope.py', b"print('false')\n")
        self.write('Sources/game.swift')
        self.commit()
        self.assertEqual(self.execute_bootstrap(), 'requires_build=true\n')

    def test_bootstrap_documentation_skip_and_first_install_missing_base_default(self):
        self.write('docs/meridian/story.md')
        self.commit()
        self.assertEqual(self.execute_bootstrap(), 'requires_build=false\n')
        self.git('rm', 'Tools/CI/change_scope.py')
        before = self.commit()
        self.write('docs/meridian/story.md', b'next\n')
        self.commit()
        self.assertEqual(self.execute_bootstrap(self.event(base=before)), 'requires_build=true\n')

    def test_workflows_share_classifier_and_full_build_condition(self):
        ci = (ROOT / '.github/workflows/ci.yml').read_text()
        units = (ROOT / '.github/workflows/unit-tests.yml').read_text()
        self.assertEqual(bootstrap(), bootstrap('unit-tests.yml'))
        condition = "if: ${{ !cancelled() && (needs.scope.result != 'success' || needs.scope.outputs.requires_build != 'false') }}"
        for source in (ci, units):
            self.assertIn(condition, source)
            self.assertIn('fetch-depth: 0', source)
            self.assertNotIn('paths-ignore:', source)
        self.assertIn('name: quality', ci)
        self.assertIn('needs: [scope, phases]', ci)
        self.assertIn('enable_native: true', ci)
        self.assertIn('run: make unit-ci', units)
        self.assertNotIn('    paths:', units)
        self.assertIn('\nci: change-scope-check ', (ROOT / 'Makefile').read_text())

    def test_required_quality_never_converts_failed_native_or_classifier_into_pass(self):
        source = (ROOT / '.github/workflows/ci.yml').read_text()
        script = source.split('      - name: Require all native and prerequisite results\n', 1)[1].split('        run: |\n', 1)[1]
        script = '\n'.join(line[10:] for line in script.splitlines())
        for route, component, result, passed in [
                ('false', 'skipped', 'success', True), ('true', 'success', 'success', True),
                ('true', 'failure', 'success', False), ('true', 'skipped', 'success', False),
                ('false', 'failure', 'success', False), ('false', 'success', 'success', False),
                ('false', 'skipped', 'failure', False), ('', 'skipped', 'success', False),
                ('true', 'cancelled', 'success', False)]:
            with self.subTest(route=route, component=component, result=result):
                output = self.repo / '.git/summary'
                env = dict(os.environ, SCOPE=result, REQUIRES_BUILD=route, COMPONENTS=component, GITHUB_STEP_SUMMARY=str(output))
                run = subprocess.run(['bash', '-e', '-c', script], env=env, capture_output=True)
                self.assertEqual(run.returncode == 0, passed)
                if passed and route == 'false':
                    self.assertIn('no game build', output.read_text())


if __name__ == '__main__':
    unittest.main()
