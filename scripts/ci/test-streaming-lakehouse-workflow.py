#!/usr/bin/env python3
"""Contract tests for the first streaming/lakehouse workflow DAG."""

from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/build-components.yml"
COMPONENTS = ROOT / "ci/components.yaml"


def yaml_json(path: Path) -> dict:
    result = subprocess.run(
        ["ruby", "-ryaml", "-rjson", "-e", "puts JSON.generate(YAML.load_file(ARGV.fetch(0)))", str(path)],
        text=True,
        capture_output=True,
        check=True,
    )
    return json.loads(result.stdout)


class StreamingLakehouseWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow = yaml_json(WORKFLOW)
        cls.jobs = cls.workflow["jobs"]
        cls.catalog = yaml_json(COMPONENTS)["components"]

    def test_dispatch_exposes_kafka_and_flink(self) -> None:
        on = self.workflow.get("on") or self.workflow.get("true")
        choices = on["workflow_dispatch"]["inputs"]["start_component"]["options"]
        self.assertIn("kafka", choices)
        self.assertIn("flink", choices)
        self.assertIn("all", choices)

    def test_dispatch_exposes_trino_as_an_independent_lifecycle(self) -> None:
        on = self.workflow.get("on") or self.workflow.get("true")
        choices = on["workflow_dispatch"]["inputs"]["start_component"]["options"]
        self.assertIn("trino", choices)
        trino = self.jobs["trino"]
        self.assertIn("inputs.start_component == 'trino'", trino["if"])
        self.assertIn("inputs.start_component == 'all'", trino["if"])
        self.assertEqual(trino["with"]["component"], "trino")
        self.assertEqual(trino["with"]["version"], "483")
        self.assertEqual(trino["with"]["builder"], "custom")
        self.assertEqual(trino["with"]["source_identity"], self.catalog["trino"]["source_identity"])
        self.assertNotIn("needs", trino)

    def test_ci_pr_runs_trino_runtime_and_lifecycle_contracts(self) -> None:
        ci_pr = (ROOT / ".github/workflows/ci-pr.yml").read_text(encoding="utf-8")
        self.assertIn("test-pinned-java-runtime.sh", ci_pr)
        self.assertIn("test-trino-ci-contract.py", ci_pr)

    def test_iceberg_is_pinned_to_spark_flink_compatibility_and_clean_smoke(self) -> None:
        iceberg = self.catalog["iceberg"]
        self.assertEqual(iceberg["version"], "1.12.0")
        self.assertEqual(iceberg["artifact_type"], "integration-rpm")
        self.assertEqual(iceberg["runtime_packages"], [
            "bigdata-iceberg-spark", "bigdata-iceberg-flink"
        ])
        self.assertEqual(iceberg["depends_on"], ["spark", "flink"])
        self.assertEqual(iceberg["compatibility"]["engine_versions"], {
            "spark": "3.5.8", "flink": "1.20.1", "scala": "2.12"
        })
        self.assertEqual(iceberg["source_identity"], "d72a2c06306fac05f6962148834c7d0860ea0fb7")
        iceberg_job = self.jobs["iceberg"]
        self.assertEqual(iceberg_job["with"]["component"], "iceberg")
        self.assertEqual(iceberg_job["with"]["test_profile"], "iceberg-cross-engine-smoke")
        self.assertIn("spark_gate", iceberg_job["needs"])
        self.assertIn("flink", iceberg_job["needs"])
        self.assertIn("iceberg_prerequisite_spark", iceberg_job["needs"])
        self.assertIn("iceberg_prerequisite_flink", iceberg_job["needs"])
        self.assertIn("inputs.start_component == 'iceberg'", iceberg_job["if"])
        self.assertEqual(self.jobs["iceberg_prerequisite_spark"]["with"]["version"], "3.5.8")
        self.assertEqual(self.jobs["iceberg_prerequisite_flink"]["with"]["version"], "1.20.1")
        self.assertIn("inputs.start_component == 'iceberg'", self.jobs["iceberg_prerequisite_spark"]["if"])
        self.assertIn("inputs.start_component == 'iceberg'", self.jobs["iceberg_prerequisite_flink"]["if"])

    def test_kafka_kraft_uses_zookeeper_package_prerequisite(self) -> None:
        # KRaft avoids a ZooKeeper quorum at runtime, but the pinned Bigtop RPM
        # still has a hard package Requires edge on ZooKeeper.
        kafka = self.catalog["kafka"]
        self.assertEqual(kafka["test_profile"], "kafka-kraft-smoke")
        self.assertIn("zookeeper", kafka["depends_on"])
        self.assertIn("kafka_prerequisite", self.jobs["kafka"].get("needs", []))
        self.assertEqual(self.workflow["jobs"]["kafka_prerequisite"]["with"]["component"], "zookeeper")

    def test_flink_depends_on_hadoop(self) -> None:
        self.assertIn("hadoop", self.catalog["flink"]["depends_on"])
        self.assertIn("flink_prerequisite", self.jobs["flink"].get("needs", []))

    def test_hadoop_failure_does_not_block_kafka(self) -> None:
        self.assertNotIn("flink_prerequisite", self.jobs["kafka"].get("needs", []))
        self.assertNotIn("kafka_prerequisite", self.jobs["flink"].get("needs", []))

    def test_dispatch_starts_selected_component_and_descendants_only(self) -> None:
        kafka_if = self.jobs["kafka"]["if"]
        flink_if = self.jobs["flink"]["if"]
        self.assertIn("inputs.start_component == 'kafka'", kafka_if)
        self.assertIn("inputs.start_component == 'flink'", flink_if)
        self.assertIn("inputs.start_component == 'all'", kafka_if)
        self.assertIn("inputs.start_component == 'all'", flink_if)
        self.assertIn("needs.zookeeper_gate.outputs.continue_chain == 'true'", kafka_if)
        self.assertIn("needs.hadoop_gate.outputs.continue_chain == 'true'", flink_if)
        self.assertEqual(self.jobs["kafka"]["needs"], ["zookeeper_gate", "kafka_prerequisite"])
        self.assertEqual(self.jobs["flink"]["needs"], ["hadoop_gate", "flink_prerequisite"])
        # Main/all runs reuse the already-completed base stages; only targeted
        # starts invoke a second prerequisite lifecycle.
        self.assertIn("inputs.start_component == 'kafka'", self.jobs["kafka_prerequisite"]["if"])
        self.assertNotIn("inputs.start_component == 'all'", self.jobs["kafka_prerequisite"]["if"])
        self.assertIn("inputs.start_component == 'flink'", self.jobs["flink_prerequisite"]["if"])
        self.assertNotIn("inputs.start_component == 'all'", self.jobs["flink_prerequisite"]["if"])
        for job_name in ("kafka_prerequisite", "kafka", "flink_prerequisite", "flink"):
            with self.subTest(job=job_name):
                permissions = self.jobs[job_name]["permissions"]
                self.assertEqual(permissions["contents"], "write")
                self.assertEqual(permissions["actions"], "read")
                self.assertEqual(permissions["pull-requests"], "write")
        lifecycle = yaml_json(ROOT / ".github/workflows/component-lifecycle.yml")["jobs"]
        repo_check = lifecycle["repo_check"]["with"]
        self.assertEqual(repo_check["component"], "${{ inputs.component }}")
        self.assertEqual(repo_check["version"], "${{ inputs.version }}")
        self.assertEqual(repo_check["source_identity"], "${{ inputs.source_identity }}")
        self.assertEqual(repo_check["artifact_type"], "${{ inputs.artifact_type }}")
        self.assertEqual(repo_check["test_profile"], "${{ inputs.test_profile }}")
        self.assertEqual(repo_check["jdk"], "${{ inputs.jdk }}")
        self.assertEqual(repo_check["jdk_package"], "${{ inputs.jdk_package }}")
        zookeeper_if = self.jobs["zookeeper_repo_check"]["if"]
        self.assertIn("inputs.start_component == 'all'", zookeeper_if)


if __name__ == "__main__":
    unittest.main(verbosity=2)
