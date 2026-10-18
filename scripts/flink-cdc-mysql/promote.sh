#!/usr/bin/env bash
# Called only after this run's actual clean install and recovery test succeeds.
set -euo pipefail
: "${GITHUB_WORKSPACE:?}"
: "${GITHUB_REPOSITORY:?}"
: "${GITHUB_RUN_ID:?}"
: "${GITHUB_SHA:?}"
: "${BUILD_RUN_ID:?}"
source_root="$GITHUB_WORKSPACE"
checkout="$source_root/repository"
evidence="$source_root/test-evidence/evidence.md"
grep -qx 'status: PASS' "$evidence"
grep -qx "test_run_id: $GITHUB_RUN_ID" "$evidence"
grep -qx "build_run_id: $BUILD_RUN_ID" "$evidence"
grep -qx 'source_identity: 06581fc73b84b1da45fccf93441d96a118d9bfc1' "$evidence"
for field in clean_install snapshot_exact_rows insert_update_delete_exact_rows completed_checkpoint savepoint_restore_path restored_exact_rows; do
  grep -qx "$field: PASS" "$evidence"
done
(cd "$source_root/candidate" && sha256sum -c evidence/SHA256SUMS)
cd "$checkout"
git switch -c "ci/rpm-repo-flink-cdc-mysql-3.4.0-$GITHUB_RUN_ID"
target=repo/openeuler-22.03-lts-sp4/bigtop-3.6/flink-cdc-mysql/3.4.0
if [[ -f "$target/manifest.yaml" ]]; then
  python3 - "$target" "$source_root" <<'PY'
import importlib.util
from pathlib import Path
import sys
target, source = map(Path, sys.argv[1:])
spec = importlib.util.spec_from_file_location("repo_check", source / "scripts/ci/check-component-repo-fast-path.py")
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)
manifest = check.fields(target / "manifest.yaml")
assert manifest["source_identity"] == "06581fc73b84b1da45fccf93441d96a118d9bfc1"
assert manifest["component"] == "flink-cdc-mysql" and manifest["version"] == "3.4.0"
assert manifest["test_status"] == "PASS"
checksums = check.parse_checksum_file(target / "SHA256SUMS")
candidate = {Path(line.split()[1]).name: line.split()[0]
             for line in (source / "candidate/evidence/SHA256SUMS").read_text().splitlines()}
assert checksums == candidate, "existing published RPM differs; review a new release revision"
entries = check.validate_repomd(target)
primary = next(e["location"] for e in entries if e["type"] == "primary")
check.validate_primary(target, primary, "flink-cdc-mysql", "3.4.0",
                       {"bigdata-flink-cdc-mysql"}, checksums)
PY
  echo "The same verified connector RPM is already published."
  exit 0
fi
mkdir -p "$target"
cp "$source_root"/candidate/rpms/*.rpm "$target/"
(cd "$target" && sha256sum ./*.rpm > SHA256SUMS)
docker run --rm -v "$checkout/$target:/target" openeuler/openeuler:22.03-lts-sp4 \
  bash -c 'set -euo pipefail; dnf -y install createrepo_c; createrepo_c --no-database /target'
compatibility_identity="$(sha256sum "$source_root/scripts/flink-cdc-mysql/contract.json" | cut -d ' ' -f 1)"
cat > "$target/manifest.yaml" <<EOF
schema: bigdata.rpm-repo/v2
component: flink-cdc-mysql
version: 3.4.0
bigtop_version: 3.6.0
artifact_type: integration-rpm
test_profile: mysql-snapshot-changelog-savepoint
jdk: 11
jdk_package: java-11-openjdk-devel
build_run_id: $BUILD_RUN_ID
test_run_id: $GITHUB_RUN_ID
tested_artifact_run_id: $GITHUB_RUN_ID
promotion_workflow_commit: $GITHUB_SHA
source_identity: 06581fc73b84b1da45fccf93441d96a118d9bfc1
compatibility_identity: $compatibility_identity
compatibility_identity_format: flink-cdc-mysql-contract-json/v1
os: openEuler 22.03 LTS SP4
rpm_count: 1
test_status: PASS
repository_layout: split-runtime/v2
EOF
cp "$evidence" "$target/test-evidence.md"
cp "$source_root/scripts/flink-cdc-mysql/contract.json" "$target/contract.json"
git lfs install --local
git add -- "$target"
git diff --cached --check
rpm_path="$(find "$target" -maxdepth 1 -name '*.rpm' -type f)"
[[ "$(git check-attr filter -- "$rpm_path")" == *'filter: lfs' ]]
[[ "$(git cat-file -s ":$rpm_path")" -lt 300 ]]
git -c user.name='github-actions[bot]' \
  -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
  commit -m 'repo: add tested Flink CDC MySQL 3.4.0 connector RPM'
git push origin HEAD
body_file="$(mktemp)"
cat > "$body_file" <<EOF
Publishes the connector-only RPM tested in run $GITHUB_RUN_ID from RPM build $BUILD_RUN_ID.
The clean openEuler test verified exact snapshot and I/U/D rows, a completed checkpoint,
and restoration from the exact savepoint with offline MySQL changes.
MySQL's JDBC driver is a test fixture dependency and is excluded from this RPM.
Includes RPM checksums, repodata, immutable source identity and archived test evidence.
This PR requires review and merge; the workflow does not merge it.
EOF
gh pr create --repo "$GITHUB_REPOSITORY" --base main \
  --title 'repo: add tested Flink CDC MySQL 3.4.0 RPM' --body-file "$body_file"
