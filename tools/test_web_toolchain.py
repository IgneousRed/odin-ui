"""Check locked web artifacts and reject host-tool fallback."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class WebToolchainTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(dir='.work')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.script = self.root / 'web-toolchain.sh'
        shutil.copyfile('scripts/web-toolchain.sh', self.script)
        self.compiler = self.root / 'compiler with spaces'
        self.compiler.write_text('#!/bin/sh\nexit 0\n')
        self.compiler.chmod(0o755)
        self.archive = self.root / 'archive with spaces.a'
        self.archive.write_bytes(b'fixture')
        self.environment = {key: value for key, value in os.environ.items()
                            if not key.startswith(('EM', 'RAYLIB_', 'PROJECT_'))}
        self.environment.update(PROJECT_ROOT=str(self.root), PROJECT_NIX_ENVIRONMENT=str(self.root),
                                EMCC=str(self.compiler), RAYLIB_WEB_LIB=str(self.archive))

    def resolve(self, **overrides):
        return subprocess.run(['/bin/sh', '-eu', '-c', '. "$1"', 'resolve', str(self.script)],
                              env={**self.environment, **overrides}, text=True, capture_output=True)

    def test_uses_the_supplied_locked_compiler_and_archive(self):
        self.assertEqual(self.resolve().returncode, 0)

    def test_requires_project_environment_without_falling_back_to_host_tools(self):
        result = self.resolve(PROJECT_NIX_ENVIRONMENT='')
        self.assertEqual(result.returncode, 2)
        self.assertIn('scripts/dev', result.stderr)

    def test_missing_locked_inputs_fail_instead_of_installing_replacements(self):
        for overrides in [{'EMCC': ''}, {'RAYLIB_WEB_LIB': ''},
                          {'EMCC': str(self.root / 'absent')},
                          {'RAYLIB_WEB_LIB': str(self.root / 'absent')}]:
            with self.subTest(overrides=overrides):
                self.assertEqual(self.resolve(**overrides).returncode, 2)


if __name__ == '__main__':
    unittest.main()
