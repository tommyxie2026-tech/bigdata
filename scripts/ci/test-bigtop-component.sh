#!/usr/bin/env bash
set -euo pipefail

COMPONENT="${COMPONENT:?COMPONENT required}"
VERSION="${VERSION:?VERSION required}"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-/artifact}"
EVIDENCE_ROOT="${EVIDENCE_ROOT:-/evidence}"
REPO_DIR=/tmp/bigdata-repo

mkdir -p "${EVIDENCE_ROOT}" "${REPO_DIR}"

dnf -y install createrepo_c dnf-utils rpm findutils procps-ng java-1.8.0-openjdk nc

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

dnf clean all
dnf makecache --repo=bigdata-ci

mapfile -t package_names < <(
  for rpm_file in "${REPO_DIR}"/*.rpm; do
    rpm -qp --queryformat '%{NAME}\n' "${rpm_file}"
  done | sort -u
)
printf '%s\n' "${package_names[@]}" > "${EVIDENCE_ROOT}/package-names.txt"

base_pkg=""
for p in "${package_names[@]}"; do
  case "${COMPONENT}" in
    tez)   [[ "${p}" == tez* ]] && base_pkg="${p}" ;;
    hive)  [[ "${p}" == hive* && "${p}" != *server* && "${p}" != *metastore* && "${p}" != *webhcat* ]] && base_pkg="${p}" ;;
    spark) [[ "${p}" == spark* && "${p}" != *historyserver* && "${p}" != *thriftserver* ]] && base_pkg="${p}" ;;
    hbase) [[ "${p}" == hbase* && "${p}" != *master* && "${p}" != *regionserver* && "${p}" != *thrift* ]] && base_pkg="${p}" ;;
  esac
done

if [[ -z "${base_pkg}" ]]; then
  echo "Unable to resolve base package for ${COMPONENT}" >&2
  cat "${EVIDENCE_ROOT}/package-names.txt" >&2
  exit 1
fi

dnf -y --repo=bigdata-ci install "${base_pkg}" 2>&1 | tee "${EVIDENCE_ROOT}/dnf-install.log"

rpm -qi "${base_pkg}" > "${EVIDENCE_ROOT}/rpm-info.txt"
rpm -ql "${base_pkg}" > "${EVIDENCE_ROOT}/rpm-files.txt"
rpm -qR "${base_pkg}" > "${EVIDENCE_ROOT}/rpm-requires.txt"

smoke_status=PASS
case "${COMPONENT}" in
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
environment: openEuler-22.03-LTS-SP4-clean-container
repository: local-createrepo-c
package_manager: dnf
dnf_install: PASS
runtime_smoke: ${smoke_status}
status: ${smoke_status}
EOF

[[ "${smoke_status}" == PASS ]]
