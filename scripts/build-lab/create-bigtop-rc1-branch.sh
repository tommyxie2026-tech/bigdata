#!/usr/bin/env bash
set -euo pipefail

BIGDATA_RC1_HOME=${BIGDATA_RC1_HOME:-/opt/bigdata-rc1}
BIGTOP_DIR="$BIGDATA_RC1_HOME/src/bigtop"
BRANCH_NAME=${BRANCH_NAME:-bigdata-1.0-rc1-openeuler22-rpm}
OUT=${1:-validation/bigtop/rc1-adaptation-branch.md}

mkdir -p "$BIGDATA_RC1_HOME/src"

if [ ! -d "$BIGTOP_DIR/.git" ]; then
  git clone https://github.com/apache/bigtop.git "$BIGTOP_DIR"
fi

cd "$BIGTOP_DIR"

BASE_COMMIT=$(git rev-parse HEAD)

if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
  git checkout "$BRANCH_NAME"
else
  git checkout -b "$BRANCH_NAME"
fi

CURRENT_BRANCH=$(git branch --show-current)
STATUS_OUTPUT=$(git status --short)

mkdir -p "$(dirname "$OUT")"

{
  echo "# Bigtop RC1 Adaptation Branch Evidence"
  echo
  echo "## Metadata"
  echo
  echo '```yaml'
  echo "task: TASK-302"
  echo "issue: '#21'"
  echo "status: EXECUTED"
  echo "result: REVIEW_REQUIRED"
  echo '```'
  echo

  echo "## Branch"
  echo
  echo '```yaml'
  echo "base_project: apache/bigtop"
  echo "base_version_or_ref: REVIEW_REQUIRED"
  echo "base_commit: $BASE_COMMIT"
  echo "branch_name: $CURRENT_BRANCH"
  echo '```'
  echo

  echo "## Git Status"
  echo
  echo '```text'
  git status
  echo '```'
  echo

  echo "## Short Status"
  echo
  echo '```text'
  if [ -z "$STATUS_OUTPUT" ]; then
    echo "clean"
  else
    echo "$STATUS_OUTPUT"
  fi
  echo '```'
  echo

  echo "## Result Matrix"
  echo
  echo '```yaml'
  echo "bigtop_source_cloned: PASS"
  echo "base_commit_recorded: PASS"
  echo "branch_created: REVIEW_REQUIRED"
  echo "branch_name_verified: REVIEW_REQUIRED"
  echo "working_tree_clean_before_patch: REVIEW_REQUIRED"
  echo "adaptation_scope_confirmed: REVIEW_REQUIRED"
  echo '```'
  echo

  echo "## Decision"
  echo
  echo '```yaml'
  echo "result: REVIEW_REQUIRED"
  echo "next_action: Review branch/ref and update matrix to PASS/FAIL."
  echo '```'
} | tee "$OUT"
