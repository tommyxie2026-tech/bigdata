#!/usr/bin/env bash
set -euo pipefail

: "${COMPONENT:?COMPONENT is required}"
: "${VERSION:?VERSION is required}"
: "${BUILD_RUN_ID:?BUILD_RUN_ID is required}"
: "${TEST_RUN_ID:?TEST_RUN_ID is required}"
: "${ARTIFACT_ROOT:?ARTIFACT_ROOT is required}"
: "${EVIDENCE_ROOT:?EVIDENCE_ROOT is required}"
: "${COMPONENT_RUNTIME_PACKAGES:?COMPONENT_RUNTIME_PACKAGES is required}"
: "${COMPONENT_COMPATIBILITY_IDENTITY:?COMPONENT_COMPATIBILITY_IDENTITY is required}"
: "${COMPONENT_JDK_RUNTIME_ARCHIVE_URL:?COMPONENT_JDK_RUNTIME_ARCHIVE_URL is required}"
: "${COMPONENT_JDK_RUNTIME_ARCHIVE_SHA256:?COMPONENT_JDK_RUNTIME_ARCHIVE_SHA256 is required}"

[[ "${COMPONENT}" == hue && "${VERSION}" == 4.11.0 ]]
[[ "${TEST_PROFILE}" == hue-single-node-smoke ]]
[[ "${ARTIFACT_TYPE}" == service-rpm ]]
[[ "${COMPONENT_RUNTIME_PACKAGES}" == bigdata-hue-server ]]
[[ "${EXPECTED_SOURCE_IDENTITY}" == 65d9e489f400ac151029b33c5a2bd9df31e167da ]]
grep -qi openEuler /etc/os-release

REPO_DIR=/tmp/bigdata-hue-rpm-repo
LOG_DIR="${EVIDENCE_ROOT}/logs"
RPM_NAME="bigdata-hue-server-${VERSION}-1.oe2203sp4.x86_64.rpm"
mkdir -p "${REPO_DIR}" "${EVIDENCE_ROOT}" "${LOG_DIR}"
dnf -y install ca-certificates coreutils createrepo_c curl dnf-utils \
  findutils procps-ng python3 rpm shadow-utils sudo tar util-linux
source /workspace/scripts/ci/install-pinned-java-runtime.sh

build_evidence="${ARTIFACT_ROOT}/evidence/evidence.md"
[[ -s "${build_evidence}" ]]
grep -qx "component: ${COMPONENT}" "${build_evidence}"
grep -qx "version: ${VERSION}" "${build_evidence}"
grep -qx 'artifact_type: service-rpm' "${build_evidence}"
grep -qx 'test_profile: hue-single-node-smoke' "${build_evidence}"
grep -qx "build_run_id: ${BUILD_RUN_ID}" "${build_evidence}"
source_identity="$(awk -F ': ' '$1 == "source_identity" {print $2}' "${build_evidence}")"
compatibility_identity="$(awk -F ': ' '$1 == "compatibility_identity" {print $2}' "${build_evidence}")"
[[ "${source_identity}" == "${EXPECTED_SOURCE_IDENTITY}" ]]
[[ "${compatibility_identity}" == "${COMPONENT_COMPATIBILITY_IDENTITY}" ]]
grep -qx 'status: PASS' "${build_evidence}"

rpm_files=("${ARTIFACT_ROOT}"/rpms/*.rpm)
[[ "${#rpm_files[@]}" -eq 1 && "${rpm_files[0]##*/}" == "${RPM_NAME}" ]]
[[ "$(rpm -qp --queryformat '%{NAME}' "${rpm_files[0]}")" == bigdata-hue-server ]]
[[ "$(rpm -qp --queryformat '%{VERSION}' "${rpm_files[0]}")" == "${VERSION}" ]]
[[ "$(rpm -qp --queryformat '%{ARCH}' "${rpm_files[0]}")" == x86_64 ]]
(cd "${ARTIFACT_ROOT}" && sha256sum -c evidence/SHA256SUMS)
cp -v "${rpm_files[0]}" "${REPO_DIR}/"
createrepo_c --no-database "${REPO_DIR}"

dependency_index=0
IFS=',' read -r -a dependency_paths <<< "${DEPENDENCY_REPO_PATHS:-}"
for dependency_path in "${dependency_paths[@]}"; do
  [[ -n "${dependency_path}" ]] || continue
  dependency_repo="/dependency-repos/${dependency_path}"
  [[ -f "${dependency_repo}/repodata/repomd.xml" ]] || {
    echo "Missing dependency repository metadata: ${dependency_repo}" >&2
    exit 1
  }
  cat > "/etc/yum.repos.d/hue-dependency-${dependency_index}.repo" <<EOF
[hue-dependency-${dependency_index}]
name=Hue lifecycle dependency ${dependency_path}
baseurl=file://${dependency_repo}
enabled=1
gpgcheck=0
repo_gpgcheck=0
metadata_expire=0
EOF
  dependency_index=$((dependency_index + 1))
done
cat > /etc/yum.repos.d/hue-ci.repo <<EOF
[hue-ci]
name=Hue CI RPM
baseurl=file://${REPO_DIR}
enabled=1
gpgcheck=0
metadata_expire=0
EOF
dnf clean all
dnf -y --enablerepo=hue-ci install bigdata-hue-server trino-server-rpm
rpm -q bigdata-hue-server trino-server-rpm

test -x /usr/share/hue/build/venvs/python3.9/bin/hue
test -s /etc/hue/hue.ini
grep -q '^/usr/share/hue/build/venvs/python3.9/bin/hue$' /usr/libexec/hue/hue-server
sed -i \
  -e "s|^secret_key=.*|secret_key=bigdata-hue-ci-disposable-key-2026|" \
  -e 's|^## engine=sqlite3$|engine=sqlite3|' \
  -e 's|^## name=desktop/desktop.db$|name=/var/lib/hue/hue.db|' \
  /etc/hue/hue.ini
install -d -o hue -g hue -m 0750 /var/lib/hue /var/log/hue
runuser -u hue -- env HUE_CONF_DIR=/etc/hue HOME=/var/lib/hue \
  /usr/share/hue/build/venvs/python3.9/bin/hue migrate \
  2>&1 | tee "${LOG_DIR}/hue-migrate.log"

cat > /etc/trino/config.properties <<'EOF'
coordinator=true
node-scheduler.include-coordinator=true
http-server.http.port=8080
discovery.uri=http://127.0.0.1:8080
EOF
cat > /etc/trino/node.properties <<'EOF'
node.environment=bigdata-ci
node.id=bigdata-ci-trino
node.data-dir=/var/lib/trino/data
EOF
cat > /etc/trino/jvm.config <<'EOF'
-server
-Xmx1G
-XX:+UseG1GC
EOF
mkdir -p /etc/trino/catalog /var/lib/trino/data /var/log/trino
chown -R trino:trino /var/lib/trino /var/log/trino
runuser -u trino -- env JAVA_HOME="${JAVA_HOME}" PATH="${JAVA_HOME}/bin:${PATH}" \
  /usr/lib/trino/bin/launcher run --etc-dir=/etc/trino \
  >"${LOG_DIR}/trino.log" 2>&1 &
trino_pid=$!
hue_pid=''
cleanup() {
  if [[ -n "${hue_pid}" ]]; then
    kill -TERM "${hue_pid}" 2>/dev/null || true
    wait "${hue_pid}" 2>/dev/null || true
  fi
  kill -TERM "${trino_pid}" 2>/dev/null || true
  wait "${trino_pid}" 2>/dev/null || true
}
trap cleanup EXIT

trino_ready=false
for attempt in $(seq 1 180); do
  if curl --fail --silent http://127.0.0.1:8080/v1/info -o "${LOG_DIR}/trino-health.json"; then
    if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get("nodeVersion",{}).get("version")=="483" and not d.get("starting",False) else 1)' "${LOG_DIR}/trino-health.json"; then
      trino_ready=true
      break
    fi
  fi
  kill -0 "${trino_pid}" || { cat "${LOG_DIR}/trino.log" >&2; exit 1; }
  sleep 2
done
[[ "${trino_ready}" == true ]] || { cat "${LOG_DIR}/trino.log" >&2; exit 1; }

runuser -u hue -- env HUE_CONF_DIR=/etc/hue HOME=/var/lib/hue \
  /usr/libexec/hue/hue-server >"${LOG_DIR}/hue-server.log" 2>&1 &
hue_pid=$!
hue_ready=false
for attempt in $(seq 1 120); do
  status="$(curl --silent --output "${LOG_DIR}/hue-health.html" --write-out '%{http_code}' \
    http://127.0.0.1:8888/ || true)"
  if [[ "${status}" =~ ^(200|302)$ ]]; then
    hue_ready=true
    break
  fi
  kill -0 "${hue_pid}" || { cat "${LOG_DIR}/hue-server.log" >&2; exit 1; }
  sleep 2
done
[[ "${hue_ready}" == true ]] || { cat "${LOG_DIR}/hue-server.log" >&2; exit 1; }
echo 'health_check: PASS' > "${EVIDENCE_ROOT}/health-check.txt"

# Exercise Hue's own Trino connector against the real single-node Trino service;
# a direct HTTP check alone is not considered a backend smoke test.
cd /usr/share/hue
runuser -u hue -- env HUE_CONF_DIR=/etc/hue HOME=/var/lib/hue \
  /usr/share/hue/build/venvs/python3.9/bin/hue shell \
  >"${LOG_DIR}/hue-trino-query.log" 2>&1 <<'PY'
import os
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "desktop.settings")
import django
django.setup()
from django.contrib.auth import get_user_model
from notebook.connectors.trino import TrinoApi

user_model = get_user_model()
user, _ = user_model.objects.get_or_create(username="bigdata-ci")
api = TrinoApi(
    user,
    interpreter={
        "name": "trino",
        "options": {"url": "http://127.0.0.1:8080"},
    },
)
snippet = {
    "database": "system.runtime",
    "statement": "SELECT 42 AS hue_ci_value",
    "dialect": "trino",
    "result": {"handle": {}},
}
response = api.execute(None, snippet)
rows = list(response["result"].get("data") or [])
next_uri = response.get("next_uri")
while next_uri:
    status = api.trino_request.process(api.trino_request.get(next_uri))
    rows.extend(status.rows or [])
    next_uri = status.next_uri
if not any(str(cell) == "42" for row in rows for cell in row):
    raise SystemExit(f"Hue Trino connector returned no expected row: {rows!r}")
print("hue_trino_connector_query: PASS")
PY
grep -q 'hue_trino_connector_query: PASS' "${LOG_DIR}/hue-trino-query.log"
echo 'hue_trino_connector_query: PASS' > "${EVIDENCE_ROOT}/backend-query.txt"
cat > "${EVIDENCE_ROOT}/evidence.md" <<EOF
# CI Evidence — Hue RPM Clean Install and Trino Connector Smoke
schema: bigdata.evidence/v1
stage: test
component: ${COMPONENT}
version: ${VERSION}
artifact_type: service-rpm
test_profile: ${TEST_PROFILE}
source_identity: ${source_identity}
compatibility_identity: ${compatibility_identity}
build_run_id: ${BUILD_RUN_ID}
test_run_id: ${TEST_RUN_ID}
runtime_packages: ${COMPONENT_RUNTIME_PACKAGES}
environment: openEuler-22.03-LTS-SP4-clean-container
repository: local-createrepo-c
dependency_repositories: ${DEPENDENCY_REPO_PATHS}
python_runtime: 3.9
trino_server_version: 483
dnf_install: PASS
hue_migrate: PASS
health_check: PASS
backend_query: PASS
status: PASS
EOF
