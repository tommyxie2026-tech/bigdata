"""Select a reusable actual RPM build with unchanged package inputs."""
import hashlib
import json
import os
import urllib.request
from pathlib import Path
INPUTS = ("scripts/flink-cdc-postgres/compile.sh",
          "scripts/flink-cdc-postgres/package.sh",
          "scripts/flink-cdc-postgres/contract.json",
          "scripts/ci/retry-maven-downloads.sh")
JOB = "Build RPM flink-cdc-postgres 3.4.0"
ARTIFACT = "flink-cdc-postgres-3.4.0-rpm"
def reusable(run, jobs, artifacts, original, current, repository):
    return (run.get("head_repository", {}).get("full_name") == repository
            and original == current and bool(current)
            and any(j.get("name") == JOB and j.get("run_id") == run["id"]
                    and j.get("status") == "completed" and j.get("conclusion") == "success"
                    for j in jobs)
            and any(a.get("name") == ARTIFACT and not a.get("expired", True)
                    for a in artifacts))
def api(path):
    request=urllib.request.Request("https://api.github.com/repos/" +
        os.environ["GITHUB_REPOSITORY"] + "/" + path, headers={
        "Authorization": "Bearer " + os.environ["GH_TOKEN"],
        "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)
def inputs():
    result={}
    for name in INPUTS:
        data=Path(name).read_bytes()
        result[name]=hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
    return result
def main():
    current=inputs()
    identity=hashlib.sha256(json.dumps(current,sort_keys=True).encode()).hexdigest()
    chosen=""
    if os.environ.get("REBUILD", "false") != "true":
        workflow=api("actions/runs/" + os.environ["GITHUB_RUN_ID"])["workflow_id"]
        runs=api("actions/workflows/" + str(workflow) + "/runs?per_page=100")["workflow_runs"]
        seen=set()
        for run in runs:
            if (run.get("path") != ".github/workflows/flink-cdc-postgres.yml"
                    or str(run["id"]) == os.environ["GITHUB_RUN_ID"]
                    or run["head_sha"] in seen):
                continue
            # Inspect actual jobs even if aggregate Test failed or was cancelled.
            jobs=api("actions/runs/" + str(run["id"]) + "/jobs?filter=latest&per_page=100")["jobs"]
            if not any(j.get("name")==JOB and j.get("conclusion")=="success" for j in jobs):
                continue
            seen.add(run["head_sha"])
            tree=api("git/trees/" + run["head_sha"] + "?recursive=1")
            if tree.get("truncated"):
                raise ValueError("Cannot verify incomplete input tree")
            original={e["path"]: e["sha"] for e in tree["tree"] if e["path"] in INPUTS}
            artifacts=api("actions/runs/" + str(run["id"]) + "/artifacts?per_page=100")["artifacts"]
            if reusable(run,jobs,artifacts,original,current,os.environ["GITHUB_REPOSITORY"]):
                chosen=str(run["id"]);break
    with open(os.environ["GITHUB_OUTPUT"],"a") as output:
        output.write("build=" + ("false" if chosen else "true") + "\n")
        output.write("rpm_run=" + (chosen or os.environ["GITHUB_RUN_ID"]) + "\n")
        output.write("identity=" + identity + "\n")
    print("Reuse verified RPM build " + chosen if chosen else "No matching RPM: build once")
if __name__=="__main__":main()
