#!/usr/bin/env bash
set -euo pipefail

COMPONENT="${COMPONENT:?COMPONENT required}"
VERSION="${VERSION:?VERSION required}"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-/artifact}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-/evidence}"
TEST_PROFILE="${TEST_PROFILE:-legacy-smoke}"
ARTIFACT_TYPE="${ARTIFACT_TYPE:-service-rpm}"
COMPONENT_JDK="${COMPONENT_JDK:-8}"
COMPONENT_JDK_PACKAGE="${COMPONENT_JDK_PACKAGE:-java-1.8.0-openjdk}"
EXPECTED_SOURCE_IDENTITY="${EXPECTED_SOURCE_IDENTITY:-}"
BUILD_RUN_ID="${BUILD_RUN_ID:?BUILD_RUN_ID required}"
TEST_RUN_ID="${TEST_RUN_ID:?TEST_RUN_ID required}"
COMPONENT_RUNTIME_PACKAGES="${COMPONENT_RUNTIME_PACKAGES:-}"
DEPENDENCY_REPO_PATHS="${DEPENDENCY_REPO_PATHS:-}"
REPO_DIR=/tmp/bigdata-repo

# Reuse the base-component clean-container checks in the unified test stage.
case "${COMPONENT}" in
  zookeeper)
    exec bash /workspace/scripts/ci/test-zookeeper-rpm-openeuler-container.sh
    ;;
  hadoop)
    exec bash /workspace/scripts/ci/test-hadoop-rpm-openeuler-container.sh
    ;;
  kafka)
    [[ "${TEST_PROFILE}" == kafka-kraft-smoke ]] || {
      echo "Kafka requires the kafka-kraft-smoke profile (got ${TEST_PROFILE})." >&2
      exit 2
    }
    ;;
  flink)
    [[ "${TEST_PROFILE}" == flink-local-job-smoke ]] || {
      echo "Flink requires the flink-local-job-smoke profile (got ${TEST_PROFILE})." >&2
      exit 2
    }
    ;;
esac

mkdir -p "${EVIDENCE_ROOT}" "${REPO_DIR}"

test_jdk_package="${COMPONENT_JDK_PACKAGE%-devel}"
dnf -y install createrepo_c dnf-utils rpm findutils procps-ng "${test_jdk_package}" nc

build_evidence="${ARTIFACT_ROOT}/evidence/evidence.md"
[[ -s "${build_evidence}" ]]
source_identity="$(awk -F ': ' '$1 == "source_identity" { print $2 }' "${build_evidence}")"
grep -qx "component: ${COMPONENT}" "${build_evidence}"
grep -qx "version: ${VERSION}" "${build_evidence}"
grep -qx "artifact_type: ${ARTIFACT_TYPE}" "${build_evidence}"
grep -qx "test_profile: ${TEST_PROFILE}" "${build_evidence}"
grep -qx "build_run_id: ${BUILD_RUN_ID}" "${build_evidence}"
if [[ -n "${EXPECTED_SOURCE_IDENTITY}" && "${source_identity}" != "${EXPECTED_SOURCE_IDENTITY}" ]]; then
  echo "Build artifact source identity ${source_identity} does not match ${EXPECTED_SOURCE_IDENTITY}." >&2
  exit 1
fi

cp "${ARTIFACT_ROOT}"/rpms/*.rpm "${REPO_DIR}/"
createrepo_c "${REPO_DIR}"

cat > /etc/yum.repos.d/bigdata-ci.repo <<EOF
[bigdata-ci]
name=BIGDATA CI Local Repository
baseurl=file://${REPO_DIR}
enabled=1
gpgcheck=0
metadata_expire=0
EOF

dependency_index=0
IFS=',' read -r -a dependency_paths <<< "${DEPENDENCY_REPO_PATHS}"
for dependency_path in "${dependency_paths[@]}"; do
  [[ -n "${dependency_path}" ]] || continue
  dependency_repo="/dependency-repos/${dependency_path}"
  [[ -f "${dependency_repo}/repodata/repomd.xml" ]] || {
    echo "Missing dependency repository metadata: ${dependency_repo}" >&2
    exit 1
  }
  cat >> /etc/yum.repos.d/bigdata-ci.repo <<EOF

[bigdata-dependency-${dependency_index}]
name=BIGDATA dependency repository ${dependency_path}
baseurl=file://${dependency_repo}
enabled=1
gpgcheck=0
repo_gpgcheck=0
metadata_expire=0
EOF
  dependency_index=$((dependency_index + 1))
done

dnf clean all
dnf makecache --repo=bigdata-ci

read -r -a runtime_packages <<< "${COMPONENT_RUNTIME_PACKAGES}"
if [[ "${#runtime_packages[@]}" -eq 0 ]]; then
  echo "No configured runtime package allow-list for ${COMPONENT}." >&2
  exit 1
fi
dnf -y --enablerepo=bigdata-ci install "${runtime_packages[@]}" \
  2>&1 | tee "${EVIDENCE_ROOT}/dnf-install.log"

mapfile -t package_names < <(
  for rpm_file in "${REPO_DIR}"/*.rpm; do
    rpm -qp --queryformat '%{NAME}\n' "${rpm_file}"
  done | sort -u
)
printf '%s\n' "${package_names[@]}" > "${EVIDENCE_ROOT}/package-names.txt"
for required_package in "${runtime_packages[@]}"; do
  count=0
  for rpm_file in "${REPO_DIR}"/*.rpm; do
    [[ "$(rpm -qp --queryformat '%{NAME}' "${rpm_file}")" == "${required_package}" ]] \
      && ((count += 1))
  done
  [[ "${count}" -eq 1 ]] || {
    echo "Expected one RPM for ${required_package}, found ${count}." >&2
    exit 1
  }
done

base_pkg=""
for p in "${package_names[@]}"; do
  # Match the base RPM, never a client, documentation, Python or SparkR subpackage.
  if [[ "${p}" =~ ^${COMPONENT}(_[0-9]+)*$ ]]; then
    if [[ -n "${base_pkg}" ]]; then
      echo "Multiple base packages for ${COMPONENT}: ${base_pkg}, ${p}" >&2
      exit 1
    fi
    base_pkg="${p}"
  fi
done

if [[ -z "${base_pkg}" ]]; then
  echo "Unable to resolve base package for ${COMPONENT}" >&2
  cat "${EVIDENCE_ROOT}/package-names.txt" >&2
  exit 1
fi

rpm -qi "${base_pkg}" > "${EVIDENCE_ROOT}/rpm-info.txt"
rpm -ql "${base_pkg}" > "${EVIDENCE_ROOT}/rpm-files.txt"
rpm -qR "${base_pkg}" > "${EVIDENCE_ROOT}/rpm-requires.txt"

smoke_status=PASS
case "${COMPONENT}" in
  kafka)
    if bash /workspace/scripts/ci/test-kafka-rpm-openeuler-container.sh; then
      smoke_status=PASS
    else
      smoke_status=FAIL
    fi
    ;;
  flink)
    if bash /workspace/scripts/ci/test-flink-rpm-openeuler-container.sh; then
      smoke_status=PASS
    else
      smoke_status=FAIL
    fi
    ;;
  tez)
    rpm -ql "${base_pkg}" | grep -E '/usr/lib/tez|/etc/tez' > "${EVIDENCE_ROOT}/tez-layout.txt"
    ;;
  hive)
    if command -v hive >/dev/null 2>&1; then
      hive --version > "${EVIDENCE_ROOT}/runtime-smoke.log" 2>&1
    elif command -v beeline >/dev/null 2>&1; then
      beeline --version > "${EVIDENCE_ROOT}/runtime-smoke.log" 2>&1
    else
      smoke_status=FAIL
    fi
    ;;
  spark)
    if command -v spark-submit >/dev/null 2>&1; then
      spark-submit --version > "${EVIDENCE_ROOT}/runtime-smoke.log" 2>&1
    else
      smoke_status=FAIL
    fi
    ;;
  hbase)
    if command -v hbase >/dev/null 2>&1; then
      hbase version > "${EVIDENCE_ROOT}/runtime-smoke.log" 2>&1
    else
      smoke_status=FAIL
    fi
    ;;
esac

cat > "${EVIDENCE_ROOT}/evidence.md" <<EOF
# CI Evidence — ${COMPONENT} Install Smoke

schema: bigdata.evidence/v1
stage: test
component: ${COMPONENT}
version: ${VERSION}
artifact_type: ${ARTIFACT_TYPE}
test_profile: ${TEST_PROFILE}
source_identity: ${source_identity}
build_run_id: ${BUILD_RUN_ID}
test_run_id: ${TEST_RUN_ID}
runtime_packages: ${COMPONENT_RUNTIME_PACKAGES}
environment: openEuler-22.03-LTS-SP4-clean-container
repository: local-createrepo-c
package_manager: dnf
toolchain_jdk: ${COMPONENT_JDK}
jdk_package: ${test_jdk_package}
dnf_install: PASS
runtime_smoke: ${smoke_status}
status: ${smoke_status}
EOF

for evidence in broker_start topic_roundtrip job_submit job_result; do
  if [[ -f "${EVIDENCE_ROOT}/${evidence}.txt" ]]; then
    cat "${EVIDENCE_ROOT}/${evidence}.txt" >> "${EVIDENCE_ROOT}/evidence.md"
  fi
done

[[ "${smoke_status}" == PASS ]]
