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
  tez|hive|spark|hbase) ;;
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
  sha256sum -c evidence/SHA256SUMS
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
find "${TESTED_RPMS_DIR}/rpms" -maxdepth 1 -type f -name '*.rpm' \
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
