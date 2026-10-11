#!/usr/bin/env bash
set -euo pipefail

workflow=.github/workflows/release-repo-tarball.yml
fail() {
  echo "Repository tarball release contract failed: $*" >&2
  exit 1
}

test -f "$workflow" || fail "missing $workflow"
grep -Eq '^on:[[:space:]]*$' "$workflow" || fail "workflow trigger is missing"
grep -Eq '^  workflow_dispatch:' "$workflow" || fail "release must be manually triggered"
grep -Fq 'lfs: true' "$workflow" || fail "checkout must materialize Git LFS objects"
grep -Fq 'contents: write' "$workflow" || fail "workflow needs release asset permission"
grep -Fq 'actions: read' "$workflow" || fail "workflow must verify CI evidence"
grep -Fq 'BIGDATA-1.0.0-RC1' "$workflow" || fail "unexpected RC1 tag"
grep -Fq 'check-component-repo-fast-path.py' "$workflow" || fail "component repository validation is missing"
grep -Fq 'sha256sum -c SHA256SUMS' "$workflow" || fail "RPM checksums must be verified"
grep -Fq 'sha256sum "${ARCHIVE_NAME}" > "${ARCHIVE_NAME}.sha256"' "$workflow" || fail "release checksum must use the downloadable asset name"
grep -Fq 'gzip -n' "$workflow" || fail "tarball must be deterministic"
grep -Fq 'gh release create' "$workflow" || fail "GitHub Release creation is missing"
grep -Fq -- '--prerelease' "$workflow" || fail "RC1 must be marked as a prerelease"
grep -Fq -- '-cf - repo | gzip -n' "$workflow" || fail "release archive must contain only repo/"

echo "Repository tarball release contract passed."
