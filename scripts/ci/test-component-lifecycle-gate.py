#!/usr/bin/env python3
"""Run the real workflow gate against PR/main reuse and failure cases."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[2]


class GateTests(unittest.TestCase):
    def gate(self, **overrides):
        flow = yaml.safe_load((ROOT / '.github/workflows/component-lifecycle.yml').read_text())
        command = flow['jobs']['gate']['steps'][0]['run']
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'output'
            summary = Path(directory) / 'summary'
            env = dict(os.environ, CHECK_RESULT='success', ALREADY_CURRENT='true',
                       PR_TEST_RUN_ID='', RPM_BUILD_RUN_ID='', BUILD_RESULT='skipped',
                       TEST_RESULT='skipped', RELEASE_RESULT='skipped', EVENT_NAME='push',
                       IS_FORK_PR='false', REQUIRE_PR_BUILD_TEST='true',
                       GITHUB_OUTPUT=str(output), GITHUB_STEP_SUMMARY=str(summary))
            env.update(overrides)
            result = subprocess.run(['bash', '-c', command], env=env, capture_output=True, text=True)
            return result, output.read_text() if output.exists() else ''

    def test_main_verified_repository_passes_despite_pr_only_requirement(self):
        result, output = self.gate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('stage_passed=true', output)

    def test_pr_cannot_skip_its_explicit_build_test_requirement(self):
        result, output = self.gate(EVENT_NAME='pull_request')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('stage_passed=true', output)

    def test_unverified_or_failed_repository_never_passes(self):
        for values in ({'ALREADY_CURRENT':'false'}, {'CHECK_RESULT':'failure'}):
            result, output = self.gate(**values)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('stage_passed=true', output)

    def test_failed_real_test_is_not_hidden_by_verified_repository(self):
        result, output = self.gate(TEST_RESULT='failure')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('stage_passed=true', output)


if __name__ == '__main__':
    unittest.main()
