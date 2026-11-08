"""Dependency regressions for individual TOML media and complete runtime data."""
import importlib.util
import hashlib
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
import tomllib

spec=importlib.util.spec_from_file_location('ship_reference',Path(__file__).with_name('ship-reference.py'))
reference=importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


class ShipReferenceTests(unittest.TestCase):
    def render_root(self, root):
        for name in reference.RENDER_FILES:
            path = root/name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'unchanged renderer')
        (root/'Sources/L337Core/Game.swift').write_text(
            '// unrelated mission before\n' + reference.VIEW_START
            + '    return p\n  }\n' + reference.VIEW_END + '// unrelated mission after\n')

    def test_each_declared_renderer_dependency_invalidates_and_missing_files_fail_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.render_root(root)
            original = reference.shared_hash(root)
            for name in reference.RENDER_FILES:
                with self.subTest(dependency=name):
                    path = root/name
                    before = path.read_bytes()
                    path.write_bytes(before + b'changed')
                    self.assertNotEqual(reference.shared_hash(root), original)
                    path.unlink()
                    with self.assertRaises(FileNotFoundError):
                        reference.shared_hash(root)
                    path.write_bytes(before)
                    self.assertEqual(reference.shared_hash(root), original)

    def test_unrelated_mission_custody_and_game_methods_do_not_invalidate_portraits(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.render_root(root)
            original = reference.shared_hash(root)
            for name in ['NativeSafeGunneryRuntime.swift', 'NativeIsolationProgrammerCustody.swift',
                         'NativeWayfarerInductionCrewLogSave.swift']:
                path = root/'Sources/L337Core'/name
                path.write_bytes(b'new mission')
                self.assertEqual(reference.shared_hash(root), original)
                path.write_bytes(b'changed custody')
                self.assertEqual(reference.shared_hash(root), original)
                path.unlink()
                self.assertEqual(reference.shared_hash(root), original)
            game = root/'Sources/L337Core/Game.swift'
            game.write_text(game.read_text().replace('unrelated mission', 'new service state'))
            self.assertEqual(reference.shared_hash(root), original)

    def test_actual_view_transform_invalidates_and_moved_or_ambiguous_boundary_fails_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.render_root(root)
            path = root/'Sources/L337Core/Game.swift'
            source = path.read_text()
            original = reference.shared_hash(root)
            path.write_text(source.replace('return p', 'return p * 2'))
            self.assertNotEqual(reference.shared_hash(root), original)
            for text in [source.replace(reference.VIEW_START, ''),
                         source.replace(reference.VIEW_END, ''),
                         source + reference.VIEW_START,
                         reference.VIEW_END + source.replace(reference.VIEW_END, '')]:
                path.write_text(text)
                with self.assertRaises(ValueError):
                    reference.shared_hash(root)

    def test_settings_and_relative_dependency_identity_are_content_based(self):
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            first, second = Path(a), Path(b)
            self.render_root(first)
            self.render_root(second)
            original = reference.shared_hash(first)
            self.assertEqual(reference.shared_hash(second), original)
            (first/reference.RENDER_FILES[0]).touch()
            self.assertEqual(reference.shared_hash(first), original)
            with patch.object(reference, 'SETTINGS', reference.SETTINGS + b':new-frame-rate'):
                self.assertNotEqual(reference.shared_hash(first), original)

    def test_both_texture_trees_track_pixels_manifests_notices_and_renamed_or_deleted_inputs(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            self.render_root(root)
            for directory in reference.TEXTURE_FOLDERS:
                textures = root/directory
                before_empty = reference.shared_hash(root)
                textures.mkdir(parents=True)
                self.assertEqual(reference.shared_hash(root), before_empty)
                for name in ['diffuse.png', 'diffuse.rgba', 'manifest.json', 'NOTICE.md']:
                    with self.subTest(folder=directory, dependency=name):
                        before = reference.shared_hash(root)
                        path = textures/name
                        path.write_bytes(b'original bytes')
                        added = reference.shared_hash(root)
                        self.assertNotEqual(added, before)
                        path.write_bytes(b'changed bytes')
                        changed = reference.shared_hash(root)
                        self.assertNotEqual(changed, added)
                        renamed = path.with_name('renamed-' + name)
                        path.rename(renamed)
                        self.assertNotEqual(reference.shared_hash(root), changed)
                        renamed.unlink()
                        self.assertEqual(reference.shared_hash(root), before)

    def test_content_dependencies_and_unchanged_reuse(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);spec_a=root/'SH001.toml';spec_b=root/'SH002.toml';gif=root/'SH001.gif'
            spec_a.write_text('name = "Adder"\n');spec_b.write_text('name = "Other"\n');gif.write_bytes(b'GIF89a')
            previous={'input':reference.fingerprint(spec_a.read_bytes(),'renderer1'),'output':reference.digest(gif.read_bytes())}
            self.assertFalse(reference.needs_render(reference.fingerprint(spec_a.read_bytes(), 'renderer1'), previous, gif))
            spec_b.write_text('name = "Changed other ship"\n')
            self.assertFalse(reference.needs_render(reference.fingerprint(spec_a.read_bytes(), 'renderer1'), previous, gif))
            spec_a.write_text('name = "Adder"\n[game]\nspeed = 99\n')
            self.assertTrue(reference.needs_render(reference.fingerprint(spec_a.read_bytes(), 'renderer1'), previous, gif))
            previous['input']=reference.fingerprint(spec_a.read_bytes(),'renderer1')
            spec_a.write_text(spec_a.read_text()+'[design]\nvertices = [[1,2,3]]\n')
            self.assertTrue(reference.needs_render(reference.fingerprint(spec_a.read_bytes(), 'renderer1'), previous, gif))
            previous['input']=reference.fingerprint(spec_a.read_bytes(),'renderer1')
            self.assertTrue(reference.needs_render(reference.fingerprint(spec_a.read_bytes(), 'renderer2'), previous, gif))
            gif.write_bytes(b'corrupted')
            self.assertTrue(reference.needs_render(reference.fingerprint(spec_a.read_bytes(), 'renderer1'), previous, gif))
            gif.unlink()
            self.assertTrue(reference.needs_render(reference.fingerprint(spec_a.read_bytes(), 'renderer1'), previous, gif))

    def test_renderer_publication_refuses_drift_or_incomplete_output(self):
        for drift in (False, True):
            with self.subTest(drift=drift), tempfile.TemporaryDirectory() as directory:
                media = Path(directory)
                manifest = media / 'manifest.json'
                manifest.write_text('{}')
                (media / 'SH005.gif').write_bytes(b'old GIF')
                (media / 'overview.png').write_bytes(b'old overview')
                staged = media / 'staged'
                staged.mkdir()
                steps = []

                def plan():
                    steps.append('plan')
                    return {'SH005': 'before'}

                def render(ids):
                    steps.append('render')
                    self.assertEqual(ids, ['SH005'])
                    (staged / 'SH005.gif').write_bytes(b'new GIF')
                    if drift:
                        (staged / 'overview.png').write_bytes(b'new overview')
                    return staged

                def scan():
                    steps.append('scan')
                    return [], {'SH005': 'changed' if drift else 'before'}

                with patch.object(reference, 'MEDIA', media), \
                        patch.object(reference.sys, 'argv', ['ship-reference.py']), \
                        patch.object(reference, 'isolated_media_plan', side_effect=plan), \
                        patch.object(reference, 'render_media', side_effect=render), \
                        patch.object(reference, 'scan_media_inputs', side_effect=scan), \
                        patch.object(reference, 'references') as references:
                    error = 'inputs changed after planning' if drift else 'every staged output'
                    with self.assertRaisesRegex(RuntimeError, error):
                        reference.main()
                self.assertEqual(steps, ['plan', 'render', 'scan'])
                self.assertEqual(manifest.read_text(), '{}')
                self.assertEqual((media / 'SH005.gif').read_bytes(), b'old GIF')
                self.assertEqual((media / 'overview.png').read_bytes(), b'old overview')
                references.assert_not_called()

    def test_destination_or_reused_output_failure_preserves_all_staged_destinations(self):
        for invalid_destination in (False, True):
            with self.subTest(invalid_destination=invalid_destination), tempfile.TemporaryDirectory() as directory:
                media = Path(directory)
                manifest = media / 'manifest.json'
                manifest.write_text('{}')
                old = media / 'SH005.gif'
                old.write_bytes(b'old GIF')
                if invalid_destination:
                    (media / 'overview.png').mkdir()
                staged = media / 'staged'
                staged.mkdir()
                (staged / 'SH005.gif').write_bytes(b'new GIF')
                (staged / 'overview.png').write_bytes(b'new overview')
                inputs = {'SH005': 'input-5', 'SH058': 'input-58'}

                with patch.object(reference, 'MEDIA', media), \
                        patch.object(reference.sys, 'argv', ['ship-reference.py']), \
                        patch.object(reference, 'isolated_media_plan', return_value=inputs), \
                        patch.object(reference, 'pending_media', return_value=['SH005']), \
                        patch.object(reference, 'render_media', return_value=staged), \
                        patch.object(reference, 'scan_media_inputs', return_value=([], inputs)), \
                        patch.object(reference, 'references') as references:
                    error = RuntimeError if invalid_destination else FileNotFoundError
                    with self.assertRaises(error):
                        reference.main()
                self.assertEqual(old.read_bytes(), b'old GIF')
                self.assertEqual(manifest.read_text(), '{}')
                self.assertEqual((staged / 'SH005.gif').read_bytes(), b'new GIF')
                references.assert_not_called()

    def test_all_runtime_definitions_include_geometry_and_preserve_source_profiles(self):
        ships=reference.ship_files.read_ships()
        self.assertEqual(len(ships),171)
        self.assertEqual(sum('game' in ship for ship in ships), 163)
        reference.ship_files.fleet_source_contract.require_current_fleet(ships)
        bison = next(ship for ship in ships if ship['id'] == 'SH005')
        self.assertEqual(bison['catalogue']['family'], 'bison')
        originals=[]
        for ship in ships:
            design=ship['design'];vertices=design['vertices']
            self.assertTrue(all(len(p)==3 for p in vertices))
            self.assertTrue(all(len(f)>=3 and all(0<=v<len(vertices) for v in f) for f in design['faces']))
            self.assertTrue(design['license'] and ship['profiles'])
            if 'recipe' in design:
                # Normalised coordinate ratios must differ, beyond merely scaling a generic box.
                spans=[max(p[i] for p in vertices)-min(p[i] for p in vertices) for i in range(3)]
                originals.append(reference.digest(str([[round(p[i]/spans[i],5) for i in range(3)] for p in vertices]).encode()))
        self.assertEqual(len(originals),len(set(originals)))


if __name__=='__main__':unittest.main()
