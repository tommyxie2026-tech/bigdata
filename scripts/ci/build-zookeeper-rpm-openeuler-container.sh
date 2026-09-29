#!/usr/bin/env bash
set -euo pipefail

BIGTOP_REF="${BIGTOP_REF:-branch-3.6}"
COMPONENT="${COMPONENT:-zookeeper}"
WORK_ROOT="${WORK_ROOT:-/work}"
BIGTOP_DIR="${WORK_ROOT}/bigtop"

if [[ "${COMPONENT}" != "zookeeper" ]]; then
  echo "Unsupported component in CI-1 bootstrap: ${COMPONENT}" >&2
  exit 2
fi

echo "== openEuler identity =="
cat /etc/os-release
grep -qi "openEuler" /etc/os-release

echo "== install build toolchain =="
dnf -y install   git curl wget tar unzip zip sudo   make gcc gcc-c++   maven python3   autoconf automake libtool patch   createrepo_c rpm-build rpmdevtools   java-1.8.0-openjdk-devel   which findutils diffutils procps-ng   ca-certificates

export JAVA_HOME
JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
export PATH="${JAVA_HOME}/bin:${PATH}"
export BIGTOP_JDK=8

echo "JAVA_HOME=${JAVA_HOME}"
java -version
javac -version
rpm --version
rpmbuild --version
dnf --version | head -20

echo "== prepare workspace =="
rm -rf "${BIGTOP_DIR}"
mkdir -p "${WORK_ROOT}/artifacts"/{rpms,logs,evidence}

echo "== checkout Apache Bigtop =="
git clone --filter=blob:none --branch "${BIGTOP_REF}" --single-branch   https://github.com/apache/bigtop.git "${BIGTOP_DIR}"

cd "${BIGTOP_DIR}"
git rev-parse HEAD | tee "${WORK_ROOT}/artifacts/evidence/bigtop-commit.txt"
git status --short

echo "== verify upstream baseline =="
grep -q 'version = "3.6.0"' bigtop.bom
grep -A16 "'zookeeper'" bigtop.bom | grep -q "3.8.4"

bigtop_commit="$(git rev-parse HEAD)"

cat > "${WORK_ROOT}/artifacts/evidence/build-metadata.env" <<EOF
component=zookeeper
expected_version=3.8.4
bigtop_ref=${BIGTOP_REF}
bigtop_commit=${bigtop_commit}
os_image=openeuler/openeuler:22.03-lts-sp4
jdk=8
EOF

echo "== build ZooKeeper RPM =="
set +e
./gradlew zookeeper-rpm -Dbuildwithdeps=true --stacktrace 2>&1 | tee "${WORK_ROOT}/artifacts/logs/zookeeper-build.log"
build_rc=${PIPESTATUS[0]}
set -e

echo "== collect artifacts =="
find "${BIGTOP_DIR}" -type f -name '*.rpm' -print -exec cp -v {} "${WORK_ROOT}/artifacts/rpms/" \; || true

find "${WORK_ROOT}/artifacts/rpms" -type f -name '*.rpm' -printf '%f\n'   | sort > "${WORK_ROOT}/artifacts/evidence/package-list.txt"

find "${WORK_ROOT}/artifacts/rpms" -type f -name '*.rpm' -print0   | sort -z   | xargs -0 -r sha256sum > "${WORK_ROOT}/artifacts/evidence/SHA256SUMS"

rpm_count="$(find "${WORK_ROOT}/artifacts/rpms" -type f -name '*.rpm' | wc -l)"
status="PASS"
if [[ "${build_rc}" -ne 0 || "${rpm_count}" -eq 0 ]]; then
  status="FAIL"
fi

cat > "${WORK_ROOT}/artifacts/evidence/evidence.md" <<EOF
# CI Evidence — ZooKeeper RPM Build

schema: bigdata.evidence/v1
stage: build
component: zookeeper
version: 3.8.4
bigtop_ref: ${BIGTOP_REF}
bigtop_commit: ${bigtop_commit}
environment: openEuler-22.03-LTS-SP4-container
runner: github-hosted-ubuntu
package: RPM
jdk: 8
rpm_count: ${rpm_count}
status: ${status}
EOF

echo "build_rc=${build_rc}"
echo "rpm_count=${rpm_count}"
echo "status=${status}"

if [[ "${status}" != "PASS" ]]; then
  exit 1
fi
