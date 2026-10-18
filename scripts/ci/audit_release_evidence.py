#!/usr/bin/env python3
"""Read-only release provenance audit; never builds or downloads RPM payloads."""
import argparse
import importlib.util
import io
from pathlib import Path
import zipfile
import json
import os
import re
import urllib.request

class EvidenceError(ValueError):
    pass

def verify_evidence(*, manifest, evidence, build_run, test_run, build_jobs,
                    test_jobs, artifact_names, repository):
    warnings = []
    component, version = manifest["component"], manifest["version"]
    if manifest.get("tested_artifact_run_id") != manifest.get("test_run_id"):
        raise EvidenceError("tested artifact run differs from test run")
    for stage, run, jobs, key in (
        ("Build", build_run, build_jobs, "build_run_id"),
        ("Test", test_run, test_jobs, "test_run_id"),
    ):
        if (str(run.get("id")) != manifest.get(key)
                or run.get("status") != "completed"
                or run.get("head_repository", {}).get("full_name") != repository
                or not re.fullmatch(r"[0-9a-f]{40}", run.get("head_sha", ""))):
            raise EvidenceError(f"{stage}: incomplete or mismatched run")
        pattern = re.compile(r"(?:^| / )" + stage + r" " + re.escape(component)
                             + r" " + re.escape(version) + r"(?:$| / )", re.I)
        selected = [j for j in jobs if pattern.search(j.get("name", ""))]
        if not selected or any(
            j.get("status") != "completed" or j.get("conclusion") != "success"
            or j.get("run_attempt") != run.get("run_attempt")
            or str(j.get("run_id")) != str(run["id"]) for j in selected
        ):
            raise EvidenceError(f"{stage}: missing or unsuccessful current-attempt job")
        if run.get("conclusion") != "success":
            warnings.append(f"{stage}: aggregate {run.get('conclusion')}; required jobs succeeded")
    required = {f"{component}-{version}-test-evidence", f"{component}-{version}-tested-rpms"}
    if not required <= set(artifact_names):
        raise EvidenceError("missing live test artifacts")
    for key in ("component", "version", "build_run_id", "test_run_id",
                "source_identity", "compatibility_identity", "artifact_type",
                "test_profile", "jdk_package"):
        if key not in manifest or key not in evidence or evidence[key] != manifest[key]:
            raise EvidenceError(f"evidence mismatch: {key}")
    if (manifest.get("test_status") != "PASS" or evidence.get("status") != "PASS"
            or evidence.get("toolchain_jdk") != manifest.get("jdk")):
        raise EvidenceError("test status or toolchain mismatch")
    return warnings

def api(path):
    request = urllib.request.Request("https://api.github.com/" + path, headers={
        "Accept": "application/vnd.github+json",
        "Authorization": "Bearer " + os.environ["GITHUB_TOKEN"],
    })
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)

def pages(path, key):
    result = []
    for page in range(1, 11):
        data = api(f"{path}?per_page=100&page={page}")[key]
        result.extend(data)
        if len(data) < 100:
            return result
    raise EvidenceError("API pagination exceeds audit limit")

def parse_fields(text):
    values = {}
    for line in text.splitlines():
        match = re.match(r"^([a-z_]+):\s*(.*?)\s*$", line)
        if match:
            key, value = match.groups()
            if key in values:
                raise EvidenceError(f"duplicate evidence field: {key}")
            values[key] = value.strip("\"'")
    return values

def read_evidence_zip(payload):
    if len(payload) > 2 * 1024 * 1024:
        raise EvidenceError("evidence archive exceeds 2 MiB")
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        matches = [f for f in archive.infolist() if f.filename == "evidence.md"]
        if len(matches) != 1 or matches[0].file_size > 128 * 1024:
            raise EvidenceError("missing, duplicate or oversized evidence.md")
        with archive.open(matches[0]) as stream:
            text = stream.read(128 * 1024 + 1)
        if len(text) > 128 * 1024:
            raise EvidenceError("oversized evidence.md")
        return parse_fields(text.decode("utf-8"))

def download_evidence(repository, artifact):
    if artifact["size_in_bytes"] > 2 * 1024 * 1024:
        raise EvidenceError("evidence archive exceeds download limit")
    # The GitHub redirect is authenticated; the signed blob URL needs no token.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repository}/actions/artifacts/{artifact['id']}/zip",
        headers={"Authorization": "Bearer " + os.environ["GITHUB_TOKEN"]})
    try:
        urllib.request.build_opener(NoRedirect).open(request, timeout=20)
    except urllib.error.HTTPError as response:
        if response.code != 302:
            raise
        location = response.headers["Location"]
    else:
        raise EvidenceError("expected signed artifact redirect")
    if not location.startswith("https://"):
        raise EvidenceError("unsafe artifact redirect")
    with urllib.request.urlopen(location, timeout=20) as response:
        payload = response.read(2 * 1024 * 1024 + 1)
    return read_evidence_zip(payload)

def audit_manifest(repository, path, root):
    manifest = parse_fields(path.read_text())
    if manifest.get("schema") != "bigdata.rpm-repo/v2":
        raise EvidenceError("only v2 manifests are covered")
    spec = importlib.util.spec_from_file_location(
        "repo_check", Path(__file__).with_name("check-component-repo-fast-path.py"))
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    checker.verify(argparse.Namespace(
        component=manifest["component"], version=manifest["version"],
        repo_checkout=root, components_file=root / "ci/components.yaml",
        source_identity=manifest["source_identity"],
        compatibility_identity=manifest["compatibility_identity"],
        artifact_type=manifest["artifact_type"], test_profile=manifest["test_profile"],
        jdk=manifest["jdk"], jdk_package=manifest["jdk_package"]))
    runs, jobs = {}, {}
    prefix = f"repos/{repository}/actions/runs/"
    for key in ("build_run_id", "test_run_id"):
        number = manifest[key]
        if not number.isdecimal():
            raise EvidenceError("invalid run ID")
        runs[key] = api(prefix + number)
        attempt = runs[key]["run_attempt"]
        jobs[key] = pages(prefix + number + f"/attempts/{attempt}/jobs", "jobs")
    artifacts = pages(prefix + manifest["test_run_id"] + "/artifacts", "artifacts")
    name = f"{manifest['component']}-{manifest['version']}-test-evidence"
    selected = [a for a in artifacts if a["name"] == name and not a["expired"]]
    if len(selected) != 1:
        raise EvidenceError("missing or ambiguous live evidence artifact")
    evidence = download_evidence(repository, selected[0])
    warnings = verify_evidence(
        manifest=manifest, evidence=evidence,
        build_run=runs["build_run_id"], test_run=runs["test_run_id"],
        build_jobs=jobs["build_run_id"], test_jobs=jobs["test_run_id"],
        artifact_names={a["name"] for a in artifacts if not a["expired"]},
        repository=repository)
    return {"component": manifest["component"], "version": manifest["version"],
            "status": "PASS", "warnings": warnings}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--component", choices=[
        "all", "kafka", "flink", "trino", "iceberg", "hudi", "paimon", "hue"],
        default="all")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
        raise EvidenceError("invalid repository")
    covered = {"kafka", "flink", "trino", "iceberg", "hudi", "paimon", "hue"}
    selected = covered if args.component == "all" else {args.component}
    results, seen = [], set()
    base = args.root / "repo/openeuler-22.03-lts-sp4/bigtop-3.6"
    for path in sorted(base.glob("*/*/manifest.yaml")):
        manifest = parse_fields(path.read_text())
        if manifest.get("component") not in selected or manifest.get("schema") != "bigdata.rpm-repo/v2":
            continue
        seen.add(manifest["component"])
        try:
            results.append(audit_manifest(args.repository, path, args.root))
        except Exception as error:
            results.append({"manifest": str(path), "status": "FAIL", "error": str(error)})
    for component in sorted(selected - seen):
        results.append({"component": component, "status": "FAIL", "error": "no v2 manifest"})
    print(json.dumps(results, indent=2))
    return int(any(r["status"] != "PASS" for r in results))

if __name__ == "__main__":
    raise SystemExit(main())
