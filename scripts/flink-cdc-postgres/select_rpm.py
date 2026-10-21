"""Reuse the canonical published RPM when package inputs are unchanged.

Download policy is execution policy, not package content. Reused RPMs keep the
identity of their original build, and promotion still compares actual checksums.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import urllib.request

INPUTS = ("scripts/flink-cdc-postgres/compile.sh",
          "scripts/flink-cdc-postgres/package.sh",
          "scripts/flink-cdc-postgres/contract.json",
          "scripts/ci/retry-maven-downloads.sh")
PAYLOAD_INPUTS = INPUTS[:3]
JOB = "Build RPM flink-cdc-postgres 3.4.0"
ARTIFACT = "flink-cdc-postgres-3.4.0-rpm"
WORKFLOW = ".github/workflows/flink-cdc-postgres.yml"
MANIFEST = Path("repo/openeuler-22.03-lts-sp4/bigtop-3.6/flink-cdc-postgres/3.4.0/manifest.yaml")


def input_identity(original):
    # v1 identity deliberately includes the historical retry-policy blob. Keep
    # that original identity when consuming the original artifact/evidence.
    return hashlib.sha256(json.dumps(original, sort_keys=True).encode()).hexdigest()


def reusable(run, jobs, artifacts, original, current, repository):
    payload_matches = all(original.get(name) and original.get(name) == current.get(name)
                          for name in PAYLOAD_INPUTS)
    return (run.get("head_repository", {}).get("full_name") == repository
            and payload_matches and all(original.get(name) for name in INPUTS)
            and any(j.get("name") == JOB and j.get("run_id") == run["id"]
                    and j.get("status") == "completed" and j.get("conclusion") == "success"
                    for j in jobs)
            and any(a.get("name") == ARTIFACT and not a.get("expired", True)
                    for a in artifacts))


def api(path):
    request = urllib.request.Request("https://api.github.com/repos/" +
        os.environ["GITHUB_REPOSITORY"] + "/" + path, headers={
        "Authorization": "Bearer " + os.environ["GH_TOKEN"],
        "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def inputs():
    result = {}
    for name in INPUTS:
        data = Path(name).read_bytes()
        result[name] = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    return result


def published_manifest():
    if not MANIFEST.is_file():
        return {}
    fields = dict(line.split(": ", 1) for line in MANIFEST.read_text().splitlines() if ": " in line)
    if (fields.get("component") != "flink-cdc-postgres" or fields.get("version") != "3.4.0"
            or fields.get("test_status") != "PASS"
            or fields.get("source_identity") != "06581fc73b84b1da45fccf93441d96a118d9bfc1"
            or not re.fullmatch(r"[0-9]+", fields.get("build_run_id", ""))
            or not re.fullmatch(r"[0-9a-f]{64}", fields.get("build_input_identity", ""))):
        raise ValueError("Published PostgreSQL RPM manifest has invalid provenance")
    return fields


def choose_build(current, repository, current_run_id, published):
    if published:
        # Never prefer a newer nondeterministic rebuild over canonical published
        # bytes merely because its source version happens to be the same.
        candidates = [api("actions/runs/" + published["build_run_id"])]
    else:
        workflow = api("actions/runs/" + current_run_id)["workflow_id"]
        candidates = api("actions/workflows/" + str(workflow) + "/runs?per_page=100")["workflow_runs"]
    seen = set()
    for run in candidates:
        if (run.get("path") != WORKFLOW or str(run["id"]) == current_run_id
                or run["head_sha"] in seen):
            continue
        seen.add(run["head_sha"])
        jobs = api("actions/runs/" + str(run["id"]) + "/jobs?filter=latest&per_page=100")["jobs"]
        if not any(j.get("name") == JOB and j.get("status") == "completed"
                   and j.get("conclusion") == "success" for j in jobs):
            continue
        tree = api("git/trees/" + run["head_sha"] + "?recursive=1")
        if tree.get("truncated"):
            raise ValueError("Cannot verify incomplete input tree")
        original = {e["path"]: e["sha"] for e in tree["tree"] if e["path"] in INPUTS}
        artifacts = api("actions/runs/" + str(run["id"]) + "/artifacts?per_page=100")["artifacts"]
        if reusable(run, jobs, artifacts, original, current, repository):
            identity = input_identity(original)
            if published and identity != published["build_input_identity"]:
                raise ValueError("Published RPM build identity does not match its original input tree")
            return str(run["id"]), identity
    if published:
        raise ValueError("Published RPM provenance/artifact unavailable or package inputs changed; "
                         "review the source/revision before explicitly requesting rebuild_rpm")
    return "", input_identity(current)


def main():
    current = inputs()
    chosen, identity = ("", input_identity(current))
    if os.environ.get("REBUILD", "false") != "true":
        chosen, identity = choose_build(current, os.environ["GITHUB_REPOSITORY"],
                                        os.environ["GITHUB_RUN_ID"], published_manifest())
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write("build=" + ("false" if chosen else "true") + "\n")
        output.write("rpm_run=" + (chosen or os.environ["GITHUB_RUN_ID"]) + "\n")
        output.write("identity=" + identity + "\n")
    print("Reuse canonical RPM build " + chosen if chosen else "No matching RPM: build once")


if __name__ == "__main__":
    main()
