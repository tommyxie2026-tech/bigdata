import copy
import unittest
from resume_release import CRITICAL_PATHS, verify_run, verify_evidence
REPO="tommyxie2026-tech/bigdata"
CONTRACT={"component":"flink-cdc-mysql","version":"3.4.0","source_identity":"a"*40,
          "flink":"1.20.1","java":"11","mysql_fixture":"8.0.36",
          "mysql_driver_fixture":"8.0.27","test_profile":"mysql-snapshot-changelog-savepoint"}

def fixture():
    return {"run":{"id":123,"status":"completed","head_branch":"main","head_sha":"b"*40,
                   "head_repository":{"full_name":REPO},"run_attempt":2,"conclusion":"success"},
            "jobs":[{"name":"Test flink-cdc-mysql 3.4.0","run_id":123,"run_attempt":2,
                     "status":"completed","conclusion":"success"}],
            "source_files":{p:("100644","blob","c"*40) for p in CRITICAL_PATHS},
            "current_files":{p:("100644","blob","c"*40) for p in CRITICAL_PATHS},
            "repository":REPO}

def evidence():
    d={"stage":"test","component":"flink-cdc-mysql","version":"3.4.0",
       "source_identity":"a"*40,"test_run_id":"123","build_run_id":"100",
       "jdk":"11","flink_version":"1.20.1","mysql_version":"8.0.36",
       "mysql_jdbc_driver":"8.0.27","test_profile":CONTRACT["test_profile"],
       "artifact_type":"integration-rpm","status":"PASS"}
    for key in ("clean_install","snapshot_exact_rows","insert_update_delete_exact_rows",
                "completed_checkpoint","savepoint_restore_path","restored_exact_rows"):
        d[key]="PASS"
    return "\n".join(f"{k}: {v}" for k,v in d.items())

class ResumeTests(unittest.TestCase):
    def test_verified_main_test_can_resume_release(self):
        verify_run(**fixture())
        self.assertEqual(verify_evidence(evidence(), CONTRACT, "123"),"100")
    def test_failed_skipped_cancelled_or_old_attempt_test_rejected(self):
        for conclusion in ("failure","skipped","cancelled"):
            d=fixture(); d["jobs"][0]["conclusion"]=conclusion
            with self.subTest(conclusion=conclusion), self.assertRaises(ValueError): verify_run(**d)
        d=fixture(); d["jobs"][0]["run_attempt"]=1
        with self.assertRaises(ValueError): verify_run(**d)
    def test_foreign_repository_branch_and_incomplete_run_rejected(self):
        for key,value in (("head_branch","feature"),("status","in_progress"),
                          ("head_repository",{"full_name":"other/repo"})):
            d=fixture(); d["run"][key]=value
            with self.subTest(key=key), self.assertRaises(ValueError): verify_run(**d)
    def test_changed_or_missing_runtime_code_rejected(self):
        for path in CRITICAL_PATHS:
            d=fixture(); d["current_files"][path]=("100644","blob","d"*40)
            with self.subTest(path=path), self.assertRaises(ValueError): verify_run(**d)
        d=fixture(); d["source_files"].pop(CRITICAL_PATHS[0])
        with self.assertRaises(ValueError): verify_run(**d)
    def test_wrong_run_missing_recovery_and_wrong_version_rejected(self):
        for text in (evidence().replace("test_run_id: 123","test_run_id: 999"),
                     evidence().replace("savepoint_restore_path: PASS","savepoint_restore_path: FAIL"),
                     evidence().replace("version: 3.4.0","version: 3.4.1"),
                     evidence().replace("jdk: 11","jdk: 17"),
                     evidence()+"\nstatus: PASS"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                verify_evidence(text, CONTRACT, "123")

if __name__=="__main__": unittest.main()
