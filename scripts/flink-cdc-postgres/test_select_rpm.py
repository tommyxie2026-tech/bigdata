import unittest
from unittest.mock import patch
from select_rpm import reusable, INPUTS, choose_build, input_identity, WORKFLOW
class ReuseTests(unittest.TestCase):
    def fixture(self):
        return dict(run={"id":10,"head_repository":{"full_name":"owner/repo"}},
                    jobs=[{"name":"Build RPM flink-cdc-postgres 3.4.0","status":"completed","conclusion":"success","run_id":10}],
                    artifacts=[{"name":"flink-cdc-postgres-3.4.0-rpm","expired":False}],
                    original={name:"a" for name in INPUTS}, current={name:"a" for name in INPUTS}, repository="owner/repo")
    def test_successful_actual_build_with_same_inputs_reused(self):
        self.assertTrue(reusable(**self.fixture()))
    def test_retry_policy_change_reuses_same_payload(self):
        f=self.fixture(); f["current"]["scripts/ci/retry-maven-downloads.sh"]="new-policy"
        self.assertTrue(reusable(**f))
    def test_each_payload_input_change_or_omission_prevents_reuse(self):
        for name in INPUTS[:3]:
            f=self.fixture(); f["current"][name]="changed"
            self.assertFalse(reusable(**f))
            f=self.fixture(); del f["original"][name]
            self.assertFalse(reusable(**f))
    def choose_fixture(self, expired=False, changed=False):
        f=self.fixture()
        f["run"].update(path=WORKFLOW, head_sha="a"*40)
        f["current"]["scripts/ci/retry-maven-downloads.sh"]="new-policy"
        if changed: f["current"][INPUTS[0]]="changed"
        f["artifacts"][0]["expired"]=expired
        replies={"actions/runs/10": f["run"],
                 "actions/runs/10/jobs?filter=latest&per_page=100": {"jobs":f["jobs"]},
                 "git/trees/"+"a"*40+"?recursive=1": {"tree":[{"path":k,"sha":v} for k,v in f["original"].items()]},
                 "actions/runs/10/artifacts?per_page=100": {"artifacts":f["artifacts"]}}
        published={"build_run_id":"10", "build_input_identity":input_identity(f["original"])}
        return f, replies, published
    def test_published_build_is_preferred_and_original_identity_is_retained(self):
        f, replies, published=self.choose_fixture()
        with patch("select_rpm.api", side_effect=lambda path: replies[path]):
            selected, identity=choose_build(f["current"], "owner/repo", "20", published)
        self.assertEqual(selected, "10")
        self.assertEqual(identity, input_identity(f["original"]))
        self.assertNotEqual(identity, input_identity(f["current"]))
    def test_unprovable_published_build_does_not_fall_back_to_recompilation(self):
        for values in ({"expired":True},{"changed":True}):
            f, replies, published=self.choose_fixture(**values)
            with patch("select_rpm.api", side_effect=lambda path: replies[path]):
                with self.assertRaises(ValueError):
                    choose_build(f["current"], "owner/repo", "20", published)
    def test_published_build_identity_mismatch_is_rejected(self):
        f, replies, published=self.choose_fixture()
        published["build_input_identity"]="wrong"
        with patch("select_rpm.api", side_effect=lambda path: replies[path]):
            with self.assertRaises(ValueError):
                choose_build(f["current"], "owner/repo", "20", published)
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
