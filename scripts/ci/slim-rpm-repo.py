#!/usr/bin/env python3
"""Keep one tested copy of each runtime RPM in its owning DNF repository."""

import argparse
import hashlib
import re
import shutil
import subprocess
from collections import defaultdict
from pathlib import Path


VERSIONS = {
    "zookeeper": "3.8.4",
    "hadoop": "3.4.3",
    "tez": "0.10.5",
    "hive": "4.0.1",
    "spark": "3.5.8",
    "hbase": "2.6.5",
    "common": "3.6.0",
}
ROOT = Path("repo/openeuler-22.03-lts-sp4/bigtop-3.6")
UNNEEDED = re.compile(r"-(?:debuginfo|debugsource|doc|devel|test|tests|javadoc)-")
COMMON_PRIORITY = {"hadoop": 0, "zookeeper": 1, "hive": 2, "tez": 3}


def run(*args, cwd):
    subprocess.run(args, cwd=cwd, check=True)


def digest_and_size(path):
    with path.open("rb") as stream:
        data = stream.read(256)
    match = re.fullmatch(
        rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n?",
        data,
    )
    if match:
        return match.group(1).decode(), int(match.group(2))
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
            size += len(chunk)
    return digest.hexdigest(), size


def original_checksums(directory):
    sums = {}
    for line in (directory / "SHA256SUMS").read_text().splitlines():
        digest, name = line.split(maxsplit=1)
        sums[Path(name.lstrip("* ")).name] = digest
    return sums


def plan(repo_checkout):
    base = repo_checkout / ROOT
    directories = {p.name: p for p in base.iterdir() if p.is_dir() and p.name in VERSIONS}
    candidates = defaultdict(list)
    total_count = total_bytes = 0
    for component, parent in directories.items():
        for version_dir in parent.iterdir():
            if not version_dir.is_dir():
                continue
            manifest = (version_dir / "manifest.yaml").read_text()
            if "test_status: PASS" not in manifest:
                raise ValueError(f"Unverified repository: {version_dir}")
            checksums = original_checksums(version_dir)
            for rpm in version_dir.glob("*.rpm"):
                digest, size = digest_and_size(rpm)
                if checksums.get(rpm.name) != digest:
                    raise ValueError(f"Original checksum mismatch: {rpm}")
                total_count += 1
                total_bytes += size
                name = rpm.name
                if name.endswith(".src.rpm") or UNNEEDED.search(name):
                    continue
                owner = "common" if name.startswith("bigtop-") else name.split("-", 1)[0]
                if owner not in directories and owner != "common":
                    continue  # dependency of a component without its own tested release
                if owner not in VERSIONS:
                    raise ValueError(f"Unknown RPM owner: {name}")
                rank = (0 if component == owner else 1, COMMON_PRIORITY.get(component, 9))
                candidates[(owner, name)].append((rank, rpm, digest, size))

    selected = []
    for (owner, name), choices in sorted(candidates.items()):
        _, source, digest, size = min(choices, key=lambda choice: (choice[0], str(choice[1])))
        destination = base / owner / VERSIONS[owner] / name
        selected.append((source, destination, digest, size))
    print(f"Existing: {total_count} RPM entries, {total_bytes / 2**20:.1f} MiB")
    print(f"Selected: {len(selected)} runtime RPMs, {sum(x[3] for x in selected) / 2**20:.1f} MiB")
    for owner in VERSIONS:
        count = sum(destination.parent.parent.name == owner for _, destination, _, _ in selected)
        if count:
            print(f"  {owner}: {count}")
    return selected


def apply(repo_checkout, selected):
    base = repo_checkout / ROOT
    sources = sorted({str(source.relative_to(repo_checkout)) for source, _, _, _ in selected})
    run("git", "lfs", "pull", "--include=" + ",".join(sources), "--exclude=", cwd=repo_checkout)
    for source, _, digest, size in selected:
        actual_digest, actual_size = digest_and_size(source)
        with source.open("rb") as stream:
            is_pointer = stream.read(64).startswith(b"version https://git-lfs.github.com/spec/v1")
        if is_pointer:
            raise ValueError(f"Git LFS object was not downloaded: {source}")
        if (actual_digest, actual_size) != (digest, size):
            raise ValueError(f"Git LFS content mismatch: {source}")

    # Copy the selected shared packages before removing redundant source paths.
    for source, destination, _, _ in selected:
        if source != destination:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
    retained = {destination for _, destination, _, _ in selected}
    for rpm in base.glob("*/*/*.rpm"):
        if rpm not in retained:
            rpm.unlink()

    for version_dir in sorted({destination.parent for destination in retained}):
        repodata = version_dir / "repodata"
        if repodata.exists():
            shutil.rmtree(repodata)
        rpms = sorted(version_dir.glob("*.rpm"))
        with (version_dir / "SHA256SUMS").open("w") as output:
            for rpm in rpms:
                digest, _ = digest_and_size(rpm)
                output.write(f"{digest}  ./{rpm.name}\n")
        manifest = version_dir / "manifest.yaml"
        if manifest.exists():
            content = re.sub(r"^rpm_count: .*?$", f"rpm_count: {len(rpms)}", manifest.read_text(), flags=re.M)
            content = re.sub(r"^repository_layout:.*\n?", "", content, flags=re.M)
            manifest.write_text(content.rstrip() + "\nrepository_layout: split-runtime/v2\n")
        else:
            source_runs = sorted({
                re.search(r"^tested_artifact_run_id: (\d+)$", (source.parent / "manifest.yaml").read_text(), re.M).group(1)
                for source, destination, _, _ in selected if destination.parent == version_dir
            })
            manifest.write_text(
                "schema: bigdata.rpm-repo/v2\ncomponent: common\nversion: 3.6.0\n"
                f"rpm_count: {len(rpms)}\ntest_status: PASS\nrepository_layout: split-runtime/v2\n"
                "source_test_run_ids:\n" + "".join(f"  - {run_id}\n" for run_id in source_runs)
            )
        run("createrepo_c", "--no-database", str(version_dir), cwd=repo_checkout)

    current = list(base.glob("*/*/*.rpm"))
    if len(current) != len(selected) or len({rpm.name for rpm in current}) != len(current):
        raise ValueError("Runtime RPM set is incomplete or contains duplicate filenames")
    print(f"Rebuilt {len({rpm.parent for rpm in current})} DNF repositories")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-checkout", type=Path, required=True)
    parser.add_argument("--plan-only", action="store_true")
    args = parser.parse_args()
    checkout = args.repo_checkout.resolve()
    selected = plan(checkout)
    if not args.plan_only:
        apply(checkout, selected)


if __name__ == "__main__":
    main()
