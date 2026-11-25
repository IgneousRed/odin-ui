"""Keep local/private inputs out of public source and source-copy packages."""
import importlib.util
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tarfile
import unittest

spec = importlib.util.spec_from_file_location('publication', Path(__file__).with_name('check_publication.py'))
publication = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publication)


class PublicationTests(unittest.TestCase):
    def test_private_index_checks_actual_staged_tasks_and_refuses_forced_local_inputs(self):
        script = Path(publication.__file__).resolve()
        with tempfile.TemporaryDirectory(dir='.work') as directory:
            root = Path(directory).resolve()
            private = root / '.private'
            subprocess.run(['git', 'init', '--initial-branch=main', str(private)], check=True, capture_output=True)
            (private / 'todo').mkdir()
            (private / 'todo/task.md').write_text('synthetic open task')
            subprocess.run(['git', '-C', str(private), 'add', 'todo'], check=True)
            command = [sys.executable, '-I', str(script), '--private-index']
            result = subprocess.run(command, cwd=root, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            (private / '.local').mkdir()
            (private / '.local/input').write_text('synthetic excluded input')
            subprocess.run(['git', '-C', str(private), 'add', '-f', '.local'], check=True)
            result = subprocess.run(command, cwd=root, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('reserved', result.stderr)

    def test_git_free_source_archive_ignores_local_material_and_rejects_unknown_inputs(self):
        script = Path(publication.__file__).resolve()
        with tempfile.TemporaryDirectory(dir='.work') as directory:
            root = Path(directory).resolve()
            (root / 'README.md').write_text('public fixture')
            (root / 'AGENTS.md').write_text('synthetic local instructions')
            for name in ['.private', '.local', '.work', '.vendor']:
                (root / name).mkdir()
                (root / name / 'input').write_text('excluded fixture')
            command = [sys.executable, '-I', str(script), '--index']
            result = subprocess.run(command, cwd=root, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            (root / 'unreviewed').mkdir()
            result = subprocess.run(command, cwd=root, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('unclassified', result.stderr)

    def test_accepts_maintained_public_inputs(self):
        for path in ['README.md', 'src/layout/layout.odin', 'tests/consumer/main.odin']:
            publication.check_path(path, '100644')

    def test_refuses_reserved_paths_at_any_depth_and_escaping_paths(self):
        for path in ['.private/proposal.md', '.local/fuzz/seed', '.work/build/showcase', '.vendor/source.c',
                     'src/.local/data', 'src/.git/config', 'binaries/release.zip', 'AGENTS.md', 'src/AGENTS.md',
                     '../LICENSE', '/tmp/LICENSE']:
            with self.subTest(path=path), self.assertRaises(ValueError):
                publication.check_path(path)

    def test_unknown_root_requires_review(self):
        for path in ['unreviewed/capture.json', 'TODO.md', 'todo/task.md']:
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'unclassified'):
                publication.check_path(path)

    def test_private_tasks_are_allowed_without_allowing_local_captures(self):
        for path in ['.gitignore', 'experiments/probe.md', 'reworks/proposal.md', 'todo/task.md', 'instructions/AGENTS.md']:
            publication.check_path(path, '100644', private=True)
        for path in ['.local/data', '.work/capture', '.vendor/source.c', 'todo/.vendor/source.c', 'todo/.local/data', 'captures/source.odin', 'TODO.md']:
            with self.subTest(path=path), self.assertRaises(ValueError):
                publication.check_path(path, '100644', private=True)

    def test_staged_links_and_nested_repositories_are_refused(self):
        for mode in ['120000', '160000']:
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                publication.check_path('src/asset', mode)

    def test_instruction_files_are_rejected_from_index_and_excluded_from_exports(self):
        script = Path(publication.__file__).resolve()
        attributes = Path('.gitattributes').read_bytes()
        with tempfile.TemporaryDirectory(dir='.work') as directory:
            root = Path(directory).resolve()
            subprocess.run(['git', 'init', '--initial-branch=main', str(root)], check=True, capture_output=True)
            (root / '.gitattributes').write_bytes(attributes)
            (root / 'src').mkdir()
            (root / 'src/main.odin').write_text('package main\n')
            for name in ['AGENTS.md', 'src/AGENTS.md']:
                (root / name).write_text('synthetic private instructions\n')
            subprocess.run(['git', '-C', str(root), 'add', '-f', '--', '.gitattributes',
                            'src/main.odin', 'AGENTS.md', 'src/AGENTS.md'], check=True)
            checked = subprocess.run([sys.executable, '-I', str(script), '--index'], cwd=root,
                                     text=True, capture_output=True)
            self.assertNotEqual(checked.returncode, 0)
            self.assertIn('reserved', checked.stderr)
            tree = subprocess.check_output(['git', '-C', str(root), 'write-tree'], text=True).strip()
            archive = subprocess.check_output(['git', '-C', str(root), 'archive', tree])
            with tarfile.open(fileobj=io.BytesIO(archive)) as exported:
                self.assertIn('src/main.odin', exported.getnames())
                self.assertFalse(any(Path(name).name == 'AGENTS.md' for name in exported.getnames()))

    def test_source_package_cannot_follow_a_link_to_local_material(self):
        with tempfile.TemporaryDirectory(dir='.work') as directory:
            root = Path(directory).resolve()
            (root / 'src').mkdir()
            (root / '.local').mkdir()
            (root / '.local/input').write_text('local fixture')
            (root / 'src/input').symlink_to(root / '.local/input')
            previous = Path.cwd()
            try:
                os.chdir(root)
                with self.assertRaisesRegex(ValueError, 'ordinary files/directories'):
                    publication.check_inputs(['src'])
            finally:
                os.chdir(previous)


    def test_explicit_ref_allowlist_and_machine_backup_ref_denial(self):
        oid = '1' * 40
        self.assertEqual(publication.outgoing_roots([f'refs/heads/main {oid} refs/heads/main {oid}']), [oid])
        self.assertEqual(publication.outgoing_roots([f'refs/tags/v0.2.8 {oid} refs/tags/v0.2.8 {oid}']), [oid])
        for local, remote in [('refs/t3/retained', 'refs/heads/main'), ('refs/backup/retained', 'refs/heads/main'),
                              ('refs/remotes/origin/main', 'refs/remotes/origin/main'), ('refs/heads/private', 'refs/heads/private'),
                              ('refs/tags/local-note', 'refs/tags/local-note'), ('refs/heads/main', 'refs/original/main')]:
            with self.subTest(local=local, remote=remote), self.assertRaises(ValueError):
                publication.outgoing_roots([f'{local} {oid} {remote} {oid}'])
        with self.assertRaises(ValueError):
            publication.outgoing_roots([f'(delete) {"0" * 40} refs/heads/main {oid}'])

    def test_current_clean_tree_does_not_hide_reclassified_ancestry(self):
        self.exercise_history(renamed=False)

    def test_renamed_content_copy_is_rejected_without_a_reserved_path(self):
        self.exercise_history(renamed=True)

    def exercise_history(self, renamed):
        with tempfile.TemporaryDirectory(dir='.work') as directory:
            root = Path(directory);previous = Path.cwd()
            env = {k:v for k,v in os.environ.items() if not k.startswith('GIT_')}
            env.update(GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_SYSTEM='/dev/null')
            def git(*args, data=None):
                return subprocess.check_output(['git','-C',str(root),'-c','user.name=Fixture',
                                                '-c','user.email=fixture@example.invalid','-c','core.hooksPath=/dev/null',*args],
                                               input=data, env=env, stderr=subprocess.PIPE)
            git('init','--initial-branch=main')
            (root/'README.md').write_text('minimal public fixture\n');git('add','README.md');git('commit','-qm','public fixture')
            payload=b'minimal synthetic reclassified record\n'
            record=root/('docs/copy.md' if renamed else 'TODO.md');record.parent.mkdir(exist_ok=True)
            record.write_bytes(payload);git('add',str(record.relative_to(root)));git('commit','-qm','record fixture')
            tainted=git('rev-parse','HEAD').decode().strip()
            git('rm','--',str(record.relative_to(root)));git('commit','-qm','remove record from current tree')
            rules=root/'rules.json';rules.write_text(json.dumps({'algorithm':'sha256','paths':['TODO.md'],
                                                               'content_hashes':[hashlib.sha256(payload).hexdigest()]}))
            try:
                os.chdir(root)
                with self.assertRaisesRegex(ValueError, 'outgoing history'):
                    publication.audit_outgoing(['HEAD'],rules)
                # A machine-only recovery ref is retained, while main receives a
                # clean root with no private ancestry. Audit only the outgoing tip.
                tree=git('rev-parse','HEAD^{tree}').decode().strip()
                clean=git('commit-tree',tree,data=b'clean publication root\n').decode().strip()
                git('update-ref','refs/backup/retained',tainted)
                git('update-ref','refs/heads/main',clean)
                publication.audit_outgoing(['refs/heads/main'],rules)
                self.assertEqual(git('rev-parse','refs/backup/retained').decode().strip(),tainted)
            finally:
                os.chdir(previous)



if __name__ == '__main__':
    unittest.main()
