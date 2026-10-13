#!/usr/bin/env python3
"""Contract tests for dependency RPM repo mounting in the shared test flows."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RESOLVER = ROOT / "scripts/ci/resolve-component-dependencies.py"


class ComponentDependencyContracts(unittest.TestCase):
    def resolve(self, component: str) -> dict[str, object]:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "github-output"
            subprocess.run(
                [sys.executable, str(RESOLVER), "--config", "ci/components.yaml", "--component", component,
                 "--github-output", str(output)],
                cwd=ROOT,
                check=True,
            )
            lines = output.read_text(encoding="utf-8").splitlines()
            values: dict[str, object] = {}
            index = 0
            while index < len(lines):
                line = lines[index]
                if "<<" in line:
                    key, delimiter = line.split("<<", 1)
                    index += 1
                    block = []
                    while index < len(lines) and lines[index] != delimiter:
                        block.append(lines[index])
                        index += 1
                    values[key] = "\n".join(block)
                else:
                    key, value = line.split("=", 1)
                    values[key] = value
                index += 1
            return values

    def test_kafka_dependency_closure_includes_zookeeper_repo_and_packages(self) -> None:
        result = self.resolve("kafka")
        self.assertIn("zookeeper/3.8.4", result["dependency_repos"])
        self.assertIn("common/3.6.0", result["dependency_repos"])
        self.assertIn("zookeeper", result["dependency_packages"].split())
        self.assertIn("zookeeper-server", result["dependency_packages"].split())

    def test_flink_dependency_closure_includes_hadoop_and_transitive_zookeeper(self) -> None:
        result = self.resolve("flink")
        self.assertIn("hadoop/3.4.3", result["dependency_repos"])
        self.assertIn("zookeeper/3.8.4", result["dependency_repos"])
        self.assertIn("hadoop-client", result["dependency_packages"].split())
        self.assertIn("zookeeper", result["dependency_packages"].split())

    def test_integration_compatibility_identity_is_canonical_and_emitted(self) -> None:
        compatibility = {"engines": ["flink"], "catalog": "hive-metastore", "storage": "local"}
        expected = hashlib.sha256(
            json.dumps(compatibility, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "components.yaml"
            config.write_text(
                "schema: bigdata.ci.components/v1\ncomponents:\n"
                "  iceberg:\n    version: 1.6.1\n"
                "    runtime_packages: [bigdata-iceberg-flink]\n"
                "    depends_on: [flink]\n"
                "    compatibility:\n      engines: [flink]\n"
                "      catalog: hive-metastore\n      storage: local\n"
                "  flink:\n    version: 1.20.1\n    runtime_packages: [flink]\n    depends_on: []\n",
                encoding="utf-8",
            )
            output = Path(directory) / "github-output"
            subprocess.run(
                [sys.executable, str(RESOLVER), "--config", str(config), "--component", "iceberg",
                 "--github-output", str(output)],
                cwd=ROOT,
                check=True,
            )
            self.assertIn(f"compatibility_identity={expected}", output.read_text(encoding="utf-8"))

    def test_repo_install_script_configures_dependency_repositories(self) -> None:
        script = (ROOT / "scripts/ci/verify-component-repo-install.sh").read_text(encoding="utf-8")
        self.assertIn("DEPENDENCY_REPO_PATHS", script)
        self.assertIn("bigdata-dependency-${dependency_index}", script)
        self.assertIn("dnf -y install", script)

    def test_test_workflow_checks_out_and_mounts_resolved_dependency_repos(self) -> None:
        workflow = (ROOT / ".github/workflows/test-components.yml").read_text(encoding="utf-8")
        self.assertIn("resolve-component-dependencies.py", workflow)
        self.assertIn("steps.catalog.outputs.sparse_paths", workflow)
        self.assertIn("steps.catalog.outputs.dependency_repos", workflow)
        self.assertIn("/dependency-repos:ro", workflow)

    def test_compatibility_identity_flows_through_build_test_release_and_repo_gate(self) -> None:
        build = (ROOT / ".github/workflows/build-one-component.yml").read_text(encoding="utf-8")
        test = (ROOT / ".github/workflows/test-components.yml").read_text(encoding="utf-8")
        release = (ROOT / ".github/workflows/release-components.yml").read_text(encoding="utf-8")
        check = (ROOT / ".github/workflows/check-component-repo.yml").read_text(encoding="utf-8")
        for workflow in (build, test):
            self.assertIn("COMPONENT_COMPATIBILITY_IDENTITY", workflow)
        self.assertIn("expected_compatibility_identity", release)
        self.assertIn("COMPATIBILITY_IDENTITY:", release)
        self.assertIn("--compatibility-identity", check)


if __name__ == "__main__":
    unittest.main(verbosity=2)
