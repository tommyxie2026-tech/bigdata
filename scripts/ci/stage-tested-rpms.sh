#!/usr/bin/env bash
set -euo pipefail

COMPONENT="${COMPONENT:?COMPONENT is required}"
VERSION="${VERSION:?VERSION is required}"
TEST_RUN_ID="${TEST_RUN_ID:?TEST_RUN_ID is required}"
SOURCE_SHA="${SOURCE_SHA:?SOURCE_SHA is required}"
REPO_CHECKOUT="${REPO_CHECKOUT:?REPO_CHECKOUT is required}"
TESTED_RPMS_DIR="${TESTED_RPMS_DIR:-/tmp/tested-rpms}"
TEST_EVIDENCE_DIR="${TEST_EVIDENCE_DIR:-/tmp/test-evidence}"

case "${COMPONENT}" in
  zookeeper|hadoop|tez|hive|spark|hbase) ;;
  *) echo "Unsupported component: ${COMPONENT}" >&2; exit 2 ;;
esac
[[ "${VERSION}" =~ ^[0-9]+(\.[0-9]+)+$ ]]
[[ "${TEST_RUN_ID}" =~ ^[0-9]+$ ]]
[[ "${SOURCE_SHA}" =~ ^[0-9a-f]{40}$ ]]

grep -qx 'status: PASS' "${TEST_EVIDENCE_DIR}/evidence.md"
grep -qx "component: ${COMPONENT}" "${TEST_EVIDENCE_DIR}/evidence.md"
grep -qx "version: ${VERSION}" "${TEST_EVIDENCE_DIR}/evidence.md"
(
  cd "${TESTED_RPMS_DIR}"
  # Older ZooKeeper/Hadoop build artifacts recorded container-absolute RPM
  # paths. Artifact download places all RPMs in rpms/, so normalize each
  # checksum entry before checking the exact uploaded file set and its hashes.
  normalized_checksums="$(mktemp)"
  trap 'rm -f "${normalized_checksums}"' EXIT
  awk 'NF >= 2 {
    name = $2
    sub(/^.*\//, "", name)
    if (name != ".rpm") print $1 "  rpms/" name
  }' evidence/SHA256SUMS > "${normalized_checksums}"
  [[ -s "${normalized_checksums}" ]]
  diff -u \
    <(awk '{print $2}' "${normalized_checksums}" | LC_ALL=C sort) \
    <(find rpms -maxdepth 1 -type f -name '*.rpm' ! -name '.rpm' \
      -print | LC_ALL=C sort)
  sha256sum -c "${normalized_checksums}"
)

target="${REPO_CHECKOUT}/repo/openeuler-22.03-lts-sp4/bigtop-3.6/${COMPONENT}/${VERSION}"
if [[ -e "${target}" ]]; then
  grep -qx "component: ${COMPONENT}" "${target}/manifest.yaml"
  grep -qx "version: ${VERSION}" "${target}/manifest.yaml"
  grep -qx 'test_status: PASS' "${target}/manifest.yaml"
  echo "Already promoted: ${target}"
  exit 0
fi
mkdir -p "${target}"
find "${TESTED_RPMS_DIR}/rpms" -maxdepth 1 -type f -name '*.rpm' ! -name '.rpm' \
  -exec cp {} "${target}/" \;
rpm_count="$(find "${target}" -maxdepth 1 -type f -name '*.rpm' | wc -l | tr -d ' ')"
[[ "${rpm_count}" -gt 0 ]]

(
  cd "${target}"
  find . -maxdepth 1 -type f -name '*.rpm' -print0 | sort -z \
    | xargs -0 -r sha256sum > SHA256SUMS
  createrepo_c .
)

cat > "${target}/manifest.yaml" <<EOF
schema: bigdata.rpm-repo/v1
component: ${COMPONENT}
version: ${VERSION}
bigtop_version: 3.6.0
os: openEuler 22.03 LTS SP4
promotion_workflow_commit: ${SOURCE_SHA}
tested_artifact_run_id: ${TEST_RUN_ID}
rpm_count: ${rpm_count}
test_status: PASS
EOF

echo "Staged ${rpm_count} verified RPMs in ${target}"
