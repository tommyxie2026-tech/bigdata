#!/usr/bin/env python3
"""Resolve runtime packages and the transitive RPM repository closure."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import yaml


REPO_PREFIX = "repo/openeuler-22.03-lts-sp4/bigtop-3.6/"


def resolve(config_path: Path, component: str) -> tuple[list[str], list[str], list[str], list[str], str, dict[str, str]]:
    with config_path.open(encoding="utf-8") as stream:
        components = yaml.safe_load(stream)["components"]
    if component not in components:
        raise ValueError(f"unknown component: {component}")

    visited: set[str] = set()

    def visit(name: str) -> None:
        if name in visited:
            return
        visited.add(name)
        for dependency in components[name].get("depends_on", []):
            visit(dependency)

    visit(component)
    visited.remove(component)
    package_list = list(components[component]["runtime_packages"])
    dependency_dirs = [f"{name}/{components[name]['version']}" for name in sorted(visited)]
    dependency_packages = sorted({
        package
        for name in visited
        for package in components[name]["runtime_packages"]
    })
    dependency_dirs.append("common/3.6.0")
    sparse_paths = [f"{REPO_PREFIX}{directory}/" for directory in dependency_dirs]
    compatibility = components[component].get("compatibility")
    runtime_archive = components[component].get("jdk_runtime_archive")
    compatibility_identity = ""
    if runtime_archive is not None:
        identity_data = {"jdk_runtime_archive": runtime_archive}
        if compatibility is not None:
            identity_data["compatibility"] = compatibility
        canonical = json.dumps(identity_data, sort_keys=True, separators=(",", ":"))
        compatibility_identity = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    elif compatibility is not None:
        canonical = json.dumps(compatibility, sort_keys=True, separators=(",", ":"))
        compatibility_identity = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return (package_list, dependency_dirs, sparse_paths, dependency_packages, compatibility_identity,
            runtime_archive or {})


def write_output(output_path: Path, package_list: list[str], dependency_dirs: list[str],
                 sparse_paths: list[str], dependency_packages: list[str],
                 compatibility_identity: str, runtime_archive: dict[str, str]) -> None:
    with output_path.open("a", encoding="utf-8") as stream:
        stream.write("packages=" + " ".join(package_list) + "\n")
        stream.write("dependency_repos=" + ",".join(dependency_dirs) + "\n")
        stream.write("dependency_packages=" + " ".join(dependency_packages) + "\n")
        stream.write("compatibility_identity=" + compatibility_identity + "\n")
        stream.write("jdk_runtime_archive_url=" + runtime_archive.get("url", "") + "\n")
        stream.write("jdk_runtime_archive_sha256=" + runtime_archive.get("sha256", "") + "\n")
        stream.write("sparse_paths<<BIGDATA_SPARSE_PATHS\n")
        stream.write("\n".join(sparse_paths) + "\n")
        stream.write("BIGDATA_SPARSE_PATHS\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("ci/components.yaml"))
    parser.add_argument("--component", required=True)
    parser.add_argument("--github-output", type=Path, required=True)
    args = parser.parse_args()
    try:
        packages, dependencies, sparse_paths, dependency_packages, compatibility_identity, runtime_archive = resolve(
            args.config, args.component
        )
        write_output(args.github_output, packages, dependencies, sparse_paths, dependency_packages,
                     compatibility_identity, runtime_archive)
    except (OSError, KeyError, TypeError, ValueError, yaml.YAMLError) as error:
        print(f"cannot resolve component dependencies: {error}", file=sys.stderr)
        return 1
    print(
        f"{args.component}: packages={len(packages)}, "
        f"dependency_repos={len(dependencies)}, dependency_packages={len(dependency_packages)}, "
        f"compatibility_identity={compatibility_identity or 'none'}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
