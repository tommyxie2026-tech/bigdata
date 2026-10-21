#!/usr/bin/env python3
"""Reuse proven component PR tests after merge, ignoring unrelated repository edits.

This is a fail-closed optimization: any missing provenance, required CI result,
component Build/Test job, or uploaded test artifact falls back to the normal lifecycle.
"""

from __future__ import annotations

import base64
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

from component_reuse_scope import component_input_fingerprint


API = "https://api.github.com"
PER_PAGE = 100


def _normalized(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def merged_pr_matches_tree(
    pull_request: dict[str, Any],
    *,
    repository: str,
    merge_sha: str,
    merge_tree_sha: str,
    head_tree_sha: str,
    component_inputs_match: bool = False,
) -> bool:
    head_repo = (pull_request.get("head") or {}).get("repo") or {}
    base = pull_request.get("base") or {}
    return bool(
        pull_request.get("merged")
        and pull_request.get("merge_commit_sha") == merge_sha
        and base.get("ref") == "main"
        and head_repo.get("full_name", "").lower() == repository.lower()
        and merge_tree_sha
        and head_tree_sha
        and (merge_tree_sha == head_tree_sha or component_inputs_match)
        and (pull_request.get("head") or {}).get("sha")
    )


def _successful_jobs_for_component(
    jobs: list[dict[str, Any]], component: str, version: str, reused_build_proven: bool = False
) -> bool:
    component_version = re.escape(f"{component} {version}".lower())
    matched: dict[str, list[dict[str, Any]]] = {"build": [], "test": []}
    for job in jobs:
        name = _normalized(job.get("name", ""))
        for stage in matched:
            pattern = rf"(?:^|[^a-z0-9]){stage}\s+{component_version}(?![0-9.])"
            if re.search(pattern, name):
                matched[stage].append(job)
    return all(
        matched[stage]
        and (all(job.get("status") == "completed" and job.get("conclusion") == "success" for job in matched[stage])
             or (stage == "build" and reused_build_proven
                 and all(job.get("status") == "completed" and job.get("conclusion") == "skipped"
                         for job in matched[stage])))
        for stage in ("build", "test")
    )


def verified_component_run(
    run: dict[str, Any],
    *,
    jobs: list[dict[str, Any]],
    artifact_names: set[str],
    repository: str,
    head_sha: str,
    component: str,
    version: str,
    allowed_workflows: dict[str, str] | None = None,
    reused_build_proven: bool = False,
) -> bool:
    head_repo = run.get("head_repository") or {}
    required_artifacts = {
        f"{component}-{version}-test-evidence",
        f"{component}-{version}-tested-rpms",
    }
    allowed_workflows = allowed_workflows or {"Build Components": ".github/workflows/build-components.yml"}
    return bool(
        run.get("name") in allowed_workflows
        and allowed_workflows.get(run.get("name")) == run.get("path")
        and run.get("event") == "pull_request"
        and run.get("status") == "completed"
        and run.get("conclusion") == "success"
        and run.get("head_sha") == head_sha
        and head_repo.get("full_name", "").lower() == repository.lower()
        and required_artifacts.issubset(artifact_names)
        and _successful_jobs_for_component(jobs, component, version, reused_build_proven)
    )


def select_reusable_test_run(
    *,
    runs: list[dict[str, Any]],
    ci_runs: list[dict[str, Any]],
    jobs_by_run: dict[int, list[dict[str, Any]]],
    artifacts_by_run: dict[int, set[str]],
    repository: str,
    head_sha: str,
    component: str,
    version: str,
    allowed_workflows: dict[str, str] | None = None,
    reused_build_proven: bool = False,
) -> int | None:
    matching_ci = [run for run in ci_runs
                   if run.get("name") == "CI PR" and run.get("event") == "pull_request"
                   and run.get("path") == ".github/workflows/ci-pr.yml"
                   and run.get("head_sha") == head_sha
                   and (run.get("head_repository") or {}).get("full_name", "").lower() == repository.lower()]
    latest_ci = max(matching_ci, key=lambda item: (item.get("id", 0), item.get("run_attempt", 1)), default={})
    if latest_ci.get("status") != "completed" or latest_ci.get("conclusion") != "success":
        return None
    allowed_workflows = allowed_workflows or {"Build Components": ".github/workflows/build-components.yml"}
    latest = {}
    for candidate in runs:
        path = candidate.get("path")
        if path not in latest or (candidate.get("id", 0), candidate.get("run_attempt", 1)) > (
                latest[path].get("id", 0), latest[path].get("run_attempt", 1)):
            latest[path] = candidate
    runs = list(latest.values())

    for run in runs:
        run_id = run.get("id")
        if not isinstance(run_id, int):
            continue
        if verified_component_run(
            run,
            jobs=jobs_by_run.get(run_id, []),
            artifact_names=artifacts_by_run.get(run_id, set()),
            repository=repository,
            head_sha=head_sha,
            component=component,
            version=version,
            allowed_workflows=allowed_workflows,
            reused_build_proven=reused_build_proven,
        ):
            return run_id
    return None


def _api_get(token: str, path: str) -> dict[str, Any]:
    request = urllib.request.Request(
        API + path,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "bigdata-ci-tested-artifact-reuse",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def _pages(token: str, path: str, key: str) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for page in range(1, 6):
        parts = urllib.parse.urlsplit(path)
        query = [
            (name, value)
            for name, value in urllib.parse.parse_qsl(parts.query, keep_blank_values=True)
            if name not in {"per_page", "page"}
        ]
        query.extend((("per_page", str(PER_PAGE)), ("page", str(page))))
        paged_path = urllib.parse.urlunsplit(
            ("", "", parts.path, urllib.parse.urlencode(query), "")
        )
        data = _api_get(token, paged_path)
        entries = data if isinstance(data, list) else data.get(key, [])
        result.extend(entries)
        if len(entries) < PER_PAGE:
            break
    return result


def _commit_tree(token: str, sha: str) -> str:
    data = _api_get(token, f"/repos/{os.environ['GITHUB_REPOSITORY']}/git/commits/{sha}")
    return (data.get("tree") or {}).get("sha", "")


def _blob_text(token: str, repository: str, sha: str) -> str:
    data = _api_get(token, f"/repos/{repository}/git/blobs/{sha}")
    if data.get("encoding") != "base64":
        raise ValueError("Unsupported Git blob encoding")
    return base64.b64decode("".join(data["content"].split()), validate=True).decode("utf-8")


def _revision_scope(token: str, repository: str, sha: str, component: str, version: str):
    import yaml
    data = _api_get(token, f"/repos/{repository}/git/trees/{sha}?recursive=1")
    if data.get("truncated"):
        raise ValueError("Incomplete component input tree")
    entries = {entry["path"]: entry for entry in data.get("tree", []) if entry.get("type") == "blob"}
    config = yaml.safe_load(_blob_text(token, repository, entries["ci/components.yaml"]["sha"]))
    if str(config["components"][component]["version"]) != version:
        raise ValueError("Component version differs from requested reuse version")
    tree = {path: entry["mode"] + ":" + entry["sha"] for path, entry in entries.items()}
    fingerprint = component_input_fingerprint(tree, config, component)
    workflows = {"Build Components": ".github/workflows/build-components.yml"}
    build_run_id = ""
    own_workflow = f".github/workflows/{component}.yml"
    if own_workflow in entries:
        workflow = yaml.safe_load(_blob_text(token, repository, entries[own_workflow]["sha"]))
        for job in workflow.get("jobs", {}).values():
            inputs = job.get("with", {})
            if (job.get("uses") == "./.github/workflows/component-lifecycle.yml"
                    and inputs.get("component") == component and str(inputs.get("version")) == version):
                if workflow["name"] in workflows:
                    raise ValueError("Ambiguous component workflow name")
                workflows[workflow["name"]] = own_workflow
                build_run_id = str(inputs.get("rpm_build_run_id", ""))
    return fingerprint, workflows, build_run_id


def _verified_original_build(token: str, repository: str, run_id: str, component: str, version: str) -> bool:
    if not re.fullmatch(r"[0-9]+", run_id):
        return False
    run = _api_get(token, f"/repos/{repository}/actions/runs/{run_id}")
    if (run.get("head_repository") or {}).get("full_name", "").lower() != repository.lower():
        return False
    jobs = _pages(token, f"/repos/{repository}/actions/runs/{run_id}/jobs", "jobs")
    pattern = r"(?:^|[^a-z0-9])build\s+" + re.escape(f"{component} {version}".lower()) + r"(?![0-9.])"
    builds = [job for job in jobs if re.search(pattern, _normalized(job.get("name", "")))]
    return bool(builds and all(job.get("status") == "completed" and job.get("conclusion") == "success"
                               and str(job.get("run_id")) == run_id for job in builds))


def find_reusable_test_run(
    *,
    token: str,
    repository: str,
    merge_sha: str,
    component: str,
    version: str,
    provenance: dict[str, str] | None = None,
) -> tuple[int | None, str]:
    associated = _pages(
        token,
        f"/repos/{repository}/commits/{merge_sha}/pulls",
        "pull_requests",
    )
    merge_tree_sha = _commit_tree(token, merge_sha)

    for pr_summary in associated:
        pr_number = pr_summary.get("number")
        if not isinstance(pr_number, int):
            continue
        pr = _api_get(token, f"/repos/{repository}/pulls/{pr_number}")
        head_sha = (pr.get("head") or {}).get("sha", "")
        if not head_sha:
            continue
        head_tree_sha = _commit_tree(token, head_sha)
        merge_fingerprint, merge_workflows, merge_build_id = _revision_scope(
            token, repository, merge_sha, component, version)
        head_fingerprint, head_workflows, head_build_id = _revision_scope(
            token, repository, head_sha, component, version)
        if not merged_pr_matches_tree(
            pr, repository=repository, merge_sha=merge_sha,
            merge_tree_sha=merge_tree_sha, head_tree_sha=head_tree_sha,
            component_inputs_match=merge_fingerprint == head_fingerprint,
        ):
            continue
        if merge_workflows != head_workflows or merge_build_id != head_build_id:
            continue
        original_build_proven = _verified_original_build(
            token, repository, head_build_id, component, version)

        query = urllib.parse.urlencode(
            {"head_sha": head_sha, "event": "pull_request", "per_page": PER_PAGE}
        )
        runs = _pages(token, f"/repos/{repository}/actions/runs?{query}", "workflow_runs")
        ci_runs = [run for run in runs if run.get("name") == "CI PR"]
        component_runs = [run for run in runs if run.get("name") in head_workflows
                          and head_workflows.get(run.get("name")) == run.get("path")]

        jobs_by_run: dict[int, list[dict[str, Any]]] = {}
        artifacts_by_run: dict[int, set[str]] = {}
        for run in component_runs:
            run_id = run.get("id")
            if not isinstance(run_id, int):
                continue
            jobs_by_run[run_id] = _pages(
                token,
                f"/repos/{repository}/actions/runs/{run_id}/jobs",
                "jobs",
            )
            artifacts = _pages(
                token,
                f"/repos/{repository}/actions/runs/{run_id}/artifacts",
                "artifacts",
            )
            artifacts_by_run[run_id] = {
                item.get("name", "")
                for item in artifacts
                if not item.get("expired", False)
            }

        reusable = select_reusable_test_run(
            runs=component_runs,
            ci_runs=ci_runs,
            jobs_by_run=jobs_by_run,
            artifacts_by_run=artifacts_by_run,
            repository=repository,
            head_sha=head_sha,
            component=component,
            version=version,
            allowed_workflows=head_workflows,
            reused_build_proven=original_build_proven,
        )
        if reusable is not None:
            if provenance is not None:
                built_here = _successful_jobs_for_component(jobs_by_run[reusable], component, version)
                provenance["build_run_id"] = str(reusable) if built_here else head_build_id
            return reusable, (f"Reusing actual PR Test artifacts from run {reusable}; "
                              f"component_inputs={head_fingerprint}, original_build_run={head_build_id or 'same-run'}.")

    return None, "No matching component-scoped PR Test artifact was proven; running normal lifecycle."


def main() -> int:
    token = os.environ.get("GITHUB_TOKEN", "")
    repository = os.environ.get("GITHUB_REPOSITORY", "")
    merge_sha = os.environ.get("GITHUB_SHA", "")
    component = os.environ.get("COMPONENT", "")
    version = os.environ.get("VERSION", "")
    output = Path(os.environ["GITHUB_OUTPUT"])
    summary = Path(os.environ["GITHUB_STEP_SUMMARY"])

    provenance: dict[str, str] = {}
    reusable_run: int | None = None
    message = "Missing API context; running normal lifecycle."
    try:
        if token and repository and merge_sha and component and version:
            reusable_run, message = find_reusable_test_run(
                token=token,
                repository=repository,
                merge_sha=merge_sha,
                component=component,
                version=version,
                provenance=provenance,
            )
    except (OSError, ValueError, KeyError, urllib.error.URLError, json.JSONDecodeError) as error:
        # Optimization failures must never bypass the normal CI path.
        message = f"PR artifact reuse lookup unavailable ({type(error).__name__}); running normal lifecycle."

    with output.open("a", encoding="utf-8") as stream:
        stream.write(f"test_run_id={reusable_run or ''}\n")
        stream.write("build_run_id=" + (provenance.get("build_run_id", "") if reusable_run else "") + "\n")
    with summary.open("a", encoding="utf-8") as stream:
        stream.write(message + "\n")
    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
