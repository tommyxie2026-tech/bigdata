#!/usr/bin/env python3
"""Static contracts for the Bigtop Kafka and Flink RPM smoke profiles."""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]
CATALOG = yaml.safe_load((ROOT / "ci/components.yaml").read_text(encoding="utf-8"))
DISPATCHER = (ROOT / "scripts/ci/test-bigtop-component.sh").read_text(encoding="utf-8")


class StreamingComponentContracts(unittest.TestCase):
    def test_kafka_build_uses_configured_runtime_allowlist(self) -> None:
        kafka = CATALOG["components"]["kafka"]
        self.assertEqual(kafka["build_task"], "kafka-rpm")
        self.assertEqual(kafka["runtime_packages"], ["kafka", "kafka-server"])

    def test_kafka_uses_kraft_profile_and_declared_zookeeper_prerequisite(self) -> None:
        kafka = CATALOG["components"]["kafka"]
        self.assertEqual(kafka["test_profile"], "kafka-kraft-smoke")
        self.assertIn("zookeeper", kafka["depends_on"])
        self.assertIn('[[ "${TEST_PROFILE}" == kafka-kraft-smoke ]]', DISPATCHER)

    def test_kafka_requires_broker_start_and_topic_roundtrip(self) -> None:
        script = (ROOT / "scripts/ci/test-kafka-rpm-openeuler-container.sh").read_text(encoding="utf-8")
        for token in (
            "kafka-storage.sh",
            "format",
            "kafka-server-start.sh",
            "kafka-topics.sh",
            "kafka-console-producer.sh",
            "kafka-console-consumer.sh",
            "broker_start: PASS",
            "topic_roundtrip: PASS",
            "bigdata-ci-roundtrip",
        ):
            with self.subTest(token=token):
                self.assertIn(token, script)

    def test_flink_uses_configured_runtime_allowlist_and_hadoop_prerequisite(self) -> None:
        flink = CATALOG["components"]["flink"]
        self.assertEqual(flink["build_task"], "flink-rpm")
        self.assertEqual(flink["runtime_packages"], ["flink", "flink-jobmanager", "flink-taskmanager"])
        self.assertIn("hadoop", flink["depends_on"])
        self.assertIn('[[ "${TEST_PROFILE}" == flink-local-job-smoke ]]', DISPATCHER)

    def test_flink_requires_health_job_submission_and_expected_output(self) -> None:
        script = (ROOT / "scripts/ci/test-flink-rpm-openeuler-container.sh").read_text(encoding="utf-8")
        for token in (
            "start-cluster.sh",
            "/overview",
            "flink\" run",
            "job_submit: PASS",
            "job_result: PASS",
            "alpha",
            "beta",
            "gamma",
        ):
            with self.subTest(token=token):
                self.assertIn(token, script)

    def test_dispatcher_fails_on_profile_component_mismatch(self) -> None:
        result = subprocess.run(
            ["bash", "-c", "COMPONENT=kafka VERSION=3.4.1 TEST_PROFILE=wrong BUILD_RUN_ID=1 TEST_RUN_ID=2 bash scripts/ci/test-bigtop-component.sh"],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("profile", (result.stdout + result.stderr).lower())


if __name__ == "__main__":
    unittest.main(verbosity=2)
