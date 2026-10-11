#!/usr/bin/env python3
"""Contract tests for dependency RPM repo mounting in the shared test flows."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
