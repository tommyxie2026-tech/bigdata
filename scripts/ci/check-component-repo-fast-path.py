#!/usr/bin/env python3
"""Validate a committed component RPM repo before allowing CI to fast-pass it.

Exit codes: 0 means the current, tested runtime RPM set is complete and valid;
1 means the repository is absent or does not match and normal CI must run;
2 means the checker could not safely evaluate its inputs.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path, PurePosixPath


REPO_BASE = Path("repo/openeuler-22.03-lts-sp4/bigtop-3.6")
EXPECTED_OS = "openEuler 22.03 LTS SP4"
EXPECTED_LAYOUT = "split-runtime/v2"
EXCLUDED_PACKAGE = re.compile(r"(?:-debuginfo|-debugsource|-devel|-doc|-test|-tests|-javadoc)$")


class RepoMismatch(Exception):
    """The current repository cannot be reused; build/test/release normally."""


class UnsafeInput(Exception):
    """The checker encountered malformed or unreadable data."""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fields(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    try:
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line or line[0].isspace() or ":" not in line:
                continue
            key, raw_value = line.split(":", 1)
            key = key.strip()
            value = raw_value.strip()
            if value.startswith('"'):
                try:
                    value = json.loads(value)
                except json.JSONDecodeError as error:
                    raise RepoMismatch(f"invalid quoted manifest value for {key}: {value!r}") from error
                if not isinstance(value, str):
                    raise RepoMismatch(f"manifest value for {key} must be a string")
            elif value.startswith("'"):
                if len(value) < 2 or not value.endswith("'"):
                    raise RepoMismatch(f"invalid quoted manifest value for {key}: {value!r}")
                value = value[1:-1].replace("''", "'")
            result[key] = value
    except OSError as error:
        raise RepoMismatch(f"cannot read {path}: {error}") from error
    return result


def configured_component(path: Path, component: str) -> tuple[str, set[str]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise UnsafeInput(f"cannot read component config {path}: {error}") from error
    in_components = False
    in_target = False
    in_runtime_packages = False
    version = ""
    packages: list[str] = []
    for line in lines:
        if line == "components:":
            in_components = True
            continue
        if not in_components:
            continue
        match = re.fullmatch(r"  ([a-z0-9_-]+):", line)
        if match:
            in_target = match.group(1) == component
            in_runtime_packages = False
            continue
        if in_target:
            match = re.fullmatch(
                r"    version:\s*(?:'([0-9]+(?:\.[0-9]+){0,3})'|([0-9]+(?:\.[0-9]+){0,3}))\s*",
                line,
            )
            if match:
                version = match.group(1) or match.group(2)
                continue
            if line == "    runtime_packages:":
                in_runtime_packages = True
                continue
            if re.match(r"^    [a-z0-9_-]+:", line):
                in_runtime_packages = False
            if in_runtime_packages:
                match = re.fullmatch(r"      - ([a-z0-9_-]+)", line)
                if match:
                    packages.append(match.group(1))
    if not version:
        raise UnsafeInput(f"component {component!r} has no version in {path}")
    if not packages or len(packages) != len(set(packages)):
        raise UnsafeInput(f"component {component!r} has no valid unique runtime_packages list in {path}")
    return version, set(packages)


def parse_checksum_file(path: Path) -> dict[str, str]:
    checksums: dict[str, str] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise RepoMismatch(f"cannot read {path}: {error}") from error
    for line in lines:
        match = re.fullmatch(r"([0-9a-f]{64})  ((?:\./)?[^/\s][^/]*\.rpm)", line)
        if not match:
            raise RepoMismatch(f"invalid or duplicate checksum entry in {path}: {line!r}")
        filename = PurePosixPath(match.group(2)).name
        if filename in checksums:
            raise RepoMismatch(f"duplicate RPM checksum entry in {path}: {line!r}")
        checksums[filename] = match.group(1)
    if not checksums:
        raise RepoMismatch(f"no RPM checksums in {path}")
    return checksums


def content_digest(path: Path) -> str:
    """Return a materialized RPM hash or the content hash encoded by its LFS pointer."""
    try:
        with path.open("rb") as stream:
            prefix = stream.read(256)
    except OSError as error:
        raise RepoMismatch(f"cannot read {path}: {error}") from error
    if prefix.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
        match = re.search(rb"(?m)^oid sha256:([0-9a-f]{64})$", prefix)
        if not match:
            raise RepoMismatch(f"malformed Git LFS pointer: {path}")
        return match.group(1).decode("ascii")
    return sha256(path)


def xml_tag(element: ET.Element) -> str:
    return element.tag.rsplit("}", 1)[-1]


def child(element: ET.Element, name: str) -> ET.Element:
    matches = [entry for entry in element if xml_tag(entry) == name]
    if len(matches) != 1:
        raise RepoMismatch(f"expected one {name} element, found {len(matches)}")
    return matches[0]


def resolve_metadata_path(target: Path, href: str) -> Path:
    relative = PurePosixPath(href)
    if relative.is_absolute() or ".." in relative.parts:
        raise RepoMismatch(f"unsafe repository metadata path: {href!r}")
    path = target.joinpath(*relative.parts)
    if not path.is_file():
        raise RepoMismatch(f"repository metadata file is missing: {href}")
    return path


def load_xml_data(target: Path, href: str) -> bytes:
    path = resolve_metadata_path(target, href)
    try:
        data = path.read_bytes()
        if path.suffix == ".gz":
            return gzip.decompress(data)
        return data
    except (OSError, EOFError) as error:
        raise RepoMismatch(f"cannot read repository metadata {href}: {error}") from error


def validate_repomd(target: Path) -> list[dict[str, str]]:
    repomd_path = target / "repodata/repomd.xml"
    try:
        root = ET.parse(repomd_path).getroot()
    except (OSError, ET.ParseError) as error:
        raise RepoMismatch(f"missing or invalid repodata/repomd.xml: {error}") from error
    if xml_tag(root) != "repomd":
        raise RepoMismatch("repomd.xml has an unexpected root element")

    checked: list[dict[str, str]] = []
    for data in (element for element in root if xml_tag(element) == "data"):
        location = child(data, "location").attrib.get("href", "")
        checksum_element = child(data, "checksum")
        algorithm = checksum_element.attrib.get("type", "")
        expected = (checksum_element.text or "").strip().lower()
        if not algorithm or not expected:
            raise RepoMismatch(f"repomd entry has an incomplete checksum: {location}")
        try:
            actual = hashlib.new(algorithm, resolve_metadata_path(target, location).read_bytes()).hexdigest()
        except (ValueError, OSError) as error:
            raise RepoMismatch(f"cannot verify repodata entry {location}: {error}") from error
        if actual != expected:
            raise RepoMismatch(f"repodata checksum mismatch: {location}")
        checked.append({"type": data.attrib.get("type", ""), "location": location})
    if not checked or sum(entry["type"] == "primary" for entry in checked) != 1:
        raise RepoMismatch("repomd must reference exactly one primary metadata file")
    return checked


def validate_primary(
    target: Path,
    href: str,
    component: str,
    version: str,
    expected_packages: set[str],
    checksums: dict[str, str],
) -> None:
    try:
        root = ET.fromstring(load_xml_data(target, href))
    except ET.ParseError as error:
        raise RepoMismatch(f"invalid primary package metadata: {error}") from error
    packages = [element for element in root if xml_tag(element) == "package"]
    if not packages:
        raise RepoMismatch("primary metadata contains no packages")
    try:
        declared_packages = int(root.attrib.get("packages", ""))
    except ValueError as error:
        raise RepoMismatch("primary metadata has an invalid package count") from error
    if declared_packages != len(packages):
        raise RepoMismatch("primary metadata package count does not match its entries")
    indexed: dict[str, str] = {}
    package_names: set[str] = set()
    for package in packages:
        name = (child(package, "name").text or "").strip()
        arch = (child(package, "arch").text or "").strip()
        version_info = child(package, "version").attrib
        checksum_element = child(package, "checksum")
        checksum = (checksum_element.text or "").strip().lower()
        location = child(package, "location").attrib.get("href", "")
        filename = PurePosixPath(location).name
        if not name or not filename.endswith(".rpm") or filename in indexed:
            raise RepoMismatch(f"invalid or duplicate RPM metadata entry: {location!r}")
        if name in package_names:
            raise RepoMismatch(f"duplicate package name in primary metadata: {name}")
        if EXCLUDED_PACKAGE.search(name):
            raise RepoMismatch(f"non-runtime package in repository: {name}")
        if version_info.get("ver") != version:
            raise RepoMismatch(f"RPM {name} version {version_info.get('ver')!r} does not match {version}")
        if arch not in {"noarch", "x86_64"}:
            raise RepoMismatch(f"unexpected RPM architecture for {name}: {arch}")
        if checksum_element.attrib.get("type") != "sha256" or len(checksum) != 64:
            raise RepoMismatch(f"RPM metadata has no SHA256 checksum: {name}")
        if checksums.get(filename) != checksum:
            raise RepoMismatch(f"RPM metadata checksum does not match SHA256SUMS: {filename}")
        if content_digest(target / filename) != checksum:
            raise RepoMismatch(f"RPM content/LFS object checksum mismatch: {filename}")
        indexed[filename] = checksum
        package_names.add(name)
    if set(indexed) != set(checksums):
        raise RepoMismatch("SHA256SUMS and primary metadata describe different RPM sets")
    if package_names != expected_packages:
        missing = sorted(expected_packages - package_names)
        unexpected = sorted(package_names - expected_packages)
        raise RepoMismatch(f"runtime package set mismatch (missing={missing}, unexpected={unexpected})")


def verify(args: argparse.Namespace) -> None:
    if not re.fullmatch(r"[a-z0-9_-]+", args.component):
        raise UnsafeInput(f"invalid component name: {args.component!r}")
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,3}", args.version):
        raise UnsafeInput(f"invalid component version: {args.version!r}")
    if args.source_identity and not re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", args.source_identity):
        raise UnsafeInput("source_identity must be a full immutable Git SHA or SHA256")
    if args.compatibility_identity and not re.fullmatch(r"[0-9a-f]{64}", args.compatibility_identity):
        raise UnsafeInput("compatibility_identity must be a SHA256 digest")
    configured, expected_packages = configured_component(args.components_file, args.component)
    if configured != args.version:
        raise RepoMismatch(f"workflow version {args.version} is stale; ci/components.yaml specifies {configured}")

    target = args.repo_checkout / REPO_BASE / args.component / args.version
    if not target.is_dir():
        raise RepoMismatch(f"RPM repository directory does not exist: {target}")
    manifest = fields(target / "manifest.yaml")
    expected_manifest = {
        "schema": "bigdata.rpm-repo/v2" if args.source_identity or args.compatibility_identity else "bigdata.rpm-repo/v1",
        "component": args.component,
        "version": args.version,
        "bigtop_version": "3.6.0",
        "os": EXPECTED_OS,
        "test_status": "PASS",
        "repository_layout": EXPECTED_LAYOUT,
    }
    if args.source_identity:
        expected_manifest["source_identity"] = args.source_identity
    if args.compatibility_identity:
        expected_manifest["compatibility_identity"] = args.compatibility_identity
    for key in ("artifact_type", "test_profile", "jdk", "jdk_package"):
        expected = getattr(args, key)
        if expected:
            expected_manifest[key] = expected
    for key, expected in expected_manifest.items():
        if manifest.get(key, "") != expected:
            raise RepoMismatch(f"manifest {key} is {manifest.get(key)!r}, expected {expected!r}")
    if not re.fullmatch(r"[0-9a-f]{40}", manifest.get("promotion_workflow_commit", "")):
        raise RepoMismatch("manifest has no valid promotion workflow commit")
    if not re.fullmatch(r"[0-9]+", manifest.get("tested_artifact_run_id", "")):
        raise RepoMismatch("manifest has no valid tested artifact run ID")

    try:
        expected_count = int(manifest.get("rpm_count", ""))
    except ValueError as error:
        raise RepoMismatch("manifest rpm_count is invalid") from error
    checksums = parse_checksum_file(target / "SHA256SUMS")
    actual_rpms = {path.name for path in target.glob("*.rpm") if path.is_file()}
    if expected_count <= 0 or expected_count != len(actual_rpms) or set(checksums) != actual_rpms:
        raise RepoMismatch("manifest rpm_count, RPM files, and SHA256SUMS do not agree")

    entries = validate_repomd(target)
    primary = next(entry["location"] for entry in entries if entry["type"] == "primary")
    validate_primary(target, primary, args.component, args.version, expected_packages, checksums)
    if len(checksums) != expected_count:
        raise RepoMismatch("validated RPM count does not match manifest")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--component", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--repo-checkout", type=Path, required=True)
    parser.add_argument("--components-file", type=Path, required=True)
    parser.add_argument(
        "--source-identity",
        default="",
        help="expected immutable upstream identity; when set, the manifest must match it",
    )
    parser.add_argument(
        "--compatibility-identity",
        default="",
        help="expected compatibility metadata SHA256; when set, the manifest must match it",
    )
    parser.add_argument("--artifact-type", default="")
    parser.add_argument("--test-profile", default="")
    parser.add_argument("--jdk", default="")
    parser.add_argument("--jdk-package", default="")
    args = parser.parse_args()
    try:
        verify(args)
    except RepoMismatch as error:
        print(f"Repository is not reusable: {error}", file=sys.stderr)
        return 1
    except UnsafeInput as error:
        print(f"Cannot safely check repository: {error}", file=sys.stderr)
        return 2
    print(f"{args.component} {args.version} RPM repository is already current and verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
