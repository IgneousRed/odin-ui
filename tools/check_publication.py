#!/usr/bin/env python3
"""Reject unclassified roots, reserved material and symlinks before publication."""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
import subprocess

RESERVED = {'.git', '.private', '.local', '.work', '.vendor', 'binaries'}
PUBLIC_FILES = {'.gitattributes', '.gitignore', 'CHANGELOG.md', 'LICENSE',
                'MIGRATING.md', 'README.md', 'VENDORING.md', 'VERSION',
                'flake.nix', 'flake.lock', 'odin-fuzz.json', 'odin-fuzz.lock.json',
                'odin-lint.lock.json'}
PUBLIC_DIRECTORIES = {'.githooks', 'docs', 'examples', 'nix', 'scripts', 'spec', 'src', 'tests', 'tools'}
PRIVATE_DIRECTORIES = {'experiments', 'reworks', 'todo', 'instructions'}


def check_path(name, mode=None, private=False):
    path = Path(name)
    if (path.is_absolute() or '..' in path.parts or RESERVED.intersection(path.parts)
            or (not private and 'AGENTS.md' in path.parts)):
        raise ValueError('reserved or escaping publication path: ' + name)
    directories = PRIVATE_DIRECTORIES if private else PUBLIC_DIRECTORIES
    files = {'.gitignore'} if private else PUBLIC_FILES
    if not path.parts or (path.parts[0] not in directories and name not in files):
        raise ValueError('unclassified publication path; review before adding it: ' + name)
    if mode in ('120000', '160000'):
        raise ValueError('publication inputs must be ordinary files, not links: ' + name)


def check_inputs(names):
    for name in names:
        path = Path(name)
        check_path(name)
        if path.is_symlink():
            raise ValueError('publication inputs must be ordinary files/directories: ' + name)
        for entry in [path, *path.rglob('*')] if path.is_dir() else [path]:
            check_path(str(entry))
            if entry.is_symlink() or not (entry.is_file() or entry.is_dir()):
                raise ValueError('publication inputs must be ordinary files/directories: ' + str(entry))


def check_index(private=False):
    root = Path('.private').resolve() if private else Path.cwd()
    git_command = ['git', '-C', str(root)]
    git = subprocess.run([*git_command, 'rev-parse', '--show-toplevel'], text=True, capture_output=True)
    if git.returncode != 0 or Path(git.stdout.strip()).resolve() != root:
        if private:
            raise ValueError('private publication requires the independent .private Git repository')
        # Source archives have no index. Inspect only public inputs, never the
        # local/private directories a developer may keep beside those sources.
        check_inputs([p.name for p in Path.cwd().iterdir()
                      if p.name not in RESERVED | {'AGENTS.md', '.DS_Store', '__pycache__'}])
        return
    entries = subprocess.check_output([*git_command, 'ls-files', '--stage', '-z']).split(b'\0')
    for entry in filter(None, entries):
        metadata, name = entry.split(b'\t', 1)
        check_path(name.decode(), metadata.split()[0].decode(), private=private)


def outgoing_roots(rows):
    roots = []
    for row in rows:
        if not row.strip():
            continue
        local, oid, remote, previous = row.split()
        if not (remote == 'refs/heads/main' or re.fullmatch(r'refs/tags/v\d+\.\d+\.\d+', remote)):
            raise ValueError('outgoing ref requires review: ' + remote)
        if oid == '0' * 40:
            if remote == 'refs/heads/main' or local != '(delete)':
                raise ValueError('main deletion is not an approved publication')
            continue
        if local != remote or not re.fullmatch(r'[0-9a-f]{40}', oid):
            raise ValueError('only explicit matching main/release-tag refs may be pushed: ' + local)
        roots.append(oid)
    return roots


def audit_outgoing(roots, rules_path=None):
    if not roots:
        return
    rules = json.loads((rules_path or Path(__file__).with_name('reclassified-content.json')).read_text())
    if rules.get('algorithm') != 'sha256' or not all(re.fullmatch(r'[0-9a-f]{64}', x) for x in rules['content_hashes']):
        raise ValueError('invalid reclassified-content fingerprints')
    forbidden = set(rules['paths']);fingerprints = set(rules['content_hashes']);seen = set()
    # Deliberately traverse only the explicitly outgoing tips. Machine-only refs,
    # undo history and other local recovery are neither enumerated nor altered.
    commits = subprocess.check_output(['git', 'rev-list', *roots], text=True).splitlines()
    for commit in commits:
        entries = subprocess.check_output(['git', 'ls-tree', '-r', '-z', commit]).split(b'\0')
        for entry in filter(None, entries):
            metadata, name = entry.split(b'\t', 1)
            path = name.decode(errors='surrogateescape')
            mode, kind, oid = metadata.decode().split()
            if path in forbidden or (RESERVED | {'AGENTS.md'}).intersection(Path(path).parts):
                raise ValueError('reclassified/reserved path in outgoing history: ' + path)
            if kind == 'blob' and oid not in seen:
                seen.add(oid)
                payload = subprocess.check_output(['git', 'cat-file', 'blob', oid])
                if hashlib.sha256(payload).hexdigest() in fingerprints:
                    raise ValueError('copied reclassified content in outgoing history: ' + path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--index', action='store_true', help='review staged paths, or public inputs in a source archive')
    selection.add_argument('--pre-push', action='store_true', help='validate the explicit outgoing ref stream and its ancestry')
    selection.add_argument('--private-index', action='store_true', help='review approved staged paths in the private companion')
    parser.add_argument('paths', nargs='*', help='approved working-tree inputs to inspect recursively')
    options = parser.parse_args()
    if options.pre_push:
        audit_outgoing(outgoing_roots(sys.stdin))
    elif options.index or options.private_index:
        check_index(private=options.private_index)
    elif options.paths:
        check_inputs(options.paths)
    else:
        parser.error('select --index, --private-index, --pre-push or explicit approved inputs')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        raise SystemExit('publication check: ' + str(error))
