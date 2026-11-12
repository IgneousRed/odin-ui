"""Check explicit SDK/archive builds without depending on this machine's Homebrew."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class WebToolchainTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(dir='.work')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        (self.root / 'scripts').mkdir()
        (self.root / 'bin').mkdir()
        for name in ['emscripten.sh', 'web-toolchain.sh']:
            shutil.copyfile(Path('scripts') / name, self.root / 'scripts' / name)
        self.environment = {key: value for key, value in os.environ.items()
                            if not key.startswith(('EM', 'RAYLIB_'))}
        self.environment['PATH'] = str(self.root / 'bin') + ':/usr/bin:/bin'
        self.executable('emcc', '#!/bin/sh\nexit 0\n')
        self.archive = self.root / 'raylib with spaces.a'
        self.archive.write_bytes(b'fixture')
        # An explicit build must never consult Homebrew or the shared resolver.
        self.executable('brew', '#!/bin/sh\necho "unexpected Homebrew lookup" >&2\nexit 99\n')

    def executable(self, name, value):
        path = self.root / 'bin' / name
        path.write_text(value)
        path.chmod(0o755)
        return path

    def resolve(self, **overrides):
        return subprocess.run(['/bin/sh', '-eu', '-c',
                               '. ./scripts/web-toolchain.sh\n'
                               'printf "%s\\n%s\\n" "$RAYLIB_WEB_LIB" "$EMCC"'],
                              cwd=self.root, env={**self.environment, **overrides},
                              text=True, capture_output=True)

    def test_explicit_archive_uses_active_compiler_without_homebrew(self):
        result = self.resolve(RAYLIB_WEB_LIB=str(self.archive))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [str(self.archive), 'emcc'])

    def test_explicit_sdk_is_activated_before_linking(self):
        sdk = self.root / 'sdk with spaces'
        sdk.mkdir()
        compiler = self.executable('custom-emcc', '#!/bin/sh\nexit 0\n')
        (sdk / 'emsdk_env.sh').write_text('EMCC="$EMSDK/../bin/custom-emcc"\n')
        result = self.resolve(EMSDK=str(sdk), RAYLIB_WEB_LIB=str(self.archive))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(result.stdout.splitlines()[1]).resolve(), compiler)

    def test_explicit_compiler_requires_its_own_archive(self):
        result = self.resolve(EMCC='emcc')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Set RAYLIB_WEB_LIB', result.stderr)

    def test_missing_archive_and_sdk_fail_with_actionable_errors(self):
        for overrides, message in [
                ({'RAYLIB_WEB_LIB': str(self.root / 'absent.a')}, 'archive missing'),
                ({'RAYLIB_WEB_LIB': str(self.archive), 'EMSDK': str(self.root / 'absent')},
                 'EMSDK must name an installed SDK')]:
            with self.subTest(overrides=overrides):
                result = self.resolve(**overrides)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)

    def test_default_homebrew_path_uses_shared_archive_and_canonical_compiler(self):
        for directory in ['emscripten/bin', 'node/bin', 'shared/lib', 'tools']:
            (self.root / directory).mkdir(parents=True)
        shutil.copyfile(self.root / 'bin/emcc', self.root / 'emscripten/bin/emcc')
        (self.root / 'emscripten/bin/emcc').chmod(0o755)
        (self.root / 'shared/lib/libraylib.web.a').write_bytes(b'fixture')
        self.executable('brew', '#!/bin/sh\nprintf "%s/%s\\n" "$PWD" "$2"\n')
        (self.root / 'bin/python3').symlink_to(sys.executable)
        (self.root / 'tools/shared_raylib.py').write_text(
            'from pathlib import Path\nprint(Path.cwd() / "shared")\n')
        result = self.resolve()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines()[0], str(self.root / 'shared/lib/libraylib.web.a'))


if __name__ == '__main__':
    unittest.main()
