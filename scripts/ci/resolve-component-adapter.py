#!/usr/bin/env python3
"""Select an allow-listed build or clean-test adapter for a component."""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path


TOKEN = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
BIGTOP_TASKS = {
    "zookeeper": "zookeeper-rpm",
    "hadoop": "hadoop-rpm",
    "tez": "tez-rpm",
    "hive": "hive-rpm",
    "spark": "spark-rpm",
    "hbase": "hbase-rpm",
    "kafka": "kafka-rpm",
    "flink": "flink-rpm",
}
BIGTOP_PROFILES = {
    "zookeeper": "legacy-smoke",
    "hadoop": "legacy-smoke",
    "tez": "legacy-smoke",
    "hive": "legacy-smoke",
    "spark": "legacy-smoke",
    "hbase": "legacy-smoke",
    "kafka": "kafka-kraft-smoke",
    "flink": "flink-local-job-smoke",
}
CUSTOM = {
    "trino": ("trino-rpm", "trino-single-node-smoke"),
    "hue": ("hue-rpm", "hue-single-node-smoke"),
    "iceberg": ("iceberg-rpm", "iceberg-cross-engine-smoke"),
    "hudi": ("hudi-rpm", "hudi-cross-engine-smoke"),
    "paimon": ("paimon-rpm", "paimon-cross-engine-smoke"),
}


def resolve_adapter(builder: str, component: str, operation: str, task: str,
                    test_profile: str, scripts_dir: Path) -> Path:
    if operation not in {"build", "test"}:
        raise ValueError(f"unsupported adapter operation: {operation!r}")

    if builder == "bigtop":
        if component not in BIGTOP_TASKS:
            raise ValueError(f"unsupported Bigtop component: {component!r}")
        if operation == "build":
            if task != BIGTOP_TASKS[component]:
                raise ValueError(f"component {component}: unexpected Bigtop build task {task!r}")
            filename = "build-bigtop-component.sh"
        else:
            if test_profile != BIGTOP_PROFILES[component]:
                raise ValueError(f"component {component}: unexpected Bigtop test profile {test_profile!r}")
            filename = "test-bigtop-component.sh"
    elif builder == "custom":
        if component not in CUSTOM:
            raise ValueError(f"unsupported custom component: {component!r}")
        expected_task, expected_profile = CUSTOM[component]
        if operation == "build":
            if task != expected_task:
                raise ValueError(f"component {component}: unexpected custom build task {task!r}")
            filename = f"build-{component}-rpm-openeuler-container.sh"
        else:
            if test_profile != expected_profile:
                raise ValueError(f"component {component}: unexpected custom test profile {test_profile!r}")
            filename = f"test-{component}-rpm-openeuler-container.sh"
    else:
        raise ValueError(f"unsupported builder: {builder!r}")

    if not TOKEN.fullmatch(component):
        raise ValueError(f"invalid component name: {component!r}")
    path = (scripts_dir / filename).resolve()
    root = scripts_dir.resolve()
    if path.parent != root or not path.is_file():
        raise ValueError(f"component adapter is missing or outside scripts directory: {filename}")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--builder", required=True)
    parser.add_argument("--component", required=True)
    parser.add_argument("--operation", choices=("build", "test"), required=True)
    parser.add_argument("--task", default="")
    parser.add_argument("--test-profile", default="")
    parser.add_argument("--scripts-dir", type=Path, required=True)
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--exec", action="store_true", dest="exec_adapter")
    args = parser.parse_args()
    try:
        path = resolve_adapter(args.builder, args.component, args.operation,
                               args.task, args.test_profile, args.scripts_dir)
    except ValueError as error:
        print(f"cannot resolve component adapter: {error}", file=sys.stderr)
        return 2
    if args.exec_adapter:
        os.execv("/bin/bash", ["bash", str(path)])
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as stream:
            stream.write(f"script={path.name}\n")
    print(path.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
