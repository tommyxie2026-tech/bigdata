#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:?VERSION is required}"
TEST_RUN_ID="${TEST_RUN_ID:?TEST_RUN_ID is required}"
SOURCE_SHA="${SOURCE_SHA:?SOURCE_SHA is required}"
REPO_CHECKOUT="${REPO_CHECKOUT:?REPO_CHECKOUT is required}"
TESTED_RPMS_DIR="${TESTED_RPMS_DIR:-/tmp/tested-rpms}"
TEST_EVIDENCE_DIR="${TEST_EVIDENCE_DIR:-/tmp/test-evidence}"

[[ "${VERSION}" =~ ^[0-9]+(\.[0-9]+)+$ ]]
[[ "${TEST_RUN_ID}" =~ ^[0-9]+$ ]]
[[ "${SOURCE_SHA}" =~ ^[0-9a-f]{40}$ ]]
grep -qx 'status: PASS' "${TEST_EVIDENCE_DIR}/evidence.md"
grep -qx 'component: ambari' "${TEST_EVIDENCE_DIR}/evidence.md"
grep -qx "version: ${VERSION}" "${TEST_EVIDENCE_DIR}/evidence.md"

(
  cd "${TESTED_RPMS_DIR}"
  [[ -s evidence/SHA256SUMS ]]
  diff -u \
    <(awk '{print $2}' evidence/SHA256SUMS | LC_ALL=C sort) \
    <(find rpms -maxdepth 1 -type f -name '*.rpm' -print | LC_ALL=C sort)
  sha256sum -c evidence/SHA256SUMS
)

target="${REPO_CHECKOUT}/repo/openeuler-22.03-lts-sp4/ambari/${VERSION}"
if [[ -e "${target}" ]]; then
  grep -qx 'component: ambari' "${target}/manifest.yaml"
  grep -qx "version: ${VERSION}" "${target}/manifest.yaml"
  grep -qx 'test_status: PASS' "${target}/manifest.yaml"
  echo "Already promoted: ${target}"
  exit 0
fi
mkdir -p "${target}"

for rpm in "${TESTED_RPMS_DIR}"/rpms/*.rpm; do
  name="${rpm##*/}"
  case "${name}" in
    *.src.rpm|*-debuginfo-*|*-debugsource-*|*-devel-*|*-test-*|*-tests-*|*-doc-*|*-javadoc-*) ;;
    ambari-server-[0-9]*.rpm|ambari-agent-[0-9]*.rpm) cp "${rpm}" "${target}/${name}" ;;
  esac
done

server_count="$(find "${target}" -maxdepth 1 -type f -name 'ambari-server-[0-9]*.rpm' | wc -l | tr -d ' ')"
agent_count="$(find "${target}" -maxdepth 1 -type f -name 'ambari-agent-[0-9]*.rpm' | wc -l | tr -d ' ')"
rpm_count="$(find "${target}" -maxdepth 1 -type f -name '*.rpm' | wc -l | tr -d ' ')"
[[ "${server_count}" -eq 1 ]]
[[ "${agent_count}" -eq 1 ]]
[[ "${rpm_count}" -eq 2 ]]

(
  cd "${target}"
  find . -maxdepth 1 -type f -name '*.rpm' -print0 | sort -z \
    | xargs -0 -r sha256sum > SHA256SUMS
  createrepo_c --no-database .
)

cat > "${target}/manifest.yaml" <<EOF
schema: bigdata.rpm-repo/v1
component: ambari
version: ${VERSION}
ambari_version: ${VERSION}
os: openEuler 22.03 LTS SP4
promotion_workflow_commit: ${SOURCE_SHA}
tested_artifact_run_id: ${TEST_RUN_ID}
rpm_count: ${rpm_count}
test_status: PASS
repository_layout: ambari-runtime/v1
EOF

echo "Staged ${rpm_count} verified RPMs in ${target}"
