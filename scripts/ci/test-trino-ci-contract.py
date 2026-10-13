#!/usr/bin/env python3
"""Contract checks for the pinned Trino 483 RPM lifecycle."""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path
import sys

import yaml


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "ci"))
from trino_query_client import collect_query_response


class TrinoLifecycleContractTests(unittest.TestCase):
    def test_select_result_rows_are_collected_across_all_pages(self) -> None:
        pages = iter([
            {"data": [[1]], "nextUri": "http://trino/page/2"},
            {"stats": {"state": "FINISHED"}},
        ])
        result = collect_query_response(
            {"columns": [{"name": "_col0"}], "nextUri": "http://trino/page/1"},
            lambda _url: next(pages),
        )
        self.assertEqual(result["data"], [[1]])
        self.assertEqual(result["columns"][0]["name"], "_col0")

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
        query_client = (ROOT / "scripts/ci/trino_query_client.py").read_text()
        for fragment in (
            "trino-server-rpm-${VERSION}.noarch.rpm",
            "/v1/info",
            'd.get("nodeVersion",{}).get("version")',
            'attempt % 30 == 0',
            'cd "${ARTIFACT_ROOT}" && sha256sum -c evidence/SHA256SUMS',
            'util-linux',
            'runuser -u trino -- env JAVA_HOME=',
            'trino_query_client.py',
            "health_check: PASS",
            "query: PASS",
        ):
            self.assertIn(fragment, script)
        for fragment in (
            "/v1/statement",
            'data=b"SELECT 1"',
            "rows.extend(current.get(\"data\") or [])",
            'str(rows[0][0]) != "1"',
        ):
            self.assertIn(fragment, query_client)

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

    def test_stager_accepts_runtime_rpms_with_or_without_release_segment(self) -> None:
        stager = (ROOT / "scripts/ci/stage-tested-rpms.sh").read_text()
        condition_line = next(
            (
                line.strip()
                for line in stager.splitlines()
                if line.strip().startswith('if [[ "${name}" == "${package}-${VERSION}-"*')
            ),
            None,
        )
        self.assertIsNotNone(condition_line, "runtime RPM matching must support both RPM filename forms")
        condition = condition_line.removeprefix("if ").removesuffix("; then")
        script = f"""
set -euo pipefail
package=trino-server-rpm
VERSION=483
names=(trino-server-rpm-483.noarch.rpm trino-server-rpm-483-1.noarch.rpm trino-server-rpm-482.noarch.rpm other-483.noarch.rpm)
expected=(1 1 0 0)
for i in "${!names[@]}"; do
  name="${names[i]}"
  if {condition}; then matched=1; else matched=0; fi
  [[ "${matched}" -eq "${expected[i]}" ]]
done
"""
        result = subprocess.run(["bash", "-c", script], capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_release_and_repo_manifest_retain_runtime_archive_provenance(self) -> None:
        release = (ROOT / ".github/workflows/release-components.yml").read_text()
        stager = (ROOT / "scripts/ci/stage-tested-rpms.sh").read_text()
        self.assertIn('evidence_jdk_archive_sha="$(awk', release)
        self.assertIn("jdk_runtime_archive_sha256: ${{ steps.catalog.outputs.jdk_runtime_archive_sha256 }}", release)
        self.assertIn('jdk_runtime_archive_sha256: ${JDK_RUNTIME_ARCHIVE_SHA256}', stager)
        self.assertIn('grep -qx "jdk_runtime_archive_sha256: ${JDK_RUNTIME_ARCHIVE_SHA256}"', stager)


if __name__ == "__main__":
    unittest.main(verbosity=2)
