#!/usr/bin/env python3
"""Unit contracts for safe reuse of merged PR Build/Test artifacts."""

from __future__ import annotations

import unittest

from reuse_merged_pr_test_artifacts import (
    merged_pr_matches_tree,
    select_reusable_test_run,
)


REPO = "tommyxie2026-tech/bigdata"
HEAD = "a" * 40
RUN_ID = 1234
COMPONENT = "flink"
VERSION = "1.20.1"


def pr() -> dict:
    return {
        "merged": True,
        "merge_commit_sha": "b" * 40,
        "base": {"ref": "main"},
        "head": {"sha": HEAD, "repo": {"full_name": REPO}},
    }


def run(name: str, run_id: int, *, conclusion: str = "success") -> dict:
    return {
        "name": name,
        "id": run_id,
        "event": "pull_request",
        "status": "completed",
        "conclusion": conclusion,
        "head_sha": HEAD,
        "head_repository": {"full_name": REPO},
    }


def jobs(*, build: str = "success", test: str = "success") -> list[dict]:
    return [
        {
            "name": "Flink 1.20.1 Build Test Release / Build flink 1.20.1 / Build flink 1.20.1",
            "status": "completed",
            "conclusion": build,
        },
        {
            "name": "Flink 1.20.1 Build Test Release / Test flink 1.20.1 / Test flink 1.20.1",
            "status": "completed",
            "conclusion": test,
        },
    ]


ARTIFACTS = {
    "flink-1.20.1-test-evidence",
    "flink-1.20.1-tested-rpms",
}


class MergedPrArtifactReuseTests(unittest.TestCase):
    def test_only_exact_merged_pr_tree_is_eligible(self) -> None:
        self.assertTrue(
            merged_pr_matches_tree(
                pr(),
                repository=REPO,
                merge_sha="b" * 40,
                merge_tree_sha="c" * 40,
                head_tree_sha="c" * 40,
            )
        )
        self.assertFalse(
            merged_pr_matches_tree(
                pr(),
                repository=REPO,
                merge_sha="b" * 40,
                merge_tree_sha="c" * 40,
                head_tree_sha="d" * 40,
            )
        )

    def test_fork_and_unmerged_prs_are_never_eligible(self) -> None:
        fork = pr()
        fork["head"]["repo"]["full_name"] = "contributor/bigdata"
        self.assertFalse(
            merged_pr_matches_tree(
                fork,
                repository=REPO,
                merge_sha="b" * 40,
                merge_tree_sha="c" * 40,
                head_tree_sha="c" * 40,
            )
        )
        unmerged = pr()
        unmerged["merged"] = False
        self.assertFalse(
            merged_pr_matches_tree(
                unmerged,
                repository=REPO,
                merge_sha="b" * 40,
                merge_tree_sha="c" * 40,
                head_tree_sha="c" * 40,
            )
        )

    def test_successful_ci_build_test_and_both_artifacts_are_reused(self) -> None:
        selected = select_reusable_test_run(
            runs=[run("Build Components", RUN_ID)],
            ci_runs=[run("CI PR", 9)],
            jobs_by_run={RUN_ID: jobs()},
            artifacts_by_run={RUN_ID: ARTIFACTS},
            repository=REPO,
            head_sha=HEAD,
            component=COMPONENT,
            version=VERSION,
        )
        self.assertEqual(selected, RUN_ID)

    def test_failed_build_or_test_is_not_reused(self) -> None:
        for component_jobs in (jobs(build="failure"), jobs(test="failure")):
            selected = select_reusable_test_run(
                runs=[run("Build Components", RUN_ID)],
                ci_runs=[run("CI PR", 9)],
                jobs_by_run={RUN_ID: component_jobs},
                artifacts_by_run={RUN_ID: ARTIFACTS},
                repository=REPO,
                head_sha=HEAD,
                component=COMPONENT,
                version=VERSION,
            )
            self.assertIsNone(selected)

    def test_skipped_test_is_not_reused(self) -> None:
        selected = select_reusable_test_run(
            runs=[run("Build Components", RUN_ID)],
            ci_runs=[run("CI PR", 9)],
            jobs_by_run={RUN_ID: jobs(test="skipped")},
            artifacts_by_run={RUN_ID: ARTIFACTS},
            repository=REPO,
            head_sha=HEAD,
            component=COMPONENT,
            version=VERSION,
        )
        self.assertIsNone(selected)

    def test_missing_artifact_or_ci_check_is_not_reused(self) -> None:
        no_ci = select_reusable_test_run(
            runs=[run("Build Components", RUN_ID)],
            ci_runs=[],
            jobs_by_run={RUN_ID: jobs()},
            artifacts_by_run={RUN_ID: ARTIFACTS},
            repository=REPO,
            head_sha=HEAD,
            component=COMPONENT,
            version=VERSION,
        )
        missing_evidence = select_reusable_test_run(
            runs=[run("Build Components", RUN_ID)],
            ci_runs=[run("CI PR", 9)],
            jobs_by_run={RUN_ID: jobs()},
            artifacts_by_run={RUN_ID: {"flink-1.20.1-tested-rpms"}},
            repository=REPO,
            head_sha=HEAD,
            component=COMPONENT,
            version=VERSION,
        )
        self.assertIsNone(no_ci)
        self.assertIsNone(missing_evidence)


if __name__ == "__main__":
    unittest.main(verbosity=2)
