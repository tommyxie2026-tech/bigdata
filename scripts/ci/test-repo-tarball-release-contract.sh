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

stage_script=scripts/ci/stage-tested-rpms.sh
test -f "$stage_script" || fail "RPM repository staging script is missing"
for empty_manifest_key in \
  jdk_runtime_archive_sha256 source_identity compatibility_identity; do
  if grep -Eq "^[[:space:]]*${empty_manifest_key}:" "$stage_script"; then
    fail "optional manifest key must not be written unconditionally: $empty_manifest_key"
  fi
done
grep -Fq 'if [[ -n "${JDK_RUNTIME_ARCHIVE_SHA256}" ]]; then' "$stage_script" \
  || fail "JDK archive checksum must be emitted only when configured"
grep -Fq 'if [[ -n "${SOURCE_IDENTITY}" ]]; then' "$stage_script" \
  || fail "source identity must be emitted only when available"
grep -Fq 'if [[ -n "${COMPATIBILITY_IDENTITY}" ]]; then' "$stage_script" \
  || fail "compatibility identity must be emitted only when available"
grep -Fq 'jdk_runtime_archive_sha256: %s\n' "$stage_script" \
  || fail "JDK archive checksum must be appended without empty trailing fields"
echo "Repository tarball release contract passed."
