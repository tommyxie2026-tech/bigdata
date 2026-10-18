import unittest
from select_rpm import reusable
class ReuseTests(unittest.TestCase):
    def fixture(self):
        return dict(run={"id":10,"head_repository":{"full_name":"owner/repo"}},
                    jobs=[{"name":"Build RPM flink-cdc-postgres 3.4.0","status":"completed","conclusion":"success","run_id":10}],
                    artifacts=[{"name":"flink-cdc-postgres-3.4.0-rpm","expired":False}],
                    original={"compile":"a"}, current={"compile":"a"}, repository="owner/repo")
    def test_successful_actual_build_with_same_inputs_reused(self):
        self.assertTrue(reusable(**self.fixture()))
    def test_skipped_failed_cancelled_or_foreign_build_rejected(self):
        for status in ("skipped","failure","cancelled",None):
            f=self.fixture();f["jobs"][0]["conclusion"]=status
            self.assertFalse(reusable(**f))
        f=self.fixture();f["run"]["head_repository"]["full_name"]="other/repo"
        self.assertFalse(reusable(**f))
    def test_expired_missing_artifact_or_changed_package_inputs_rejected(self):
        f=self.fixture();f["artifacts"][0]["expired"]=True
        self.assertFalse(reusable(**f))
        f=self.fixture();f["artifacts"]=[]
        self.assertFalse(reusable(**f))
        f=self.fixture();f["original"]={"compile":"changed"}
        self.assertFalse(reusable(**f))
        f=self.fixture();f["original"]={}
        self.assertFalse(reusable(**f))
if __name__=="__main__":unittest.main()
