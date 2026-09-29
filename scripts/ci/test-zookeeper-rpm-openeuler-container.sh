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

server_pkg=""
base_pkg=""
for p in "${package_names[@]}"; do
  [[ "${p}" == *zookeeper*server* ]] && server_pkg="${p}"
  [[ "${p}" == zookeeper* && "${p}" != *server* && "${p}" != *native* && "${p}" != *rest* ]] && base_pkg="${p}"
done

if [[ -z "${base_pkg}" ]]; then
  echo "Unable to resolve ZooKeeper base RPM package name" >&2
  exit 1
fi

install_pkgs=("${base_pkg}")
[[ -n "${server_pkg}" ]] && install_pkgs+=("${server_pkg}")

{
  echo "Installing packages from repo:"
  printf '  %s\n' "${install_pkgs[@]}"
  dnf -y --repo=bigdata-ci install "${install_pkgs[@]}"
} 2>&1 | tee "${EVIDENCE_ROOT}/dnf-install.log"

rpm -qa | grep -i zookeeper | sort | tee "${EVIDENCE_ROOT}/installed-packages.txt"
rpm -ql "${base_pkg}" | sort > "${EVIDENCE_ROOT}/rpm-files.txt"
rpm -qR "${base_pkg}" | sort > "${EVIDENCE_ROOT}/rpm-requires.txt"

test -x /usr/bin/zookeeper-server
test -x /usr/bin/zookeeper-client
test -f /etc/zookeeper/conf/zoo.cfg

zookeeper-server start 2>&1 | tee "${EVIDENCE_ROOT}/runtime-start.log"

ready=0
for _ in $(seq 1 30); do
  if zookeeper-server status >/tmp/zk-status.txt 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
cat /tmp/zk-status.txt | tee "${EVIDENCE_ROOT}/runtime-status.log"
test "${ready}" -eq 1

set +e
echo "ls /" | timeout 30 zookeeper-client -server 127.0.0.1:2181   > "${EVIDENCE_ROOT}/zkcli-smoke.log" 2>&1
cli_rc=$?
set -e

zookeeper-server stop 2>&1 | tee "${EVIDENCE_ROOT}/runtime-stop.log" || true

if [[ "${cli_rc}" -ne 0 ]]; then
  cat "${EVIDENCE_ROOT}/zkcli-smoke.log"
  exit "${cli_rc}"
fi

cat > "${EVIDENCE_ROOT}/evidence.md" <<EOF
# CI Evidence — ZooKeeper Install and Runtime Smoke

schema: bigdata.evidence/v1
stage: test
component: zookeeper
version: 3.8.4
environment: openEuler-22.03-LTS-SP4-clean-container
repository: local-createrepo-c
package_manager: dnf
install: PASS
runtime_smoke: PASS
status: PASS
EOF
