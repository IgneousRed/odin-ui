"""Prevent incomplete/ASan-only campaigns from satisfying the coverage gate."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('fuzz_driver', Path(__file__).with_name('run-odin-fuzz.py'))
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)


class LockedSetupTests(unittest.TestCase):
    def setUp(self):
        self.lock = {'revision': '1' * 40}
        self.variables = {
            'ODIN_FUZZ_BIN': '/nix/store/' + 'a' * 32 + '-odin-fuzz-0.4.0/bin/odin-fuzz',
            'ODIN_FUZZ_REVISION': self.lock['revision'],
            'ODIN': '/nix/store/' + 'b' * 32 + '-odin/bin/odin',
        }
        self.environment = {**self.variables, 'PROJECT_NIX_ENVIRONMENT': '/nix/store/' + 'c' * 32 + '-environment',
                            'PATH': '/ambient/tools'}
        self.selection = self.environment['PROJECT_NIX_ENVIRONMENT']

    def test_direct_driver_bootstraps_only_the_explicit_fuzz_profile(self):
        with patch.dict(os.environ, {}, clear=True), \
                patch.object(driver.sys, 'argv', ['run-odin-fuzz.py', '--budget', '5']), \
                patch.object(driver.os, 'execv', side_effect=RuntimeError('inert bootstrap')) as execute:
            with self.assertRaisesRegex(RuntimeError, 'inert bootstrap'):
                driver.main()
            self.assertEqual(execute.call_args.args[1],
                             [str(driver.ROOT / 'scripts/dev'), '--profile', 'fuzz', 'python3', '-I',
                              str(Path(driver.__file__).resolve()), '--budget', '5'])

    def test_selects_packaged_scanner_and_tools_without_executing_them(self):
        clean = driver.locked_fuzz_environment(self.environment, self.variables, self.lock, self.selection)
        self.assertEqual(clean['ODIN_FUZZ_BIN'], self.variables['ODIN_FUZZ_BIN'])
        self.assertEqual(clean['ODIN_FUZZ_SCANNER'],
                         self.variables['ODIN_FUZZ_BIN'].removesuffix('/bin/odin-fuzz') + '/libexec/odin-fuzz-scan')
        self.assertNotIn('/ambient/tools', clean['PATH'])

    def test_refuses_ambient_tool_compiler_and_scanner_substitutions(self):
        for changes in [{'ODIN_FUZZ_BIN': '/tmp/inert-tool'}, {'ODIN': '/tmp/inert-compiler'},
                        {'ODIN_FUZZ_SCANNER': '/tmp/inert-scanner'}]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                driver.locked_fuzz_environment({**self.environment, **changes}, self.variables, self.lock, self.selection)

    def test_refuses_stale_environment_after_checkout_pin_changes(self):
        with self.assertRaisesRegex(ValueError, 'stale fuzz environment'):
            driver.locked_fuzz_environment(self.environment, self.variables, {'revision': '2' * 40}, self.selection)

    def test_refuses_changed_package_selection_even_when_upstream_revision_matches(self):
        with self.assertRaisesRegex(ValueError, 'stale dependency selection'):
            driver.locked_fuzz_environment(self.environment, self.variables, self.lock,
                                           '/nix/store/' + 'd' * 32 + '-updated-environment')

    def test_missing_or_legacy_local_package_never_falls_back_to_path(self):
        for value in ['', 'odin-fuzz', '/tmp/legacy/odin-fuzz']:
            variables = {**self.variables, 'ODIN_FUZZ_BIN': value}
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, 'no local or PATH fallback'):
                driver.locked_fuzz_environment({**self.environment, **variables}, variables, self.lock, self.selection)

    def test_main_refuses_substitution_or_missing_package_before_preparation(self):
        with tempfile.TemporaryDirectory(dir='.work') as directory:
            root = Path(directory).resolve()
            share = root / 'environment/share'
            share.mkdir(parents=True)
            compiler = root / 'inert-compiler'
            compiler.write_text('#!/bin/sh\nexit 99\n')
            compiler.chmod(0o755)
            variables = {**self.variables, 'ODIN': str(compiler)}
            (share / 'project-environment.json').write_text(json.dumps({'variables': variables}))
            (root / 'odin-fuzz.lock.json').write_text(json.dumps({**self.lock, 'repository': 'IgneousRed/odin-fuzz',
                                                               'archive_sha256': '3' * 64}))
            for overrides, message in [({'ODIN_FUZZ_SCANNER': '/tmp/inert-scanner'}, 'ODIN_FUZZ_SCANNER'),
                                       ({}, 'ODIN_FUZZ_BIN is unavailable')]:
                environment = {**self.environment, **variables, 'PROJECT_ROOT': str(root),
                               'PROJECT_NIX_ENVIRONMENT': str(share.parent), **overrides}
                with self.subTest(overrides=overrides), patch.object(driver, 'ROOT', root), \
                        patch.dict(os.environ, environment, clear=True), \
                        patch.object(driver.sys, 'argv', ['run-odin-fuzz.py']), patch.object(driver.sys, 'platform', 'darwin'), \
                        patch.object(driver.subprocess, 'run') as run, \
                        patch.object(driver.subprocess, 'check_output', return_value=str(share.parent)) as output:
                    with self.assertRaisesRegex(ValueError, message):
                        driver.main()
                    run.assert_not_called()
                    output.assert_called_once()
                    self.assertEqual(output.call_args.args[0][1:3],
                                     ['--eval', 'packages.aarch64-darwin.fuzz-environment.outPath'])


class CoverageGateTests(unittest.TestCase):
    def setUp(self):
        self.launches = [{'name': 'showcase', 'path': 'examples/showcase'},
                         {'name': 'failure', 'path': 'examples/failure_policy'}]
        self.report = {'status': 'ok', 'finding_count': 0, 'applications': [dict(app, status='explored', coverage_mode='llvm_sancov',
                                             executions=10, first_party_edges_hit=20) for app in self.launches]}

    def test_requires_each_application_and_real_feedback(self):
        driver.verify_coverage(self.report, self.launches)
        for field, value in [('status', 'unsupported'), ('coverage_mode', 'asan_only'),
                             ('executions', 0), ('first_party_edges_hit', 0)]:
            report = copy.deepcopy(self.report)
            report['applications'][1][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                driver.verify_coverage(report, self.launches)

    def test_missing_duplicate_and_unexpected_launches_fail(self):
        for apps in [self.report['applications'][:1],
                     [self.report['applications'][0]] * 2,
                     [dict(self.report['applications'][0], name='other')]]:
            with self.subTest(apps=apps), self.assertRaises(ValueError):
                driver.verify_coverage(dict(self.report, applications=apps), self.launches)

    def test_findings_and_failed_summaries_cannot_pass(self):
        for changes in [dict(finding_count=1), dict(status='findings'), dict(status='error')]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                driver.verify_coverage(dict(self.report, **changes), self.launches)

    def test_source_archive_identity_needs_no_git_metadata_or_outputs(self):
        with tempfile.TemporaryDirectory(dir='.work') as directory:
            root = Path(directory).resolve()
            source = root / 'main.odin'
            source.write_text('package main\n')
            with patch.object(driver, 'ROOT', root):
                initial = driver.source_identity()
                self.assertIsNone(initial['head'])
                (root / 'AGENTS.md').write_text('synthetic private instructions')
                self.assertEqual(driver.source_identity(), initial)
                for name in ('.work', '.private', '.local', '.vendor'):
                    (root / name).mkdir()
                    (root / name / 'output').write_text('excluded')
                self.assertEqual(driver.source_identity(), initial)
                source.write_text('package changed\n')
                self.assertNotEqual(driver.source_identity()['sha256'], initial['sha256'])


if __name__ == '__main__':
    unittest.main()
