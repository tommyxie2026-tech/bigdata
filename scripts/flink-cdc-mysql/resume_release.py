"""Resume publication only from verified, unchanged mainline test artifacts."""
import argparse
import json
import os
import re
import urllib.request
from pathlib import Path

CRITICAL_PATHS = tuple("scripts/flink-cdc-mysql/" + p for p in (
    "compile.sh", "package.sh", "test.sh", "protocol.py", "harness/pom.xml",
    "harness/src/main/java/bigdata/ci/MysqlSmoke.java", "contract.json"))

def verify_run(run, jobs, source_files, current_files, repository):
    if (run.get("status") != "completed" or run.get("head_branch") != "main"
            or run.get("head_repository", {}).get("full_name") != repository
            or not re.fullmatch(r"[0-9a-f]{40}", run.get("head_sha", ""))):
        raise ValueError("Expected completed mainline run in this repository")
    matching = [j for j in jobs if j.get("name") == "Test flink-cdc-mysql 3.4.0"]
    if len(matching) != 1:
        raise ValueError("Expected exactly one actual component test job")
    job = matching[0]
    if (job.get("status") != "completed" or job.get("conclusion") != "success"
            or job.get("run_id") != run["id"]
            or job.get("run_attempt") != run["run_attempt"]):
        raise ValueError("Latest-attempt component test did not succeed")
    for path in CRITICAL_PATHS:
        if path not in source_files or source_files[path] != current_files.get(path):
            raise ValueError("Untested payload or runtime change: " + path)

def verify_evidence(text, contract, run_id):
    fields = {}
    for line in text.splitlines():
        if ": " not in line:
            continue
        key, value = line.split(": ", 1)
        if key in fields:
            raise ValueError("Duplicate evidence field: " + key)
        fields[key] = value
    expected = {"stage": "test", "artifact_type": "integration-rpm",
                "test_run_id": str(run_id), "status": "PASS",
                "jdk": contract["java"], "flink_version": contract["flink"],
                "mysql_version": contract["mysql_fixture"],
                "mysql_jdbc_driver": contract["mysql_driver_fixture"]}
    for key in ("component", "version", "source_identity", "test_profile"):
        expected[key] = contract[key]
    for key in ("clean_install", "snapshot_exact_rows", "insert_update_delete_exact_rows",
                "completed_checkpoint", "savepoint_restore_path", "restored_exact_rows"):
        expected[key] = "PASS"
    for key, value in expected.items():
        if fields.get(key) != value:
            raise ValueError("Invalid evidence field: " + key)
    build = fields.get("build_run_id", "")
    if not re.fullmatch(r"[1-9][0-9]*", build):
        raise ValueError("Invalid build run ID")
    return build

def api(path):
    request = urllib.request.Request("https://api.github.com/repos/" +
        os.environ["GITHUB_REPOSITORY"] + "/" + path, headers={
            "Authorization": "Bearer " + os.environ["GH_TOKEN"],
            "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)

def files(sha):
    tree = api("git/commits/" + sha)["tree"]["sha"]
    data = api("git/trees/" + tree + "?recursive=1")
    if data.get("truncated"):
        raise ValueError("Incomplete source tree")
    return {e["path"]: (e["mode"], e["type"], e["sha"]) for e in data["tree"]}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("verify", "evidence"))
    parser.add_argument("run_id")
    args = parser.parse_args()
    if not re.fullmatch(r"[1-9][0-9]*", args.run_id):
        raise ValueError("Invalid test run ID")
    if args.mode == "verify":
        run = api("actions/runs/" + args.run_id)
        jobs = []
        for page in range(1, 11):
            batch = api("actions/runs/" + args.run_id + "/attempts/" +
                        str(run["run_attempt"]) + "/jobs?per_page=100&page=" + str(page))
            jobs.extend(batch["jobs"])
            if len(jobs) >= batch["total_count"]:
                break
        else:
            raise ValueError("Incomplete job history")
        verify_run(run, jobs, files(run["head_sha"]), files(os.environ["GITHUB_SHA"]),
                   os.environ["GITHUB_REPOSITORY"])
        print("Verified mainline test " + args.run_id + " at " + run["head_sha"])
    else:
        contract = json.loads(Path("scripts/flink-cdc-mysql/contract.json").read_text())
        build = verify_evidence(Path("test-evidence/evidence.md").read_text(),
                                contract, args.run_id)
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            output.write("build_run=" + build + "\n")
        print("Verified test evidence and original build " + build)

if __name__ == "__main__":
    main()
