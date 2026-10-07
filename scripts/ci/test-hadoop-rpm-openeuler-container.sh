#!/usr/bin/env bash
set -euo pipefail

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
printf '%s\n' "${package_names[@]}" | tee "${EVIDENCE_ROOT}/package-names.txt"

client_pkg=""
conf_pseudo_pkg=""
for p in "${package_names[@]}"; do
  [[ "${p}" == hadoop*client* ]] && client_pkg="${p}"
  [[ "${p}" == hadoop*conf-pseudo* ]] && conf_pseudo_pkg="${p}"
done

if [[ -z "${client_pkg}" ]]; then
  echo "Unable to resolve Hadoop client RPM package name" >&2
  exit 1
fi

install_pkgs=("${client_pkg}")
[[ -n "${conf_pseudo_pkg}" ]] && install_pkgs+=("${conf_pseudo_pkg}")

{
  echo "Installing Hadoop packages from local repo:"
  printf '  %s\n' "${install_pkgs[@]}"
  dnf -y --enablerepo=bigdata-ci install "${install_pkgs[@]}"
} 2>&1 | tee "${EVIDENCE_ROOT}/dnf-install.log"

rpm -qa | grep -E '^(hadoop|bigtop|zookeeper)' | sort \
  | tee "${EVIDENCE_ROOT}/installed-packages.txt"

hadoop version 2>&1 | tee "${EVIDENCE_ROOT}/hadoop-version.log"
hdfs version 2>&1 | tee "${EVIDENCE_ROOT}/hdfs-version.log"
yarn version 2>&1 | tee "${EVIDENCE_ROOT}/yarn-version.log"

rpm -ql "${client_pkg}" | sort > "${EVIDENCE_ROOT}/rpm-files.txt"
rpm -qR "${client_pkg}" | sort > "${EVIDENCE_ROOT}/rpm-requires.txt"

cat > "${EVIDENCE_ROOT}/evidence.md" <<EOF
# CI Evidence — Hadoop Package Install Smoke

schema: bigdata.evidence/v1
stage: test
component: hadoop
version: 3.4.3
environment: openEuler-22.03-LTS-SP4-clean-container
repository: local-createrepo-c
package_manager: dnf
dnf_install: PASS
hadoop_cli: PASS
hdfs_cli: PASS
yarn_cli: PASS
status: PASS
EOF
