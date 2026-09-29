#!/usr/bin/env bash
set -euo pipefail

BIGTOP_REF="${BIGTOP_REF:-branch-3.6}"
WORK_ROOT="${WORK_ROOT:-/work}"
BIGTOP_DIR="${WORK_ROOT}/bigtop"

echo "== openEuler identity =="
cat /etc/os-release
grep -qi "openEuler" /etc/os-release

echo "== install core build toolchain =="
dnf -y install \
  git curl wget tar unzip zip sudo hostname which findutils diffutils procps-ng \
  make gcc gcc-c++ cmake \
  maven python3 \
  autoconf automake libtool patch cppunit-devel \
  rpm-build rpmdevtools createrepo_c \
  java-1.8.0-openjdk-devel \
  openssl-devel zlib-devel \
  fuse fuse-devel fuse-libs \
  pkgconfig openEuler-rpm-config lzo-devel \
  ca-certificates

export JAVA_HOME
JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
export PATH="${JAVA_HOME}/bin:${PATH}"
export BIGTOP_JDK=8

echo "JAVA_HOME=${JAVA_HOME}"
java -version
javac -version
rpm --version
rpmbuild --version
df -h

echo "== prepare workspace =="
rm -rf "${BIGTOP_DIR}"
mkdir -p "${WORK_ROOT}/artifacts"/{rpms,logs,evidence}

echo "== checkout Apache Bigtop =="
git clone --filter=blob:none --branch "${BIGTOP_REF}" --single-branch \
  https://github.com/apache/bigtop.git "${BIGTOP_DIR}"

cd "${BIGTOP_DIR}"
bigtop_commit="$(git rev-parse HEAD)"
printf '%s\n' "${bigtop_commit}" | tee "${WORK_ROOT}/artifacts/evidence/bigtop-commit.txt"

echo "== verify upstream baseline =="
grep -q 'version = "3.6.0"' bigtop.bom
grep -A16 "'hadoop'" bigtop.bom | grep -q "3.4.3"

cat > "${WORK_ROOT}/artifacts/evidence/build-metadata.env" <<EOF
component=hadoop
expected_version=3.4.3
bigtop_ref=${BIGTOP_REF}
bigtop_commit=${bigtop_commit}
os_image=openeuler/openeuler:22.03-lts-sp4
jdk=8
EOF

echo "== build Hadoop RPMs with dependencies =="
set +e
./gradlew hadoop-rpm -Dbuildwithdeps=true --stacktrace 2>&1 \
  | tee "${WORK_ROOT}/artifacts/logs/hadoop-build.log"
build_rc=${PIPESTATUS[0]}
set -e

echo "== collect RPM artifacts =="
find "${BIGTOP_DIR}/output" -type f -name '*.rpm' ! -name '*.src.rpm' -print -exec cp -v {} "${WORK_ROOT}/artifacts/rpms/" \; || true

find "${WORK_ROOT}/artifacts/rpms" -type f -name '*.rpm' -printf '%f\n' \
  | sort > "${WORK_ROOT}/artifacts/evidence/package-list.txt"

find "${WORK_ROOT}/artifacts/rpms" -type f -name '*.rpm' -print0 \
  | sort -z | xargs -0 -r sha256sum \
  > "${WORK_ROOT}/artifacts/evidence/SHA256SUMS"

rpm_count="$(find "${WORK_ROOT}/artifacts/rpms" -type f -name '*.rpm' | wc -l)"
status="PASS"
if [[ "${build_rc}" -ne 0 || "${rpm_count}" -eq 0 ]]; then
  status="FAIL"
fi

cat > "${WORK_ROOT}/artifacts/evidence/evidence.md" <<EOF
# CI Evidence — Hadoop RPM Build

schema: bigdata.evidence/v1
stage: build
component: hadoop
version: 3.4.3
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
df -h

[[ "${status}" == "PASS" ]]
