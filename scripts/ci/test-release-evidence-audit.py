#!/usr/bin/env python3
"""Regression cases for release run/attempt/job evidence auditing."""
import copy
import unittest
import io
import zipfile
from unittest.mock import patch
from audit_release_evidence import EvidenceError, verify_evidence, parse_fields, read_evidence_zip, pages

REPO = "tommyxie2026-tech/bigdata"
MANIFEST = {
    "component": "hudi", "version": "1.2.1", "build_run_id": "100",
    "test_run_id": "200", "tested_artifact_run_id": "200",
    "source_identity": "a" * 40, "compatibility_identity": "b" * 64,
    "artifact_type": "integration-rpm", "test_profile": "hudi-cross-engine-smoke",
    "jdk": "11", "jdk_package": "java-11-openjdk-devel", "test_status": "PASS",
}
EVIDENCE = {
    "component": "hudi", "version": "1.2.1", "build_run_id": "100",
    "test_run_id": "200", "source_identity": "a" * 40,
    "compatibility_identity": "b" * 64, "artifact_type": "integration-rpm",
    "test_profile": "hudi-cross-engine-smoke", "toolchain_jdk": "11",
    "jdk_package": "java-11-openjdk-devel", "status": "PASS",
}
def run(number, conclusion="success", attempt=1):
    return {"id": number, "status": "completed", "conclusion": conclusion,
            "run_attempt": attempt, "head_sha": "c" * 40,
            "head_repository": {"full_name": REPO}}
def job(stage, run_id, conclusion="success", attempt=1):
    return {"name": f"Hudi / {stage} hudi 1.2.1 / {stage} hudi 1.2.1",
            "run_id": run_id, "run_attempt": attempt,
            "status": "completed", "conclusion": conclusion}
def fixture():
    return dict(manifest=copy.deepcopy(MANIFEST), evidence=copy.deepcopy(EVIDENCE),
                build_run=run(100), test_run=run(200),
                build_jobs=[job("Build", 100)], test_jobs=[job("Test", 200)],
                artifact_names={"hudi-1.2.1-test-evidence", "hudi-1.2.1-tested-rpms"},
                repository=REPO)

class ReleaseEvidenceTests(unittest.TestCase):
    def test_reused_build_is_checked_in_its_own_run(self):
        data = fixture()
        data["test_jobs"].append(job("Build", 200, "skipped"))
        self.assertEqual(verify_evidence(**data), [])

    def test_cancelled_aggregate_does_not_hide_successful_required_jobs(self):
        data = fixture()
        data["test_run"]["conclusion"] = "cancelled"
        self.assertIn("cancelled", " ".join(verify_evidence(**data)))

    def test_successful_aggregate_cannot_hide_failed_or_skipped_test(self):
        for conclusion in ("failure", "skipped", "cancelled", "timed_out"):
            data = fixture()
            data["test_jobs"][0]["conclusion"] = conclusion
            with self.subTest(conclusion=conclusion), self.assertRaises(EvidenceError):
                verify_evidence(**data)

    def test_reused_build_must_be_real_success(self):
        for conclusion in ("failure", "skipped", "cancelled"):
            data = fixture()
            data["build_jobs"][0]["conclusion"] = conclusion
            with self.subTest(conclusion=conclusion), self.assertRaises(EvidenceError):
                verify_evidence(**data)

    def test_old_attempt_success_cannot_cover_latest_attempt_failure(self):
        data = fixture()
        data["test_run"]["run_attempt"] = 2
        data["test_jobs"] = [job("Test", 200, attempt=1)]
        with self.assertRaises(EvidenceError):
            verify_evidence(**data)

    def test_new_attempt_success_is_not_overridden_by_old_aggregate(self):
        data = fixture()
        data["test_run"] = run(200, "cancelled", attempt=2)
        data["test_jobs"] = [job("Test", 200, attempt=2)]
        self.assertTrue(verify_evidence(**data))

    def test_manifest_cannot_point_to_an_unrelated_artifact_run(self):
        data = fixture()
        data["manifest"]["tested_artifact_run_id"] = "201"
        with self.assertRaises(EvidenceError):
            verify_evidence(**data)

    def test_other_repository_or_wrong_component_jobs_fail(self):
        data = fixture()
        data["test_run"]["head_repository"]["full_name"] = "untrusted/fork"
        with self.assertRaises(EvidenceError):
            verify_evidence(**data)
        data = fixture()
        data["test_jobs"][0]["name"] = "Test hudi 1.2.10"
        with self.assertRaises(EvidenceError):
            verify_evidence(**data)

    def test_missing_artifact_or_actual_job_fails(self):
        for key, value in (("artifact_names", set()), ("test_jobs", [])):
            data = fixture()
            data[key] = value
            with self.subTest(key=key), self.assertRaises(EvidenceError):
                verify_evidence(**data)

    def test_wrong_source_compatibility_or_toolchain_evidence_fails(self):
        for key in ("source_identity", "compatibility_identity", "toolchain_jdk",
                    "jdk_package", "build_run_id", "test_run_id", "test_profile", "status"):
            data = fixture()
            data["evidence"][key] = "wrong"
            with self.subTest(key=key), self.assertRaises(EvidenceError):
                verify_evidence(**data)

    def test_incomplete_run_or_wrong_job_run_fails(self):
        data = fixture()
        data["test_run"]["status"] = "in_progress"
        with self.assertRaises(EvidenceError):
            verify_evidence(**data)
        data = fixture()
        data["build_jobs"][0]["run_id"] = 999
        with self.assertRaises(EvidenceError):
            verify_evidence(**data)


class TransportTests(unittest.TestCase):
    def test_empty_jdk_package_for_archive_runtime(self):
        data = fixture()
        data["manifest"]["jdk_package"] = ""
        data["evidence"]["jdk_package"] = ""
        self.assertEqual(verify_evidence(**data), [])

    def test_fields_preserve_quotes_and_reject_duplicates(self):
        self.assertEqual(parse_fields('jdk: 11\njdk_package: "java-11-openjdk-devel"\n'),
                         {"jdk": "11", "jdk_package": "java-11-openjdk-devel"})
        with self.assertRaises(EvidenceError):
            parse_fields("status: FAIL\nstatus: PASS\n")

    def test_small_evidence_archive(self):
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            archive.writestr("evidence.md", "status: PASS\n")
            archive.writestr("logs/test.log", "ignored")
        self.assertEqual(read_evidence_zip(buffer.getvalue()), {"status": "PASS"})

    def test_oversized_or_missing_evidence_rejected(self):
        with self.assertRaises(EvidenceError):
            read_evidence_zip(b"x" * (2 * 1024 * 1024 + 1))
        for filename, text in [("other.md", "status: PASS"),
                               ("evidence.md", "x" * (128 * 1024 + 1))]:
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as archive:
                archive.writestr(filename, text)
            with self.assertRaises(EvidenceError):
                read_evidence_zip(buffer.getvalue())

    def test_pagination_uses_explicit_attempt_and_fails_on_truncation(self):
        with patch("audit_release_evidence.api", return_value={"jobs": []}) as api:
            self.assertEqual(pages("runs/1/attempts/2/jobs", "jobs"), [])
            api.assert_called_once_with("runs/1/attempts/2/jobs?per_page=100&page=1")
        with patch("audit_release_evidence.api", return_value={"jobs": [{}] * 100}):
            with self.assertRaises(EvidenceError):
                pages("runs/1/attempts/2/jobs", "jobs")


if __name__ == "__main__":
    unittest.main(verbosity=2)
