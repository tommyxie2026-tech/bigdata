#!/usr/bin/env python3
"""Behavioral contracts for component build/test adapter selection."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts/ci/resolve-component-adapter.py"
SPEC = importlib.util.spec_from_file_location("component_adapter", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)


class ComponentAdapterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.scripts = Path(self.tempdir.name)
        for filename in (
            "build-bigtop-component.sh",
            "test-bigtop-component.sh",
            "build-trino-rpm-openeuler-container.sh",
            "test-trino-rpm-openeuler-container.sh",
            "build-iceberg-rpm-openeuler-container.sh",
            "test-iceberg-rpm-openeuler-container.sh",
        ):
            (self.scripts / filename).write_text("#!/bin/bash\n", encoding="utf-8")

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def test_bigtop_builder_resolves_existing_component_adapter(self) -> None:
        path = ADAPTER.resolve_adapter(
            "bigtop", "flink", "build", "flink-rpm", "flink-local-job-smoke", self.scripts
        )
        self.assertEqual(path, (self.scripts / "build-bigtop-component.sh").resolve())

    def test_custom_builder_resolves_only_matching_component_task(self) -> None:
        path = ADAPTER.resolve_adapter(
            "custom", "trino", "build", "trino-rpm", "trino-single-node-smoke", self.scripts
        )
        self.assertEqual(path, (self.scripts / "build-trino-rpm-openeuler-container.sh").resolve())

    def test_custom_test_profile_resolves_to_component_owned_script(self) -> None:
        path = ADAPTER.resolve_adapter(
            "custom", "trino", "test", "trino-rpm", "trino-single-node-smoke", self.scripts
        )
        self.assertEqual(path, (self.scripts / "test-trino-rpm-openeuler-container.sh").resolve())

    def test_iceberg_custom_adapter_resolves_pinned_rpm_scripts(self) -> None:
        build = ADAPTER.resolve_adapter(
            "custom", "iceberg", "build", "iceberg-rpm", "iceberg-cross-engine-smoke", self.scripts
        )
        test = ADAPTER.resolve_adapter(
            "custom", "iceberg", "test", "iceberg-rpm", "iceberg-cross-engine-smoke", self.scripts
        )
        self.assertEqual(build, (self.scripts / "build-iceberg-rpm-openeuler-container.sh").resolve())
        self.assertEqual(test, (self.scripts / "test-iceberg-rpm-openeuler-container.sh").resolve())

    def test_custom_task_mismatch_fails_closed(self) -> None:
        with self.assertRaises(ValueError):
            ADAPTER.resolve_adapter(
                "custom", "trino", "build", "hue-rpm", "trino-single-node-smoke", self.scripts
            )

    def test_custom_profile_mismatch_fails_closed(self) -> None:
        with self.assertRaises(ValueError):
            ADAPTER.resolve_adapter(
                "custom", "trino", "test", "trino-rpm", "legacy-smoke", self.scripts
            )

    def test_missing_custom_script_fails_closed(self) -> None:
        (self.scripts / "build-trino-rpm-openeuler-container.sh").unlink()
        with self.assertRaises(ValueError):
            ADAPTER.resolve_adapter(
                "custom", "trino", "build", "trino-rpm", "trino-single-node-smoke", self.scripts
            )

    def test_unknown_builder_fails_closed(self) -> None:
        with self.assertRaises(ValueError):
            ADAPTER.resolve_adapter(
                "arbitrary", "trino", "build", "trino-rpm", "trino-single-node-smoke", self.scripts
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
