#!/usr/bin/env python3
"""Check Odin UI, then explore its disposable replay examples on macOS."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def locked_fuzz_environment(environment, variables, lock, selected_environment):
    if environment.get('PROJECT_NIX_ENVIRONMENT') != selected_environment:
        raise ValueError('stale dependency selection: reenter this checkout through scripts/dev --profile fuzz')
    if variables.get('ODIN_FUZZ_REVISION') != lock['revision']:
        raise ValueError('stale fuzz environment: rerun through scripts/dev --profile fuzz for this checkout pin')
    tool = variables.get('ODIN_FUZZ_BIN', '')
    if not re.fullmatch(r'/nix/store/[a-z0-9]{32}-[^/]+/bin/odin-fuzz', tool):
        raise ValueError('odin-fuzz must be the pinned shared Nix package; no local or PATH fallback')
    for name in ('ODIN_FUZZ_BIN', 'ODIN_FUZZ_REVISION', 'ODIN'):
        if not variables.get(name) or environment.get(name) != variables[name]:
            raise ValueError(name + ' differs from the locked environment; remove the substitution')
    if environment.get('ODIN_FUZZ_SCANNER'):
        raise ValueError('ODIN_FUZZ_SCANNER overrides are not allowed; use the packaged scanner')
    clean = {**environment, **variables}
    clean['ODIN_FUZZ_SCANNER'] = str(Path(tool).parent.parent / 'libexec/odin-fuzz-scan')
    # Only packaged tools and OS utilities may resolve, even in an edited shell.
    clean['PATH'] = str(Path(environment['PROJECT_NIX_ENVIRONMENT']) / 'bin') + ':/usr/bin:/bin:/usr/sbin:/sbin'
    return clean


def source_identity(environment=None):
    git = subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT, env=environment, text=True, capture_output=True)
    head = None
    if git.returncode == 0 and Path(git.stdout.strip()).resolve() == ROOT:
        paths = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=ROOT, env=environment)
        names = set(paths.split(b'\0')) - {b''}
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, env=environment, text=True).strip()
    else:
        # Source archives have no Git metadata; hash the same ordinary source tree.
        names = set()
        for directory, children, files in os.walk(ROOT):
            children[:] = [name for name in children if name not in ('.git', '.private', '.local', '.work', '.vendor', 'binaries', '__pycache__')
                           and not (Path(directory) / name).is_symlink()]
            names.update(os.fsencode(str((Path(directory) / name).relative_to(ROOT)))
                         for name in files if name != 'AGENTS.md')
    identity = hashlib.sha256()
    for name in sorted(names):
        path = ROOT / os.fsdecode(name)
        identity.update(name + b'\0')
        identity.update(path.read_bytes() if path.is_file() else b'<deleted>')
        identity.update(b'\0')
    return {'head': head, 'sha256': identity.hexdigest()}


def verify_coverage(report, launches):
    if report['status'] != 'ok' or report['finding_count'] != 0:
        raise ValueError('only a clean summary can satisfy the coverage gate')
    expected = {(app['name'], app['path']) for app in launches}
    seen = set()
    for app in report['applications']:
        key = (app['name'], app['path'])
        if key in seen or key not in expected:
            raise ValueError('unexpected or duplicate application in fuzz report')
        seen.add(key)
        if (app['status'] != 'explored' or app['coverage_mode'] != 'llvm_sancov'
                or app['executions'] <= 0 or app['first_party_edges_hit'] <= 0):
            raise ValueError(f'{app["name"]}: require explored LLVM coverage with actual executions and edges')
    if seen != expected:
        raise ValueError('fuzz report is missing configured applications')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--budget', type=int, default=30, help='total exploration seconds (default: 30)')
    parser.add_argument('--seed', type=int, default=1)
    parser.add_argument('--skip-checks', action='store_true', help='reuse prerequisite check.sh already passed on this tree and toolchain')
    options = parser.parse_args()
    if os.environ.get('PROJECT_ROOT') != str(ROOT) or not os.environ.get('PROJECT_NIX_ENVIRONMENT'):
        os.execv(ROOT / 'scripts/dev', [str(ROOT / 'scripts/dev'), '--profile', 'fuzz', 'python3', '-I', str(Path(__file__).resolve()), *sys.argv[1:]])
    if sys.platform != 'darwin':
        raise ValueError('odin-fuzz requires macOS; the portable check suite remains available')
    if options.budget <= 0:
        raise ValueError('--budget must be positive')
    lock = json.loads((ROOT / 'odin-fuzz.lock.json').read_text())
    if (not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', lock['repository'])
            or not re.fullmatch(r'[0-9a-f]{40}', lock['revision'])
            or not re.fullmatch(r'[0-9a-f]{64}', lock['archive_sha256'])):
        raise ValueError('odin-fuzz lock requires a GitHub repository, full revision and archive SHA-256')
    manifest = Path(os.environ['PROJECT_NIX_ENVIRONMENT']) / 'share/project-environment.json'
    variables = json.loads(manifest.read_text())['variables']
    selection_environment = {'PATH': os.defpath, **{key: os.environ[key] for key in ('HOME', 'TMPDIR') if key in os.environ}}
    selected_environment = subprocess.check_output([
        str(ROOT / 'scripts/dev'), '--eval', 'packages.aarch64-darwin.fuzz-environment.outPath',
        '--raw', '--offline', '--option', 'allow-import-from-derivation', 'false',
    ], cwd=ROOT, env=selection_environment, text=True).strip()
    environment = locked_fuzz_environment(os.environ, variables, lock, selected_environment)
    for name in ('ODIN', 'ODIN_FUZZ_BIN', 'ODIN_FUZZ_SCANNER'):
        if not Path(environment[name]).is_file() or not os.access(environment[name], os.X_OK):
            raise ValueError(name + ' is unavailable in the locked package; run scripts/dev --profile fuzz')
    odin = environment['ODIN']
    report = subprocess.check_output([odin, 'report'], env=environment, text=True)
    backend = re.search(r'Backend:\s*LLVM\s+(\d+)', report)
    if not backend:
        raise ValueError('cannot determine LLVM backend from odin report')
    major = backend[1]
    llvm_tools = {}
    for tool in ['clang', 'llvm-symbolizer', 'dsymutil']:
        executable = str(Path(environment['PROJECT_NIX_ENVIRONMENT']) / 'bin' / tool)
        version = subprocess.check_output([executable, '--version'], env=environment, text=True)
        llvm_tools[tool] = {'path': executable, 'version': version.strip()}
        if not re.search(r'(?:version|LLVM)\s+' + re.escape(major) + r'\.', version):
            raise ValueError(f'{tool} must match LLVM {major} from odin report; put that LLVM bin directory on PATH')
    libraries = environment['RAYLIB_LIB_DIR']
    if not (Path(libraries) / 'libraylib.620.dylib').is_file():
        raise ValueError('native replay requires the locked raylib 6.2 library')
    if not options.skip_checks:
        subprocess.run([str(ROOT / 'scripts/check.sh')], cwd=ROOT, env=environment, check=True)
    base = ROOT / '.local/fuzz'
    base.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix='campaign-', dir=base))
    subprocess.run([str(ROOT / 'scripts/retain-nix-environment'), str(run / 'nix-environment')], check=True)
    metadata = {
        'tool': lock, 'odin_report': report, 'compiler_sha256': digest(odin), 'llvm_tools': llvm_tools, 'native_library_directory': libraries,
        'source': source_identity(environment), 'configuration_sha256': digest(ROOT / 'odin-fuzz.json'),
        'seed': options.seed, 'budget': options.budget, 'prerequisites': 'caller-verified' if options.skip_checks else 'passed',
    }
    metadata.update(stage='bootstrap', verified=False, nix_environment=environment['PROJECT_NIX_ENVIRONMENT'])
    print('Fuzz reports and replay artifacts: ' + str(run), flush=True)
    try:
        command = [environment['ODIN_FUZZ_BIN']]
        metadata['stage'] = 'doctor'
        with (run / 'doctor.log').open('w') as log:
            subprocess.run(command + ['doctor'], cwd=ROOT, env=environment, check=True, stdout=log, stderr=subprocess.STDOUT)
        metadata['stage'] = 'discovery'
        with (run / 'scan.log').open('w') as log:
            subprocess.run(command + ['scan', str(ROOT), '--work-dir', str(run)], cwd=ROOT, env=environment, check=True,
                           stdout=log, stderr=subprocess.STDOUT)
        metadata['stage'] = 'exploration'
        with (run / 'explore.log').open('w') as log:
            result = subprocess.run(command + ['explore', str(ROOT), '--work-dir', str(run),
                                    '--corpus-dir', str(base / 'corpus'), '--budget', str(options.budget), '--seed', str(options.seed)],
                                    cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT)
        metadata['explore_exit'] = result.returncode
        if result.returncode not in (0, 1):
            print('Exploration setup failed; detailed triage requires Gemini 4 Neon.', file=sys.stderr)
            return 2
        metadata['stage'] = 'coverage'
        summaries = list(run.glob('runs/*/summary.json'))
        if len(summaries) != 1:
            raise ValueError('expected one safe summary.json; detailed triage requires Gemini 4 Neon')
        summary = json.loads(summaries[0].read_text())
        metadata['finding_count'] = summary['finding_count']
        if result.returncode == 1 or summary['finding_count'] > 0:
            metadata['stage'] = 'triage-required'
            print('Findings require Gemini 4 Neon triage. Keep this run; do not open detailed reports or bundles.', file=sys.stderr)
            return 1
        launches = json.loads((ROOT / 'odin-fuzz.json').read_text())['applications']
        verify_coverage(summary, launches)
        metadata['applications'] = [{key: app[key] for key in ('name', 'executions', 'first_party_edges_hit', 'corpus_loaded', 'corpus_saved')}
                                    for app in summary['applications']]
        metadata['stage'] = 'complete'
        metadata['verified'] = True
        print('Every configured replay has LLVM coverage feedback; no confirmed findings.')
        return 0
    finally:
        (run / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print('Fuzz verification failed: ' + str(error), file=sys.stderr)
        sys.exit(2)
