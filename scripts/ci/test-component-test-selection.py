#!/usr/bin/env python3
"""Evaluate the actual GitHub condition for main/PR component functional tests."""
import re
from pathlib import Path
import unittest
import yaml

ROOT=Path(__file__).resolve().parents[2]


def selected(**overrides):
    values={'needs.repo_check.result':'success', 'needs.repo_check.outputs.already_current':'true',
            'needs.pr_test_reuse.outputs.test_run_id':'', 'needs.build.result':'skipped',
            'inputs.rpm_build_run_id':'123', 'inputs.require_pr_build_test':True,
            'github.event_name':'push'}
    values.update(overrides)
    condition=yaml.safe_load((ROOT/'.github/workflows/component-lifecycle.yml').read_text())['jobs']['test']['if']
    condition=condition.replace('${{','').replace('}}','').replace('always()','True')
    condition=re.sub(r'\b(?:needs|inputs|github)\.[a-zA-Z_.]+',lambda m:repr(values[m[0]]),condition)
    condition=condition.replace('&&',' and ').replace('||',' or ')
    return bool(eval(condition.strip(),{'__builtins__':{}},{}))


class SelectionTests(unittest.TestCase):
    def test_main_does_not_retest_an_exact_verified_published_rpm(self):
        self.assertFalse(selected())
    def test_pr_keeps_explicit_actual_test_requirement(self):
        self.assertTrue(selected(**{'github.event_name':'pull_request'}))
    def test_unpublished_existing_build_is_really_tested(self):
        self.assertTrue(selected(**{'needs.repo_check.outputs.already_current':'false'}))
    def test_new_successful_build_is_really_tested(self):
        self.assertTrue(selected(**{'needs.build.result':'success'}))
    def test_verified_pr_test_reuse_does_not_repeat_the_test(self):
        self.assertFalse(selected(**{'needs.pr_test_reuse.outputs.test_run_id':'999',
                                    'needs.repo_check.outputs.already_current':'false'}))
    def test_failed_or_cancelled_inputs_cannot_run(self):
        self.assertFalse(selected(**{'needs.repo_check.result':'failure'}))
        self.assertFalse(selected(**{'needs.build.result':'cancelled'}))


if __name__=='__main__':unittest.main()
