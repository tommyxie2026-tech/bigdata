#!/usr/bin/env python3
"""Contract tests for the component catalog validator."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "scripts/ci/validate-components.py"


SERVICE = """\
schema: bigdata.ci.components/v1
components:
  kafka:
    builder: bigtop
    artifact_type: service-rpm
    version: 3.6.0
    source_identity: 19670ce6a3cc68833b7dd47697cd6272b66bb372
    runtime_packages: [bigtop-kafka]
    depends_on: []
    build_task: kafka-rpm
    test_profile: kafka-kraft-smoke
    jdk: '8'
    jdk_package: java-1.8.0-openjdk
"""


CONNECTOR = """\
schema: bigdata.ci.components/v1
components:
  iceberg:
    builder: custom
    artifact_type: integration-rpm
    version: 1.0.0
    runtime_packages: [bigdata-iceberg-flink]
    depends_on: [flink]
    build_task: iceberg-rpm
    test_profile: iceberg-cross-engine-smoke
    jdk: '17'
    jdk_package: java-17-openjdk
    runtime: {java: '17'}
    source:
      type: archive
      url: https://example.invalid/iceberg-1.0.0.tar.gz
      sha256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    source_identity: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    compatibility:
      engines: [flink]
      catalog: hive-metastore
"""


TRINO = """\
schema: bigdata.ci.components/v1
components:
  trino:
    builder: custom
    artifact_type: service-rpm
    version: '483'
    source_identity: 5533573115277b8c452348f28dcf011aea14dd71
    runtime_packages: [trino-server-rpm]
    depends_on: []
    build_task: trino-rpm
    test_profile: trino-single-node-smoke
    jdk: '25'
    jdk_package: ''
    jdk_runtime_archive:
      url: https://api.adoptium.net/v3/binary/version/jdk-25.0.4%2B7/linux/x64/jdk/hotspot/normal/eclipse
      sha256: e58fcdcd637b25c03ca84cbbcefc70d11efb8f4b4cbd05decc9f661769d77f94
    runtime: {java: '25'}
    source:
      type: git
      url: https://github.com/trinodb/trino-packages.git
      ref: 5533573115277b8c452348f28dcf011aea14dd71
"""


class ComponentConfigTests(unittest.TestCase):
    def validate(self, text: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "components.yaml"
            config.write_text(text, encoding="utf-8")
            return subprocess.run(
                [sys.executable, str(VALIDATOR), "--config", str(config)],
                text=True,
                capture_output=True,
                check=False,
            )

    def test_accepts_pinned_service_entry(self) -> None:
        result = self.validate(SERVICE)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_accepts_connector_entry(self) -> None:
        result = self.validate(CONNECTOR + "\n  flink:\n    builder: bigtop\n    artifact_type: service-rpm\n    version: 1.0.0\n    source_identity: 19670ce6a3cc68833b7dd47697cd6272b66bb372\n    runtime_packages: [flink]\n    depends_on: []\n    build_task: flink-rpm\n    test_profile: flink-local-job-smoke\n    jdk: '11'\n    jdk_package: java-11-openjdk\n")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_accepts_trino_with_pinned_java_runtime_archive(self) -> None:
        result = self.validate(TRINO)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_unpinned_or_invalid_java_runtime_archive(self) -> None:
        for config in (
            TRINO.replace("      sha256: " + "e58fcdcd637b25c03ca84cbbcefc70d11efb8f4b4cbd05decc9f661769d77f94" + "\n", ""),
            TRINO.replace("https://api.adoptium.net/v3/binary/version/jdk-25.0.4%2B7/linux/x64/jdk/hotspot/normal/eclipse", "http://example.invalid/jdk.tar.gz"),
            TRINO.replace("jdk_package: ''", "jdk_package: java-25-openjdk"),
        ):
            with self.subTest(config=config):
                self.assertEqual(self.validate(config).returncode, 1)

    def test_rejects_missing_version_or_runtime_packages(self) -> None:
        cases = (
            SERVICE.replace("    version: 3.6.0\n", ""),
            SERVICE.replace("    runtime_packages: [bigtop-kafka]\n", ""),
            SERVICE.replace("    runtime_packages: [bigtop-kafka]\n", "    runtime_packages: []\n"),
        )
        for config in cases:
            with self.subTest(config=config):
                self.assertEqual(self.validate(config).returncode, 1)

    def test_rejects_floating_custom_ref(self) -> None:
        config = CONNECTOR.replace(
            "      type: archive\n      url: https://example.invalid/iceberg-1.0.0.tar.gz\n      sha256: " + "a" * 64,
            "      type: git\n      url: https://example.invalid/iceberg.git\n      ref: main",
        )
        self.assertEqual(self.validate(config + "\n  flink:\n    builder: bigtop\n    artifact_type: service-rpm\n    version: 1.0.0\n    source_identity: 19670ce6a3cc68833b7dd47697cd6272b66bb372\n    runtime_packages: [flink]\n    depends_on: []\n    build_task: flink-rpm\n    test_profile: flink-local-job-smoke\n    jdk: '11'\n    jdk_package: java-11-openjdk\n").returncode, 1)

    def test_rejects_unknown_builder_or_artifact_type(self) -> None:
        for config in (
            SERVICE.replace("builder: bigtop", "builder: unknown"),
            SERVICE.replace("artifact_type: service-rpm", "artifact_type: archive"),
        ):
            with self.subTest(config=config):
                self.assertEqual(self.validate(config).returncode, 1)

    def test_rejects_duplicate_package(self) -> None:
        self.assertEqual(
            self.validate(SERVICE.replace("[bigtop-kafka]", "[bigtop-kafka, bigtop-kafka]")).returncode,
            1,
        )

    def test_rejects_unknown_dependency_or_cycle(self) -> None:
        unknown = SERVICE.replace("depends_on: []", "depends_on: [missing]")
        cycle = CONNECTOR.replace("depends_on: [flink]", "depends_on: [flink]") + "\n  flink:\n    builder: bigtop\n    artifact_type: service-rpm\n    version: 1.0.0\n    source_identity: 19670ce6a3cc68833b7dd47697cd6272b66bb372\n    runtime_packages: [flink]\n    depends_on: [iceberg]\n    build_task: flink-rpm\n    test_profile: flink-local-job-smoke\n    jdk: '11'\n    jdk_package: java-11-openjdk\n"
        for config in (unknown, cycle):
            with self.subTest(config=config):
                self.assertEqual(self.validate(config).returncode, 1)

    def test_rejects_invalid_jdk_or_package(self) -> None:
        for config in (
            SERVICE.replace("jdk: '8'", "jdk: '8x'"),
            SERVICE.replace("[bigtop-kafka]", "['not a package']"),
        ):
            with self.subTest(config=config):
                self.assertEqual(self.validate(config).returncode, 1)

    def test_rejects_unknown_test_profile(self) -> None:
        config = SERVICE.replace("kafka-kraft-smoke", "unregistered-smoke")
        self.assertEqual(self.validate(config).returncode, 1)

    def test_rejects_unknown_compatibility_engine(self) -> None:
        config = CONNECTOR.replace("[flink]", "[flink, missing-engine]")
        config += "\n  flink:\n    builder: bigtop\n    artifact_type: service-rpm\n    version: 1.20.1\n    source_identity: 19670ce6a3cc68833b7dd47697cd6272b66bb372\n    runtime_packages: [flink]\n    depends_on: []\n    build_task: flink-rpm\n    test_profile: flink-local-job-smoke\n    jdk: '11'\n    jdk_package: java-11-openjdk\n"
        self.assertEqual(self.validate(config).returncode, 1)

    def test_custom_builder_requires_explicit_runtime_metadata(self) -> None:
        config = CONNECTOR.replace("    runtime: {java: '17'}\n", "    runtime: {}\n")
        config += "\n  flink:\n    builder: bigtop\n    artifact_type: service-rpm\n    version: 1.20.1\n    source_identity: 19670ce6a3cc68833b7dd47697cd6272b66bb372\n    runtime_packages: [flink]\n    depends_on: []\n    build_task: flink-rpm\n    test_profile: flink-local-job-smoke\n    jdk: '11'\n    jdk_package: java-11-openjdk\n"
        self.assertEqual(self.validate(config).returncode, 1)

    def test_custom_builder_rejects_unsupported_runtime_version(self) -> None:
        config = CONNECTOR.replace("runtime: {java: '17'}", "runtime: {python: latest}")
        config += "\n  flink:\n    builder: bigtop\n    artifact_type: service-rpm\n    version: 1.20.1\n    source_identity: 19670ce6a3cc68833b7dd47697cd6272b66bb372\n    runtime_packages: [flink]\n    depends_on: []\n    build_task: flink-rpm\n    test_profile: flink-local-job-smoke\n    jdk: '11'\n    jdk_package: java-11-openjdk\n"
        self.assertEqual(self.validate(config).returncode, 1)

    def test_bigtop_service_requires_immutable_source_identity(self) -> None:
        for config in (
            SERVICE.replace("    source_identity: 19670ce6a3cc68833b7dd47697cd6272b66bb372\n", ""),
            SERVICE.replace("19670ce6a3cc68833b7dd47697cd6272b66bb372", "branch-3.6"),
        ):
            with self.subTest(config=config):
                self.assertEqual(self.validate(config).returncode, 1)

    def test_integration_rpm_requires_source_identity_and_compatibility_tuple(self) -> None:
        missing_tuple = CONNECTOR.replace(
            "    compatibility:\n      engines: [flink]\n      catalog: hive-metastore\n", ""
        )
        mismatched_identity = CONNECTOR.replace("source_identity: " + "a" * 64, "source_identity: " + "b" * 64)
        for config in (missing_tuple, mismatched_identity):
            with self.subTest(config=config):
                self.assertEqual(self.validate(config).returncode, 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
