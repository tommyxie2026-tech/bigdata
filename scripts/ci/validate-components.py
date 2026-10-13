#!/usr/bin/env python3
"""Validate the component catalog used by the unified CI lifecycle."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError as error:  # pragma: no cover - exercised in CI setup
    raise SystemExit("PyYAML is required; install it with python3 -m pip install pyyaml") from error


VERSION = re.compile(r"^[0-9]+(?:\.[0-9]+){1,3}(?:[-+][A-Za-z0-9.-]+)?$")
PACKAGE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9+_.-]*$")
TOKEN = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
IMMUTABLE_GIT_REF = re.compile(r"^(?:[0-9a-f]{40}|[0-9a-f]{64})$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
SUPPORTED_JDKS = {"8", "11", "17", "21"}
SUPPORTED_PROFILES = {
    "legacy-smoke",
    "kafka-kraft-smoke",
    "flink-local-job-smoke",
    "trino-single-node-smoke",
    "hue-single-node-smoke",
    "iceberg-cross-engine-smoke",
    "hudi-cross-engine-smoke",
    "paimon-cross-engine-smoke",
}
RUNTIME_VERSION = re.compile(r"^[0-9]+(?:\.[0-9]+){0,2}$")
LEGACY_COMPONENTS = {"zookeeper", "hadoop", "tez", "hive", "spark", "hbase"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate_component(name: str, entry: Any) -> list[str]:
    require(bool(TOKEN.fullmatch(name)), f"invalid component name: {name!r}")
    require(isinstance(entry, dict), f"component {name}: entry must be a mapping")

    version = entry.get("version")
    require(isinstance(version, str) and bool(VERSION.fullmatch(version)),
            f"component {name}: version must be an exact numeric release")

    packages = entry.get("runtime_packages")
    require(isinstance(packages, list) and bool(packages),
            f"component {name}: runtime_packages must be a non-empty list")
    require(all(isinstance(item, str) and bool(PACKAGE.fullmatch(item)) for item in packages),
            f"component {name}: runtime_packages contains an invalid RPM package name")
    require(len(packages) == len(set(packages)),
            f"component {name}: runtime_packages contains duplicates")

    dependencies = entry.get("depends_on")
    require(isinstance(dependencies, list) and all(
        isinstance(item, str) and bool(TOKEN.fullmatch(item)) for item in dependencies
    ), f"component {name}: depends_on must be a list of component names")
    require(len(dependencies) == len(set(dependencies)),
            f"component {name}: depends_on contains duplicates")
    require(name not in dependencies, f"component {name}: cannot depend on itself")

    # The original six entries predate the richer lifecycle contract. They keep
    # their existing metadata while all newly registered entries are explicit.
    legacy = name in LEGACY_COMPONENTS and "builder" not in entry
    builder = entry.get("builder", "bigtop" if legacy else None)
    artifact_type = entry.get("artifact_type", "service-rpm" if legacy else None)
    require(builder in {"bigtop", "custom"},
            f"component {name}: builder must be 'bigtop' or 'custom'")
    require(artifact_type in {"service-rpm", "integration-rpm"},
            f"component {name}: unsupported artifact_type")
    require(isinstance(entry.get("build_task"), str) and bool(TOKEN.fullmatch(entry["build_task"])),
            f"component {name}: build_task is required and must be a stable token")

    if not legacy:
        profile = entry.get("test_profile")
        require(isinstance(profile, str) and profile in SUPPORTED_PROFILES,
                f"component {name}: unsupported or missing test_profile {profile!r}")
        jdk = str(entry.get("jdk", ""))
        require(jdk in SUPPORTED_JDKS, f"component {name}: unsupported JDK {jdk!r}")
        require(isinstance(entry.get("jdk_package"), str)
                and bool(PACKAGE.fullmatch(entry["jdk_package"])),
                f"component {name}: jdk_package is required and must be an RPM package name")
        identity = entry.get("source_identity")
        if builder == "bigtop":
            require(isinstance(identity, str) and bool(IMMUTABLE_GIT_REF.fullmatch(identity)),
                    f"component {name}: Bigtop source_identity must be a full immutable commit SHA")

    if builder == "custom":
        runtime = entry.get("runtime")
        require(isinstance(runtime, dict) and bool(runtime),
                f"component {name}: custom builder requires runtime metadata")
        require(set(runtime).issubset({"java", "python"}) and bool(runtime),
                f"component {name}: runtime may declare java and/or python versions")
        require(all(isinstance(version, str) and bool(RUNTIME_VERSION.fullmatch(version))
                    for version in runtime.values()),
                f"component {name}: runtime versions must be exact numeric versions")
        source = entry.get("source")
        require(isinstance(source, dict), f"component {name}: custom builder requires source metadata")
        source_type = source.get("type")
        url = source.get("url")
        require(source_type in {"git", "archive"},
                f"component {name}: source.type must be git or archive")
        require(isinstance(url, str) and url.startswith("https://"),
                f"component {name}: source.url must use HTTPS")
        if source_type == "git":
            require(isinstance(source.get("ref"), str)
                    and bool(IMMUTABLE_GIT_REF.fullmatch(source["ref"])),
                    f"component {name}: git source.ref must be a full immutable commit SHA")
            require("sha256" not in source,
                    f"component {name}: git sources use ref, not sha256")
            require(entry.get("source_identity") == source.get("ref"),
                    f"component {name}: source_identity must equal the pinned git ref")
        else:
            require(isinstance(source.get("sha256"), str)
                    and bool(SHA256.fullmatch(source["sha256"])),
                    f"component {name}: archive source.sha256 must be a 64-character SHA256")
            require("ref" not in source,
                    f"component {name}: archive sources use sha256, not ref")
            require(entry.get("source_identity") == source.get("sha256"),
                    f"component {name}: source_identity must equal the pinned archive SHA256")
        if artifact_type == "integration-rpm":
            compatibility = entry.get("compatibility")
            require(isinstance(compatibility, dict),
                    f"component {name}: integration-rpm requires a compatibility tuple")
            engines = compatibility.get("engines")
            require(isinstance(engines, list) and bool(engines)
                    and all(isinstance(item, str) and bool(TOKEN.fullmatch(item)) for item in engines),
                    f"component {name}: compatibility.engines must be a non-empty component list")
            require(isinstance(compatibility.get("catalog"), str)
                    and bool(TOKEN.fullmatch(compatibility["catalog"])),
                    f"component {name}: compatibility.catalog is required")
    elif builder == "bigtop":
        source = entry.get("source")
        require(source is None or isinstance(source, dict),
                f"component {name}: source must be omitted for Bigtop builder")

    return dependencies


def validate(path: Path) -> list[str]:
    try:
        with path.open(encoding="utf-8") as stream:
            data = yaml.safe_load(stream)
    except (OSError, yaml.YAMLError) as error:
        raise ValueError(f"cannot load {path}: {error}") from error
    require(isinstance(data, dict), "component catalog must be a YAML mapping")
    require(data.get("schema") == "bigdata.ci.components/v1",
            "unsupported or missing catalog schema")
    components = data.get("components")
    require(isinstance(components, dict) and bool(components),
            "components must be a non-empty mapping")

    graph: dict[str, list[str]] = {}
    compatibility_engines: dict[str, list[str]] = {}
    for name, entry in components.items():
        graph[name] = validate_component(name, entry)
        compatibility = entry.get("compatibility")
        if isinstance(compatibility, dict):
            engines = compatibility.get("engines", [])
            require(isinstance(engines, list),
                    f"component {name}: compatibility.engines must be a list")
            compatibility_engines[name] = engines
    for name, dependencies in graph.items():
        for dependency in dependencies:
            require(dependency in graph,
                    f"component {name}: unknown dependency {dependency!r}")
    for name, engines in compatibility_engines.items():
        for engine in engines:
            require(engine in graph,
                    f"component {name}: unknown compatibility engine {engine!r}")

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name in visiting:
            raise ValueError(f"dependency cycle includes {name}")
        if name in visited:
            return
        visiting.add(name)
        for dependency in graph[name]:
            visit(dependency)
        visiting.remove(name)
        visited.add(name)

    for name in graph:
        visit(name)
    return sorted(graph)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("ci/components.yaml"))
    args = parser.parse_args()
    try:
        components = validate(args.config)
    except ValueError as error:
        print(f"component catalog invalid: {error}", file=sys.stderr)
        return 1
    print(f"component catalog valid: {', '.join(components)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
