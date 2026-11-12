#!/usr/bin/env python3
"""Resolve one verified WebAssembly raylib build for the installed Homebrew tools."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile

MAKE_FLAGS = ['PLATFORM=PLATFORM_WEB', 'RAYLIB_LIBTYPE=STATIC',
              'GRAPHICS=GRAPHICS_API_OPENGL_ES2']
LIBRARY = Path('lib/libraylib.web.a')


def digest(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def capture(arguments, **kwargs):
    return subprocess.check_output(arguments, text=True, **kwargs).strip()


def compiler_environment(emscripten, node):
    environment = os.environ.copy()
    for variable in ['CC', 'CXX', 'AR', 'CFLAGS', 'CXXFLAGS', 'LDFLAGS', 'MAKEFLAGS',
                     'EMCC_CFLAGS', 'EMMAKEN_CFLAGS', 'EMSDK', 'EMSDK_NODE', 'EMSDK_PYTHON', 'EM_CONFIG']:
        environment.pop(variable, None)
    for variable in list(environment):
        if variable.startswith('RAYLIB_'):
            environment.pop(variable)
    environment.update(PATH=str(emscripten / 'bin') + ':' + str(node / 'bin') + ':' + environment['PATH'],
                       EM_CONFIG=str(emscripten / 'libexec/.emscripten'),
                       EM_LLVM_ROOT=str(emscripten / 'libexec/llvm/bin'),
                       EM_BINARYEN_ROOT=str(emscripten / 'libexec/binaryen'),
                       EM_NODE_JS=str(node / 'bin/node'))
    return environment


def toolchain(odin):
    prefixes = capture(['brew', '--prefix', 'raylib', 'emscripten', 'node']).splitlines()
    raylib, emscripten, node = [Path(p).resolve(strict=True) for p in prefixes]
    # Use the installed formula snapshot, not potentially newer registry metadata.
    formula = (raylib / '.brew/raylib.rb').read_text()
    url = re.search(r'^  url "([^"]+)"', formula, re.M)
    checksum = re.search(r'^  sha256 "([0-9a-f]{64})"', formula, re.M)
    if not url or not checksum:
        raise RuntimeError('The installed Homebrew raylib must have a stable source URL and SHA-256.')
    header = (raylib / 'include/raylib.h').read_text()
    raylib_version = tuple(int(re.search(r'#define RAYLIB_VERSION_' + part + r'\s+(\d+)', header)[1])
                           for part in ['MAJOR', 'MINOR', 'PATCH'])
    odin_root = Path(capture([odin, 'root']))
    bindings = (odin_root / 'vendor/raylib/raylib.odin').read_text()
    binding_version = tuple(int(re.search(r'^VERSION_' + part + r'\s*::\s*(\d+)', bindings, re.M)[1])
                            for part in ['MAJOR', 'MINOR', 'PATCH'])
    if binding_version[:2] != raylib_version[:2]:
        raise RuntimeError(f'Odin raylib bindings {binding_version} do not match Homebrew raylib '
                           f'{raylib_version}; update Odin and raylib together.')
    version = capture([str(emscripten / 'bin/emcc'), '-dumpversion'],
                      env=compiler_environment(emscripten, node)).removesuffix('-git')
    return {'raylib_version': '.'.join(map(str, raylib_version)),
            'raylib_keg': str(raylib), 'emscripten_version': version,
            'emscripten_keg': str(emscripten), 'node_keg': str(node),
            'source_url': url[1], 'source_sha256': checksum[1],
            'host': [sys.platform, platform.machine()], 'make_flags': MAKE_FLAGS,
            'recipe_sha256': digest(__file__)}


def build_id(spec):
    return hashlib.sha256(json.dumps(spec, sort_keys=True).encode()).hexdigest()[:24]


def ready(directory, spec):
    try:
        record = json.loads((directory / 'build.json').read_text())
        return (record['toolchain'] == spec and (directory / 'LICENSE').is_file()
                and digest(directory / LIBRARY) == record['library_sha256'])
    except (OSError, ValueError, KeyError, TypeError):
        return False


def source_archive(pool, spec):
    archives = pool / 'sources'
    archives.mkdir(exist_ok=True)
    archive = archives / (spec['source_sha256'] + '.tar.gz')
    if archive.exists() and digest(archive) == spec['source_sha256']:
        return archive
    # Source downloads have their own lock, since different compiler versions
    # can build the same raylib release concurrently.
    with (archives / (spec['source_sha256'] + '.lock')).open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if archive.exists() and digest(archive) == spec['source_sha256']:
            return archive
        descriptor, name = tempfile.mkstemp(dir=archives, prefix='.download-')
        os.close(descriptor)
        temporary = Path(name)
        try:
            subprocess.run(['curl', '--fail', '--location', '--retry', '2',
                            '--output', str(temporary), spec['source_url']],
                           check=True, stdout=sys.stderr)
            if digest(temporary) != spec['source_sha256']:
                raise RuntimeError('raylib source checksum does not match the installed Homebrew formula.')
            os.replace(temporary, archive)
        finally:
            temporary.unlink(missing_ok=True)
    return archive


def extract_source(archive, destination):
    with tarfile.open(archive) as source:
        members = source.getmembers()
        for member in members:
            relative = Path(member.name)
            if relative.is_absolute() or '..' in relative.parts or not (member.isfile() or member.isdir()):
                raise RuntimeError('Unsafe entry in raylib source archive: ' + member.name)
        source.extractall(destination, members=members)
    roots = list(destination.iterdir())
    if len(roots) != 1 or not (roots[0] / 'src/Makefile').is_file():
        raise RuntimeError('Unexpected raylib source archive layout.')
    return roots[0]


def compile_library(spec, stage, pool):
    emscripten = Path(spec['emscripten_keg'])
    node = Path(spec['node_keg']) / 'bin/node'
    environment = compiler_environment(emscripten, node.parent.parent)
    with tempfile.TemporaryDirectory(prefix='.compile-', dir=pool) as work:
        work = Path(work)
        source = extract_source(source_archive(pool, spec), work)
        subprocess.run(['make', '-C', str(source / 'src'), '-j4', *spec['make_flags']],
                       env=environment, check=True, stdout=sys.stderr)
        (stage / LIBRARY).parent.mkdir()
        shutil.copy2(source / 'src/libraylib.web.a', stage / LIBRARY)
        shutil.copy2(source / 'LICENSE', stage / 'LICENSE')
        # Check the archive's target and required imports before publishing it.
        smoke = work / 'smoke.c'
        smoke.write_text('#include "raylib.h"\nint main(void) { return GetRandomValue(1, 1) != 1; }\n')
        subprocess.run([str(emscripten / 'bin/emcc'), str(smoke), '-I' + str(source / 'src'),
                        str(stage / LIBRARY), '-sUSE_GLFW=3', '-sENVIRONMENT=node',
                        '-sEXIT_RUNTIME=1', '-o', str(work / 'smoke.js')],
                       env=environment, check=True, stdout=sys.stderr)
        subprocess.run([str(node), str(work / 'smoke.js')], env=environment,
                       check=True, stdout=sys.stderr)
    # Homebrew can change an opt symlink during a build. Never publish a mixed build.
    for name in ['raylib', 'emscripten', 'node']:
        if Path(capture(['brew', '--prefix', name])).resolve() != Path(spec[name + '_keg']):
            raise RuntimeError('Homebrew changed during the raylib build; retry with the new toolchain.')


def ensure_library(pool, spec, build=compile_library):
    pool = Path(pool)
    pool.mkdir(parents=True, exist_ok=True)
    destination = pool / build_id(spec)
    # flock is released by the OS even if a build process exits unexpectedly.
    with (pool / (build_id(spec) + '.lock')).open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if ready(destination, spec):
            return destination
        print(f"Building shared web raylib {spec['raylib_version']} with Emscripten "
              f"{spec['emscripten_version']}…", file=sys.stderr, flush=True)
        with tempfile.TemporaryDirectory(prefix='.publish-', dir=pool) as temporary:
            stage = Path(temporary) / 'result'
            stage.mkdir()
            build(spec, stage, pool)
            record = {'toolchain': spec, 'library_sha256': digest(stage / LIBRARY)}
            (stage / 'build.json').write_text(json.dumps(record, indent=2) + '\n')
            if not ready(stage, spec):
                raise RuntimeError('The staged raylib build is incomplete.')
            if destination.exists():
                shutil.rmtree(destination)
            os.replace(stage, destination)
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--odin', default='odin', help='Odin compiler whose raylib bindings will be used')
    parser.add_argument('--describe', action='store_true', help='Show the resolved toolchain without building')
    args = parser.parse_args()
    spec = toolchain(args.odin)
    pool = Path(os.environ.get('DEV_POOL_ROOT', str(Path.home() / '.local/share/dev-pool'))) / 'raylib-web'
    if args.describe:
        print(json.dumps({'directory': str(pool / build_id(spec)), 'toolchain': spec}, indent=2))
    else:
        print(ensure_library(pool, spec))


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print('Shared raylib setup failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
