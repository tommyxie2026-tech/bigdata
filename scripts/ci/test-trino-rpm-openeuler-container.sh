#!/usr/bin/env bash
set -euo pipefail
: "${COMPONENT:?COMPONENT required}"
: "${VERSION:?VERSION required}"
: "${BUILD_RUN_ID:?BUILD_RUN_ID required}"
: "${TEST_RUN_ID:?TEST_RUN_ID required}"
: "${ARTIFACT_ROOT:?ARTIFACT_ROOT required}"
: "${EVIDENCE_ROOT:?EVIDENCE_ROOT required}"
: "${COMPONENT_RUNTIME_PACKAGES:?COMPONENT_RUNTIME_PACKAGES required}"
REPO_DIR=/tmp/bigdata-trino-rpm-repo
LOG_DIR="${EVIDENCE_ROOT}/logs"
RPM_NAME="trino-server-rpm-${VERSION}.noarch.rpm"
[[ "${COMPONENT}" == trino && "${VERSION}" == 483 ]]
[[ "${COMPONENT_RUNTIME_PACKAGES}" == trino-server-rpm ]]
grep -qi openEuler /etc/os-release
mkdir -p "${EVIDENCE_ROOT}" "${LOG_DIR}" "${REPO_DIR}"
dnf -y install ca-certificates coreutils curl createrepo_c dnf-utils \
  findutils procps-ng python3 rpm shadow-utils sudo tar util-linux
source /workspace/scripts/ci/install-pinned-java-runtime.sh
build_evidence="${ARTIFACT_ROOT}/evidence/evidence.md"
[[ -s "${build_evidence}" ]]
grep -qx "component: ${COMPONENT}" "${build_evidence}"
grep -qx "version: ${VERSION}" "${build_evidence}"
grep -qx 'artifact_type: service-rpm' "${build_evidence}"
grep -qx 'test_profile: trino-single-node-smoke' "${build_evidence}"
grep -qx "build_run_id: ${BUILD_RUN_ID}" "${build_evidence}"
source_identity="$(awk -F ': ' '$1 == "source_identity" {print $2}' "${build_evidence}")"
compatibility_identity="$(awk -F ': ' '$1 == "compatibility_identity" {print $2}' "${build_evidence}")"
[[ "${source_identity}" =~ ^[0-9a-f]{40}$ ]]
[[ "${compatibility_identity}" =~ ^[0-9a-f]{64}$ ]]
rpm_files=("${ARTIFACT_ROOT}"/rpms/*.rpm)
[[ "${#rpm_files[@]}" -eq 1 && "${rpm_files[0]##*/}" == "${RPM_NAME}" ]]
[[ "$(rpm -qp --queryformat '%{NAME}' "${rpm_files[0]}")" == trino-server-rpm ]]
[[ "$(rpm -qp --queryformat '%{VERSION}' "${rpm_files[0]}")" == "${VERSION}" ]]
(cd "${ARTIFACT_ROOT}" && sha256sum -c evidence/SHA256SUMS)
cp -v "${rpm_files[0]}" "${REPO_DIR}/"
createrepo_c --no-database "${REPO_DIR}"
cat > /etc/yum.repos.d/trino-ci.repo <<EOF
[trino-ci]
name=Trino CI RPM
baseurl=file://${REPO_DIR}
enabled=1
gpgcheck=0
metadata_expire=0
EOF
dnf clean all
dnf -y --enablerepo=trino-ci install trino-server-rpm
rpm -q trino-server-rpm
cat > /etc/trino/config.properties <<'EOF'
coordinator=true
node-scheduler.include-coordinator=true
http-server.http.port=8080
discovery.uri=http://127.0.0.1:8080
EOF
grep -q '^catalog.config-dir=' /etc/trino/node.properties || \
  echo 'catalog.config-dir=/etc/trino/catalog' >> /etc/trino/node.properties
if grep -q '^-Xmx' /etc/trino/jvm.config; then sed -i '/^-Xmx/d' /etc/trino/jvm.config; fi
echo '-Xmx1G' >> /etc/trino/jvm.config
printf '\nexport JAVA_HOME=%q\nexport PATH="${JAVA_HOME}/bin:${PATH}"\n' "${JAVA_HOME}" >> /etc/trino/env.sh
mkdir -p /etc/trino/catalog /var/lib/trino/data /var/log/trino
chown -R trino:trino /var/lib/trino /var/log/trino
runuser -u trino -- env JAVA_HOME="${JAVA_HOME}" PATH="${JAVA_HOME}/bin:${PATH}" \
  /usr/lib/trino/bin/launcher run --etc-dir=/etc/trino >"${LOG_DIR}/launcher.log" 2>&1 &
trino_pid=$!
cleanup() { kill -TERM "${trino_pid}" 2>/dev/null || true; wait "${trino_pid}" 2>/dev/null || true; }
trap cleanup EXIT
health_ok=false
for attempt in $(seq 1 180); do
  if curl --fail --silent --show-error http://127.0.0.1:8080/v1/info -o "${LOG_DIR}/health.json" 2>/dev/null; then
    if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get("nodeVersion",{}).get("version")=="483" and not d.get("starting",False) else 1)' "${LOG_DIR}/health.json"; then health_ok=true; break; fi
  fi
  kill -0 "${trino_pid}" || { cat "${LOG_DIR}/launcher.log" >&2; exit 1; }
  if (( attempt % 30 == 0 )); then echo "Waiting for Trino startup (${attempt}/180 attempts)..."; fi
  sleep 2
done
[[ "${health_ok}" == true ]] || { cat "${LOG_DIR}/launcher.log" >&2; exit 1; }
echo 'health_check: PASS' > "${EVIDENCE_ROOT}/health-check.txt"
python3 - <<'PY' | tee "${LOG_DIR}/query.log"
import json, time, urllib.request
request = urllib.request.Request("http://127.0.0.1:8080/v1/statement", data=b"SELECT 1", method="POST", headers={"X-Trino-User": "ci", "Content-Type": "text/plain; charset=utf-8"})
with urllib.request.urlopen(request, timeout=30) as response:
    result = json.load(response)
deadline = time.monotonic() + 90
while result.get("nextUri"):
    if time.monotonic() > deadline:
        raise SystemExit("Trino SELECT 1 timed out")
    with urllib.request.urlopen(result["nextUri"], timeout=30) as response:
        result = json.load(response)
    if result.get("error"):
        raise SystemExit(json.dumps(result["error"]))
rows = result.get("data") or []
if result.get("error") or len(rows) != 1 or len(rows[0]) != 1 or str(rows[0][0]) != "1":
    raise SystemExit(f"unexpected Trino query response: {result}")
print(json.dumps({"query": "SELECT 1", "data": rows}))
PY
echo 'query: PASS' > "${EVIDENCE_ROOT}/query-result.txt"
cat > "${EVIDENCE_ROOT}/evidence.md" <<EOF
# CI Evidence — Trino RPM Install and SQL Smoke
schema: bigdata.evidence/v1
stage: test
component: ${COMPONENT}
version: ${VERSION}
artifact_type: service-rpm
test_profile: trino-single-node-smoke
source_identity: ${source_identity}
compatibility_identity: ${compatibility_identity}
build_run_id: ${BUILD_RUN_ID}
test_run_id: ${TEST_RUN_ID}
runtime_packages: trino-server-rpm
environment: openEuler-22.03-LTS-SP4-clean-container
repository: local-createrepo-c
package_manager: dnf
toolchain_jdk: ${COMPONENT_JDK}
jdk_package: ${COMPONENT_JDK_PACKAGE:-}
jdk_runtime_archive_sha256: ${JDK_RUNTIME_ARCHIVE_SHA256}
health_check: PASS
query: PASS
dnf_install: PASS
runtime_smoke: PASS
status: PASS
EOF
