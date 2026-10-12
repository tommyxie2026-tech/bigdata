#!/usr/bin/env python3
"""Reuse a successful same-tree PR test artifact after its merge to main.

This is a fail-closed optimization: any missing provenance, required CI result,
component Build/Test job, or uploaded test artifact falls back to a fresh build.
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


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
) -> bool:
    head_repo = (pull_request.get("head") or {}).get("repo") or {}
    base = pull_request.get("base") or {}
    return bool(
        pull_request.get("merged")
        and pull_request.get("merge_commit_sha") == merge_sha
        and base.get("ref") == "main"
        and head_repo.get("full_name", "").lower() == repository.lower()
        and merge_tree_sha
        and merge_tree_sha == head_tree_sha
        and (pull_request.get("head") or {}).get("sha")
    )


def _successful_jobs_for_component(
    jobs: list[dict[str, Any]], component: str, version: str
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
        and all(job.get("status") == "completed" and job.get("conclusion") == "success" for job in matched[stage])
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
) -> bool:
    head_repo = run.get("head_repository") or {}
    required_artifacts = {
        f"{component}-{version}-test-evidence",
        f"{component}-{version}-tested-rpms",
    }
    return bool(
        run.get("name") == "Build Components"
        and run.get("event") == "pull_request"
        and run.get("status") == "completed"
        and run.get("conclusion") == "success"
        and run.get("head_sha") == head_sha
        and head_repo.get("full_name", "").lower() == repository.lower()
        and required_artifacts.issubset(artifact_names)
        and _successful_jobs_for_component(jobs, component, version)
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
) -> int | None:
    ci_passed = any(
        run.get("name") == "CI PR"
        and run.get("event") == "pull_request"
        and run.get("head_sha") == head_sha
        and run.get("status") == "completed"
        and run.get("conclusion") == "success"
        and (run.get("head_repository") or {}).get("full_name", "").lower() == repository.lower()
        for run in ci_runs
    )
    if not ci_passed:
        return None

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


def find_reusable_test_run(
    *,
    token: str,
    repository: str,
    merge_sha: str,
    component: str,
    version: str,
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
        if not merged_pr_matches_tree(
            pr,
            repository=repository,
            merge_sha=merge_sha,
            merge_tree_sha=merge_tree_sha,
            head_tree_sha=head_tree_sha,
        ):
            continue

        query = urllib.parse.urlencode(
            {"head_sha": head_sha, "event": "pull_request", "per_page": PER_PAGE}
        )
        runs = _pages(token, f"/repos/{repository}/actions/runs?{query}", "workflow_runs")
        ci_runs = [run for run in runs if run.get("name") == "CI PR"]
        component_runs = [run for run in runs if run.get("name") == "Build Components"]

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
        )
        if reusable is not None:
            return reusable, f"Using successful same-tree PR Build/Test artifacts from run {reusable}."

    return None, "No matching merged-PR test artifact was proven; running a fresh Build/Test."


def main() -> int:
    token = os.environ.get("GITHUB_TOKEN", "")
    repository = os.environ.get("GITHUB_REPOSITORY", "")
    merge_sha = os.environ.get("GITHUB_SHA", "")
    component = os.environ.get("COMPONENT", "")
    version = os.environ.get("VERSION", "")
    output = Path(os.environ["GITHUB_OUTPUT"])
    summary = Path(os.environ["GITHUB_STEP_SUMMARY"])

    reusable_run: int | None = None
    message = "Missing API context; running a fresh Build/Test."
    try:
        if token and repository and merge_sha and component and version:
            reusable_run, message = find_reusable_test_run(
                token=token,
                repository=repository,
                merge_sha=merge_sha,
                component=component,
                version=version,
            )
    except (OSError, ValueError, KeyError, urllib.error.URLError, json.JSONDecodeError) as error:
        # Optimization failures must never bypass the normal CI path.
        message = f"PR artifact reuse lookup unavailable ({type(error).__name__}); running a fresh Build/Test."

    with output.open("a", encoding="utf-8") as stream:
        stream.write(f"test_run_id={reusable_run or ''}\n")
    with summary.open("a", encoding="utf-8") as stream:
        stream.write(message + "\n")
    print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
