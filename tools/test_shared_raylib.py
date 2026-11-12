"""Exercise shared-cache invalidation, publication, integrity and build locking."""
from concurrent.futures import ThreadPoolExecutor
import io
import json
from pathlib import Path
import tarfile
import tempfile
import time
import unittest

import shared_raylib as shared


class SharedRaylibTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.pool = Path(self.temporary.name)
        self.spec = {'raylib_version': '6.2.0', 'emscripten_version': '6.0.13',
                     'raylib_keg': '/brew/raylib/6.2', 'emscripten_keg': '/brew/emscripten/6.0.13',
                     'recipe_sha256': 'recipe-1', 'make_flags': list(shared.MAKE_FLAGS)}
        self.builds = 0

    def build(self, spec, stage, pool):
        self.builds += 1
        (stage / shared.LIBRARY).parent.mkdir()
        (stage / shared.LIBRARY).write_bytes(b'archive ' + spec['emscripten_version'].encode())
        (stage / 'LICENSE').write_text('raylib license')

    def test_reuses_verified_build_without_compiling_again(self):
        first = shared.ensure_library(self.pool, self.spec, self.build)
        self.assertEqual(shared.ensure_library(self.pool, self.spec, self.build), first)
        self.assertEqual(self.builds, 1)
        self.assertEqual(json.loads((first / 'build.json').read_text())['toolchain'], self.spec)

    def test_raylib_compiler_and_recipe_updates_each_build_a_new_copy(self):
        original = shared.ensure_library(self.pool, self.spec, self.build)
        for field, value in [('raylib_version', '6.3.0'), ('emscripten_version', '6.0.14'),
                             ('emscripten_keg', '/brew/emscripten/6.0.13_1'),
                             ('recipe_sha256', 'recipe-2')]:
            with self.subTest(field=field):
                changed = {**self.spec, field: value}
                directory = shared.ensure_library(self.pool, changed, self.build)
                self.assertNotEqual(directory, original)
                self.assertTrue(shared.ready(directory, changed))
                self.assertTrue(shared.ready(original, self.spec))
        self.assertEqual(self.builds, 5)

    def test_failed_update_preserves_previous_build_and_publishes_nothing(self):
        original = shared.ensure_library(self.pool, self.spec, self.build)
        changed = {**self.spec, 'emscripten_version': '6.0.14'}

        def fail(spec, stage, pool):
            self.build(spec, stage, pool)
            raise RuntimeError('compiler failed')

        with self.assertRaisesRegex(RuntimeError, 'compiler failed'):
            shared.ensure_library(self.pool, changed, fail)
        self.assertTrue(shared.ready(original, self.spec))
        self.assertFalse((self.pool / shared.build_id(changed)).exists())
        self.assertEqual(list(self.pool.glob('.publish-*')), [])
        self.assertTrue(shared.ready(shared.ensure_library(self.pool, changed, self.build), changed))

    def test_corrupt_or_incomplete_artifact_is_rebuilt(self):
        directory = shared.ensure_library(self.pool, self.spec, self.build)
        (directory / shared.LIBRARY).write_bytes(b'corrupt')
        self.assertFalse(shared.ready(directory, self.spec))
        shared.ensure_library(self.pool, self.spec, self.build)
        self.assertTrue(shared.ready(directory, self.spec))
        (directory / 'LICENSE').unlink()
        shared.ensure_library(self.pool, self.spec, self.build)
        self.assertTrue(shared.ready(directory, self.spec))
        self.assertEqual(self.builds, 3)

    def test_malformed_record_is_rebuilt(self):
        directory = shared.ensure_library(self.pool, self.spec, self.build)
        for record in [[], None, {'toolchain': self.spec}]:
            with self.subTest(record=record):
                (directory / 'build.json').write_text(json.dumps(record))
                self.assertFalse(shared.ready(directory, self.spec))
                self.assertEqual(shared.ensure_library(self.pool, self.spec, self.build), directory)
                self.assertTrue(shared.ready(directory, self.spec))
        self.assertEqual(self.builds, 4)

    def test_concurrent_projects_compile_only_once(self):
        def slow_build(spec, stage, pool):
            time.sleep(0.1)
            self.build(spec, stage, pool)

        with ThreadPoolExecutor(max_workers=4) as executor:
            results = list(executor.map(lambda _: shared.ensure_library(self.pool, self.spec, slow_build), range(4)))
        self.assertEqual(len(set(results)), 1)
        self.assertEqual(self.builds, 1)

    def test_source_archive_rejects_path_traversal_and_links(self):
        for name, kind in [('../outside', tarfile.REGTYPE), ('/absolute', tarfile.REGTYPE),
                           ('raylib/link', tarfile.SYMTYPE)]:
            with self.subTest(name=name):
                archive = self.pool / 'bad.tar.gz'
                with tarfile.open(archive, 'w:gz') as output:
                    member = tarfile.TarInfo(name)
                    member.type = kind
                    output.addfile(member, io.BytesIO())
                with self.assertRaisesRegex(RuntimeError, 'Unsafe entry'):
                    shared.extract_source(archive, self.pool / 'extracted')


if __name__ == '__main__':
    unittest.main()
