#!/usr/bin/env bash
set -euo pipefail

COMPONENT="${COMPONENT:?COMPONENT is required}"
VERSION="${VERSION:?VERSION is required}"
BUILD_TASK="${BUILD_TASK:?BUILD_TASK is required}"
BIGTOP_REF="${BIGTOP_REF:-branch-3.6}"
WORK_ROOT="${WORK_ROOT:-/work}"
BIGTOP_DIR="${WORK_ROOT}/bigtop"

case "${COMPONENT}" in
  tez|hive|spark|hbase) ;;
  *) echo "unsupported component: ${COMPONENT}" >&2; exit 2 ;;
esac

cat /etc/os-release
grep -qi openEuler /etc/os-release

dnf -y install \
  sudo hostname git curl wget tar unzip zip gzip bzip2 xz \
  which findutils diffutils procps-ng coreutils \
  make gcc gcc-c++ cmake \
  maven ant python3 \
  autoconf automake libtool patch cppunit-devel \
  rpm-build rpmdevtools createrepo_c \
  java-1.8.0-openjdk-devel \
  openssl-devel zlib-devel boost-devel protobuf-devel cyrus-sasl-devel libcap-devel libtirpc-devel \
  pkgconfig openEuler-rpm-config lzo-devel \
  fuse fuse-devel fuse-libs \
  ca-certificates

export JAVA_HOME
JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
export PATH="${JAVA_HOME}/bin:${PATH}"
export BIGTOP_JDK=8

# Spark 3.5.8 enforces Maven >= 3.9.6; openEuler 22.03 ships Maven 3.6.3.
# Override Maven for Spark only, leaving other component toolchains unchanged.
if [[ "${COMPONENT}" == "spark" ]]; then
  MAVEN_VERSION=3.9.9
  MAVEN_URL="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
  MAVEN_HOME="/opt/apache-maven-${MAVEN_VERSION}"
  MAVEN_ARCHIVE="apache-maven-${MAVEN_VERSION}-bin.tar.gz"
  curl --fail --location --retry 5 --retry-delay 5 --connect-timeout 30 \
    --output "/tmp/${MAVEN_ARCHIVE}" "${MAVEN_URL}"
  curl --fail --location --retry 5 --retry-delay 5 --connect-timeout 30 \
    --output "/tmp/${MAVEN_ARCHIVE}.sha512" "${MAVEN_URL}.sha512"
  # Apache checksum sidecars may contain only the digest rather than
  # "digest  filename", so normalize both formats before verification.
  expected_sha512="$(awk '{print $1}' "/tmp/${MAVEN_ARCHIVE}.sha512")"
  actual_sha512="$(sha512sum "/tmp/${MAVEN_ARCHIVE}" | awk '{print $1}')"
  [[ "${actual_sha512}" == "${expected_sha512}" ]]
  tar -xzf "/tmp/${MAVEN_ARCHIVE}" -C /opt
  export MAVEN_HOME
  export PATH="${MAVEN_HOME}/bin:${PATH}"
  dnf -y install R
  mvn --version
  mvn --version | grep -q "Apache Maven ${MAVEN_VERSION}"
fi

export MAVEN_OPTS="${MAVEN_OPTS:-} -Dmaven.wagon.http.retryHandler.count=5 -Dmaven.wagon.http.retryHandler.requestSentEnabled=true -Dmaven.wagon.httpconnectionManager.ttlSeconds=60"

rm -rf "${BIGTOP_DIR}"
mkdir -p "${WORK_ROOT}/artifacts"/{rpms,logs,evidence}

git clone --filter=blob:none --branch "${BIGTOP_REF}" --single-branch \
  https://github.com/apache/bigtop.git "${BIGTOP_DIR}"

cd "${BIGTOP_DIR}"
bigtop_commit="$(git rev-parse HEAD)"

grep -q 'version = "3.6.0"' bigtop.bom
grep -A20 "'${COMPONENT}'" bigtop.bom | grep -q "${VERSION}"

if [[ "${COMPONENT}" == "tez" ]]; then
  echo "== enable upstream Tez allowRootBuild profile =="
  python3 - <<'PY'
from pathlib import Path

build = Path("bigtop-packages/src/common/tez/do-component-build")
text = build.read_text()
needle = "-DskipTests\""
replacement = "-DskipTests -Dallow.root.build=true\""

if needle not in text:
    raise SystemExit("Expected Tez BUILD_TEZ_OPTS context not found")

text = text.replace(needle, replacement, 1)
build.write_text(text)
print("Tez build will use -Dallow.root.build=true")
PY
  grep -q -- '-Dallow.root.build=true' bigtop-packages/src/common/tez/do-component-build
  git diff --check
  git diff -- bigtop-packages/src/common/tez/do-component-build
fi

set +e
./gradlew "${BUILD_TASK}" -Dbuildwithdeps=true --stacktrace 2>&1 \
  | tee "${WORK_ROOT}/artifacts/logs/${COMPONENT}-build.log"
build_rc=${PIPESTATUS[0]}
set -e

find "${BIGTOP_DIR}" -type f -name '*.rpm' -print -exec cp -v {} "${WORK_ROOT}/artifacts/rpms/" \; || true

find "${WORK_ROOT}/artifacts/rpms" -type f -name '*.rpm' -printf '%f\n' \
  | sort > "${WORK_ROOT}/artifacts/evidence/package-list.txt"

(
  cd "${WORK_ROOT}/artifacts"
  find rpms -type f -name '*.rpm' -print0 | sort -z | xargs -0 -r sha256sum > evidence/SHA256SUMS
)

rpm_count="$(find "${WORK_ROOT}/artifacts/rpms" -type f -name '*.rpm' | wc -l)"
status=PASS
if [[ "${build_rc}" -ne 0 || "${rpm_count}" -eq 0 ]]; then status=FAIL; fi

cat > "${WORK_ROOT}/artifacts/evidence/evidence.md" <<EOF
# CI Evidence — ${COMPONENT} RPM Build

schema: bigdata.evidence/v1
stage: build
component: ${COMPONENT}
version: ${VERSION}
bigtop_ref: ${BIGTOP_REF}
bigtop_commit: ${bigtop_commit}
environment: openEuler-22.03-LTS-SP4-container
runner: github-hosted-ubuntu
jdk: 8
rpm_count: ${rpm_count}
status: ${status}
EOF

[[ "${status}" == PASS ]]
