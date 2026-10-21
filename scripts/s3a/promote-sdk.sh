#!/usr/bin/env bash
# Publish only artifacts from an actual successful clean install and recovery test.
set -euo pipefail
: "${GITHUB_WORKSPACE:?}"
: "${GITHUB_REPOSITORY:?}"
: "${GITHUB_RUN_ID:?}"
: "${GITHUB_SHA:?}"
: "${BUILD_RUN_ID:?}"
TEST_RUN_ID="${TEST_RUN_ID:-$GITHUB_RUN_ID}"
source_root="$GITHUB_WORKSPACE"
checkout="$source_root/repository"
evidence="$source_root/test-evidence/release-evidence.json"
python3 - "$source_root" "$BUILD_RUN_ID" "$TEST_RUN_ID" <<'PY'
import json,sys
from pathlib import Path
root=Path(sys.argv[1]);sys.path.insert(0,str(root/'scripts/s3a'))
from release import validate
e=json.loads((root/'test-evidence/release-evidence.json').read_text())
validate(e['s3a'],e['api'])
assert e['status']=='PASS' and e['build_run_id']==sys.argv[2] and e['test_run_id']==sys.argv[3]
contract=json.loads((root/'candidate/evidence/sdk-contract.json').read_text())
assert contract==json.loads((root/'scripts/s3a/sdk-contract.json').read_text())
assert contract['sha256']=='db4b55f24ad1b4e70f17eb1717a4de76a8dadc5a27d764be7c44ff67b2c1c677'
assert len(list((root/'candidate/rpms').glob('*.rpm')))==1
assert (root/'candidate/rpms/bigdata-hadoop-aws-sdk-2.35.4-1.oe2203sp4.noarch.rpm').is_file()
PY
(cd "$source_root/candidate" && sha256sum -c evidence/SHA256SUMS)
cd "$checkout"
git switch -c "ci/rpm-repo-hadoop-aws-sdk-2.35.4-$GITHUB_RUN_ID"
target=repo/openeuler-22.03-lts-sp4/bigtop-3.6/hadoop-aws-sdk/2.35.4
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
assert manifest["source_identity"] == "db4b55f24ad1b4e70f17eb1717a4de76a8dadc5a27d764be7c44ff67b2c1c677"
assert manifest["component"] == "hadoop-aws-sdk" and manifest["version"] == "2.35.4"
assert manifest["test_status"] == "PASS"
checksums = check.parse_checksum_file(target / "SHA256SUMS")
candidate = {Path(line.split()[1]).name: line.split()[0]
             for line in (source / "candidate/evidence/SHA256SUMS").read_text().splitlines()}
assert checksums == candidate, "existing published RPM differs; review a new release revision"
entries = check.validate_repomd(target)
primary = next(e["location"] for e in entries if e["type"] == "primary")
check.validate_primary(target, primary, "hadoop-aws-sdk", "2.35.4",
                       {"bigdata-hadoop-aws-sdk"}, checksums)
PY
  echo "The same verified connector RPM is already published."
  exit 0
fi
mkdir -p "$target"
cp "$source_root"/candidate/rpms/*.rpm "$target/"
(cd "$target" && sha256sum ./*.rpm > SHA256SUMS)
docker run --rm -v "$checkout/$target:/target" openeuler/openeuler:22.03-lts-sp4 \
  bash -c 'set -euo pipefail; dnf -y install createrepo_c; createrepo_c --no-database /target'
compatibility_identity="$(sha256sum "$source_root/scripts/s3a/sdk-contract.json" | cut -d ' ' -f 1)"
cat > "$target/manifest.yaml" <<EOF
schema: bigdata.rpm-repo/v2
component: hadoop-aws-sdk
version: 2.35.4
bigtop_version: 3.6.0
artifact_type: optional-dependency-rpm
test_profile: hadoop-s3a-https-multipart-restart
jdk: 8
jdk_package: java-1.8.0-openjdk-devel
build_run_id: $BUILD_RUN_ID
test_run_id: $TEST_RUN_ID
tested_artifact_run_id: $TEST_RUN_ID
promotion_workflow_commit: $GITHUB_SHA
source_identity: db4b55f24ad1b4e70f17eb1717a4de76a8dadc5a27d764be7c44ff67b2c1c677
compatibility_identity: $compatibility_identity
compatibility_identity_format: hadoop-aws-sdk-contract-json/v1
os: openEuler 22.03 LTS SP4
rpm_count: 1
test_status: PASS
repository_layout: split-runtime/v2
EOF
cp "$evidence" "$target/test-evidence.json"
cp "$source_root/scripts/s3a/sdk-contract.json" "$target/contract.json"
git lfs install --local
git add -- "$target"
git diff --cached --check
rpm_path="$(find "$target" -maxdepth 1 -name '*.rpm' -type f)"
[[ "$(git check-attr filter -- "$rpm_path")" == *'filter: lfs' ]]
[[ "$(git cat-file -s ":$rpm_path")" -lt 300 ]]
git -c user.name='github-actions[bot]' \
  -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
  commit -m 'repo: add tested Hadoop S3A optional AWS SDK 2.35.4 RPM'
git push origin HEAD
body_file="$(mktemp)"
cat > "$body_file" <<EOF
Publishes the optional AWS SDK v2 dependency tested in run $TEST_RUN_ID from packaging run $BUILD_RUN_ID.
Hadoop itself was not recompiled. Clean openEuler installation verified S3A HTTPS, exact bytes,
list/seek/rename, three-part upload, actual 403 permission rejection and fresh-JVM reads after restart.
Includes the upstream binary identity, licensing, RPM checksum, repodata and strict test evidence.
This PR requires review and merge; the workflow does not merge it.
EOF
gh pr create --repo "$GITHUB_REPOSITORY" --base main \
  --title 'repo: add tested Hadoop S3A optional AWS SDK 2.35.4 RPM' --body-file "$body_file"
