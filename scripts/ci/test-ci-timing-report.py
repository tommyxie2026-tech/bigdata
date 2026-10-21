#!/usr/bin/env python3
import unittest
from ci_timing_report import timing_report


class TimingTests(unittest.TestCase):
    def test_actual_run_queue_and_job_runtime_are_separate(self):
        run={'id':1,'head_sha':'abc','created_at':'2026-10-21T15:00:00Z',
             'run_started_at':'2026-10-21T15:01:00Z','status':'in_progress'}
        jobs=[{'id':2,'name':'Build hudi','status':'completed','conclusion':'skipped',
               'started_at':None,'completed_at':None},
              {'id':3,'name':'Test hudi','status':'completed','conclusion':'success',
               'started_at':'2026-10-21T15:02:00Z','completed_at':'2026-10-21T15:04:00Z'},
              {'id':4,'name':'Gate','status':'in_progress','conclusion':None,
               'started_at':'2026-10-21T15:04:00Z','completed_at':None}]
        result=timing_report(run,jobs,component='hudi',build_run_id='10',test_run_id='20')
        self.assertEqual(result['run_queue_seconds'],60)
        self.assertEqual(result['jobs'][0]['conclusion'],'skipped')
        self.assertIsNone(result['jobs'][0]['duration_seconds'])
        self.assertEqual(result['jobs'][1]['duration_seconds'],120)
        self.assertIsNone(result['jobs'][2]['duration_seconds'])
        self.assertEqual(result['original_build_run_id'],'10')
        self.assertEqual(result['reused_test_run_id'],'20')
        self.assertEqual(result['run_status'],'in_progress')
    def test_skipped_or_live_jobs_have_no_runtime_even_with_api_timestamps(self):
        for status, conclusion in [('completed', 'skipped'), ('in_progress', None)]:
            job={'status':status,'conclusion':conclusion,
                 'started_at':'2026-10-21T15:01:00Z','completed_at':'2026-10-21T15:01:00Z'}
            self.assertIsNone(timing_report({},[job],component='hudi')['jobs'][0]['duration_seconds'])

    def test_verified_repository_and_actual_new_build_keep_distinct_origins(self):
        reused=timing_report({'id':99},[],component='hue',repo_current=True,
            repo_build_run_id='10',repo_test_run_id='20')
        self.assertEqual(reused['original_build_run_id'],'10')
        self.assertEqual(reused['original_test_run_id'],'20')
        self.assertEqual(reused['artifact_reuse_state'],'verified_repository')
        fresh=timing_report({'id':99},[],component='hue',repo_current=True,
            repo_build_run_id='10',repo_test_run_id='20',build_result='success',test_result='success')
        self.assertEqual(fresh['original_build_run_id'],'99')
        self.assertEqual(fresh['original_test_run_id'],'99')
        self.assertEqual(fresh['artifact_reuse_state'],'fresh')
        retested=timing_report({'id':99},[],component='hue',repo_current=True,
            repo_build_run_id='10',repo_test_run_id='20',build_run_id='30',test_result='success')
        self.assertEqual(retested['original_build_run_id'],'30')
        self.assertEqual(retested['original_test_run_id'],'99')
        self.assertEqual(retested['artifact_reuse_state'],'explicit_rpm')
        unknown=timing_report({'id':99},[],component='hue',repo_current=True)
        self.assertIsNone(unknown['original_build_run_id'])
        self.assertIsNone(unknown['original_test_run_id'])

    def test_merged_pr_preserves_separate_original_build_and_test(self):
        result=timing_report({'id':99},[],component='hudi',test_run_id='20',pr_build_run_id='10')
        self.assertEqual(result['original_build_run_id'],'10')
        self.assertEqual(result['original_test_run_id'],'20')
        self.assertEqual(result['artifact_reuse_state'],'merged_pr')

    def test_missing_or_reversed_times_are_unknown(self):
        run={'id':1,'created_at':'2026-10-21T15:01:00Z','run_started_at':'2026-10-21T15:00:00Z'}
        self.assertIsNone(timing_report(run,[],component='x')['run_queue_seconds'])


if __name__=='__main__':unittest.main()
