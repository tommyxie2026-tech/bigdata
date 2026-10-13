#!/usr/bin/env python3
"""Contract checks for the pinned Trino 483 RPM lifecycle."""

from __future__ import annotations

import unittest
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[2]


class TrinoLifecycleContractTests(unittest.TestCase):
    def test_catalog_pins_source_jdk_and_exact_rpm(self) -> None:
        component = yaml.safe_load((ROOT / "ci/components.yaml").read_text())["components"]["trino"]
        self.assertEqual(component["version"], "483")
        self.assertEqual(component["runtime_packages"], ["trino-server-rpm"])
        self.assertEqual(component["source"]["ref"], component["source_identity"])
        self.assertEqual(len(component["jdk_runtime_archive"]["sha256"]), 64)
        self.assertEqual(component["runtime"]["java"], component["jdk"])

    def test_build_uses_pinned_checkout_and_exact_rpm_identity(self) -> None:
        script = (ROOT / "scripts/ci/build-trino-rpm-openeuler-container.sh").read_text()
        for fragment in (
            'fetch --depth=1 origin "${EXPECTED_SOURCE_IDENTITY}"',
            'rev-parse HEAD',
            '"${EXPECTED_SOURCE_IDENTITY}"',
            './mvnw --batch-mode --no-transfer-progress -f trino-server-rpm/pom.xml clean install -DskipTests',
            'trino-server-rpm-${VERSION}.noarch.rpm',
            'rpm -qp --queryformat',
            'retry-maven-downloads.sh',
        ):
            self.assertIn(fragment, script)

    def test_clean_test_requires_health_and_sql_query(self) -> None:
        script = (ROOT / "scripts/ci/test-trino-rpm-openeuler-container.sh").read_text()
        for fragment in (
            "trino-server-rpm-${VERSION}.noarch.rpm",
            "/v1/info",
            "/v1/statement",
            "SELECT 1",
            'attempt % 30 == 0',
            "health_check: PASS",
            "query: PASS",
            'str(rows[0][0]) != "1"',
        ):
            self.assertIn(fragment, script)

    def test_build_and_test_install_checksum_pinned_jdk_runtime(self) -> None:
        helper = (ROOT / "scripts/ci/install-pinned-java-runtime.sh").read_text()
        for fragment in ("sha256sum", "JDK_RUNTIME_ARCHIVE_SHA256", "java -version"):
            self.assertIn(fragment, helper)
        for name in ("build-trino-rpm-openeuler-container.sh", "test-trino-rpm-openeuler-container.sh"):
            script = (ROOT / "scripts/ci" / name).read_text()
            self.assertIn("install-pinned-java-runtime.sh", script)
            self.assertIn("jdk_runtime_archive_sha256: ${JDK_RUNTIME_ARCHIVE_SHA256}", script)

    def test_adapters_and_workflows_carry_pinned_runtime(self) -> None:
        adapter = (ROOT / "scripts/ci/resolve-component-adapter.py").read_text()
        build = (ROOT / ".github/workflows/build-one-component.yml").read_text()
        test = (ROOT / ".github/workflows/test-components.yml").read_text()
        self.assertIn('"trino": ("trino-rpm", "trino-single-node-smoke")', adapter)
        for workflow in (build, test):
            self.assertIn("JDK_RUNTIME_ARCHIVE_URL", workflow)
            self.assertIn("JDK_RUNTIME_ARCHIVE_SHA256", workflow)

    def test_release_and_repo_manifest_retain_runtime_archive_provenance(self) -> None:
        release = (ROOT / ".github/workflows/release-components.yml").read_text()
        stager = (ROOT / "scripts/ci/stage-tested-rpms.sh").read_text()
        self.assertIn('evidence_jdk_archive_sha="$(awk', release)
        self.assertIn("jdk_runtime_archive_sha256: ${{ steps.catalog.outputs.jdk_runtime_archive_sha256 }}", release)
        self.assertIn('jdk_runtime_archive_sha256: ${JDK_RUNTIME_ARCHIVE_SHA256}', stager)
        self.assertIn('grep -qx "jdk_runtime_archive_sha256: ${JDK_RUNTIME_ARCHIVE_SHA256}"', stager)


if __name__ == "__main__":
    unittest.main(verbosity=2)
