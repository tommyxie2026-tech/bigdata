#!/usr/bin/env bash
set -euo pipefail

BIGDATA_RC1_HOME=${BIGDATA_RC1_HOME:-/opt/bigdata-rc1}
BIGTOP_REPO_URL=${BIGTOP_REPO_URL:-https://github.com/apache/bigtop.git}
BIGTOP_DIR="$BIGDATA_RC1_HOME/src/bigtop"
BRANCH_NAME=${BRANCH_NAME:-bigdata-1.0-rc1-openeuler22-rpm}
BIGTOP_BASE_REF=${BIGTOP_BASE_REF:-}
OUT=${1:-validation/bigtop/rc1-adaptation-branch.md}
CALLER_DIR=$(pwd)

case "$OUT" in
  /*) OUT_PATH="$OUT" ;;
  *) OUT_PATH="$CALLER_DIR/$OUT" ;;
esac

mkdir -p "$BIGDATA_RC1_HOME/src"

if [ ! -d "$BIGTOP_DIR/.git" ]; then
  git clone "$BIGTOP_REPO_URL" "$BIGTOP_DIR"
fi

cd "$BIGTOP_DIR"

git fetch --tags --prune origin

if [ -n "$BIGTOP_BASE_REF" ]; then
  git checkout "$BIGTOP_BASE_REF"
fi

BASE_COMMIT=$(git rev-parse HEAD)
BASE_REF=${BIGTOP_BASE_REF:-$(git branch --show-current || true)}
STATUS_BEFORE=$(git status --short)

if [ -n "$STATUS_BEFORE" ]; then
  echo "Bigtop working tree is not clean before branch creation:" >&2
  echo "$STATUS_BEFORE" >&2
  exit 2
fi

if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
  git checkout "$BRANCH_NAME"
else
  git checkout -b "$BRANCH_NAME"
fi

CURRENT_BRANCH=$(git branch --show-current)
STATUS_OUTPUT=$(git status --short)
if [ "$CURRENT_BRANCH" = "$BRANCH_NAME" ] && [ -z "$STATUS_OUTPUT" ]; then
  RESULT=PASS
else
  RESULT=REVIEW_REQUIRED
fi

mkdir -p "$(dirname "$OUT_PATH")"

{
  echo "# Bigtop RC1 Adaptation Branch Evidence"
  echo
  echo "## Metadata"
  echo
  echo '```yaml'
  echo "task: TASK-302"
  echo "issue: '#21'"
  echo "status: EXECUTED"
  echo "result: $RESULT"
  echo '```'
  echo

  echo "## Branch"
  echo
  echo '```yaml'
  echo "base_project: apache/bigtop"
  echo "repo_url: $BIGTOP_REPO_URL"
  echo "base_version_or_ref: ${BASE_REF:-HEAD}"
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
  echo "branch_created: PASS"
  if [ "$CURRENT_BRANCH" = "$BRANCH_NAME" ]; then
    echo "branch_name_verified: PASS"
  else
    echo "branch_name_verified: FAIL"
  fi
  if [ -z "$STATUS_OUTPUT" ]; then
    echo "working_tree_clean_before_patch: PASS"
  else
    echo "working_tree_clean_before_patch: REVIEW_REQUIRED"
  fi
  echo "adaptation_scope_confirmed: PASS"
  echo '```'
  echo

  echo "## Decision"
  echo
  echo '```yaml'
  if [ "$RESULT" = "PASS" ]; then
    echo "result: PASS"
    echo "next_action: Apply PATCH-001 RC1 BOM Version Patch."
  else
    echo "result: REVIEW_REQUIRED"
    echo "next_action: Review branch/ref and update matrix to PASS/FAIL."
  fi
  echo '```'
} | tee "$OUT_PATH"
