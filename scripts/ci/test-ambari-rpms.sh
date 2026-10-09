#!/usr/bin/env bash
set -euo pipefail

AMBARI_VERSION="${AMBARI_VERSION:-3.0.0}"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-/artifact}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-/evidence}"
rpms="${ARTIFACT_ROOT}/rpms"
checksums="${ARTIFACT_ROOT}/evidence/SHA256SUMS"
mkdir -p "${EVIDENCE_ROOT}"

# The openEuler base image is intentionally minimal; install the tools used by
# artifact verification before touching the downloaded RPM set.
dnf -y install coreutils diffutils findutils gawk grep rpm

[[ -d "${rpms}" ]]
[[ -s "${checksums}" ]]

(
  cd "${ARTIFACT_ROOT}"
  diff -u \
    <(awk '{print $2}' evidence/SHA256SUMS | LC_ALL=C sort) \
    <(find rpms -maxdepth 1 -type f -name '*.rpm' -print | LC_ALL=C sort)
  sha256sum -c evidence/SHA256SUMS
)

server_count="$(find "${rpms}" -maxdepth 1 -type f -name 'ambari-server-[0-9]*.rpm' | wc -l | tr -d ' ')"
agent_count="$(find "${rpms}" -maxdepth 1 -type f -name 'ambari-agent-[0-9]*.rpm' | wc -l | tr -d ' ')"
rpm_count="$(find "${rpms}" -maxdepth 1 -type f -name '*.rpm' | wc -l | tr -d ' ')"
[[ "${server_count}" -eq 1 ]]
[[ "${agent_count}" -eq 1 ]]
[[ "${rpm_count}" -eq 2 ]]

if find "${rpms}" -maxdepth 1 -type f \( \
  -name '*.src.rpm' -o -name '*-debuginfo-*' -o -name '*-debugsource-*' \
  -o -name '*-devel-*' -o -name '*-test-*' -o -name '*-tests-*' \
  -o -name '*-doc-*' -o -name '*-javadoc-*' \) | grep -q .; then
  echo "Non-runtime RPM found in Ambari artifact" >&2
  exit 1
fi

set -- "${rpms}"/ambari-server-[0-9]*.rpm "${rpms}"/ambari-agent-[0-9]*.rpm
{
  dnf -y install python3-distro java-17-openjdk-devel
  dnf -y install "$@"
  rpm -q ambari-server ambari-agent
  ambari-server --version
  ambari-agent --version
} 2>&1 | tee "${EVIDENCE_ROOT}/install-smoke.log"

cat > "${EVIDENCE_ROOT}/evidence.md" <<EOF
# CI Evidence — Ambari RPM Install Smoke

schema: bigdata.evidence/v1
stage: test
component: ambari
version: ${AMBARI_VERSION}
os: openEuler 22.03 LTS SP4
checksums: PASS
server_package: PASS
agent_package: PASS
server_version_command: PASS
agent_version_command: PASS
status: PASS
EOF

cat "${EVIDENCE_ROOT}/evidence.md"
