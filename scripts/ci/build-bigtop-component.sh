#!/usr/bin/env bash
set -euo pipefail

COMPONENT="${COMPONENT:?COMPONENT is required}"
VERSION="${VERSION:?VERSION is required}"
BUILD_TASK="${BUILD_TASK:?BUILD_TASK is required}"
BIGTOP_REF="${BIGTOP_REF:-branch-3.6}"
BUILDER="${BUILDER:-bigtop}"
ARTIFACT_TYPE="${ARTIFACT_TYPE:-service-rpm}"
TEST_PROFILE="${TEST_PROFILE:-legacy-smoke}"
COMPONENT_JDK="${COMPONENT_JDK:-8}"
COMPONENT_JDK_PACKAGE="${COMPONENT_JDK_PACKAGE:-java-1.8.0-openjdk-devel}"
EXPECTED_SOURCE_IDENTITY="${EXPECTED_SOURCE_IDENTITY:-}"
COMPONENT_COMPATIBILITY_IDENTITY="${COMPONENT_COMPATIBILITY_IDENTITY:-}"
BUILD_RUN_ID="${BUILD_RUN_ID:-local}"
WORK_ROOT="${WORK_ROOT:-/work}"
BIGTOP_DIR="${WORK_ROOT}/bigtop"

case "${COMPONENT}" in
  zookeeper|hadoop|tez|hive|spark|hbase|kafka|flink) ;;
  *) echo "unsupported component: ${COMPONENT}" >&2; exit 2 ;;
esac
[[ "${BUILDER}" == bigtop ]] || {
  echo "builder ${BUILDER} is not yet supported by the Bigtop builder." >&2
  exit 2
}

# Keep the historically validated openEuler adaptations for the two base
# components while running them through the same artifact contract/workflow.
case "${COMPONENT}" in
  zookeeper)
    [[ "${BUILD_TASK}" == "zookeeper-rpm" ]]
    exec bash /workspace/scripts/ci/build-zookeeper-rpm-openeuler-container.sh
    ;;
  hadoop)
    [[ "${BUILD_TASK}" == "hadoop-rpm" ]]
    exec bash /workspace/scripts/ci/build-hadoop-rpm-openeuler-container.sh
    ;;
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
  "${COMPONENT_JDK_PACKAGE}" \
  openssl-devel zlib-devel boost-devel protobuf-devel cyrus-sasl-devel libcap-devel libtirpc-devel \
  pkgconfig openEuler-rpm-config lzo-devel \
  fuse fuse-devel fuse-libs \
  ca-certificates

export JAVA_HOME
JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
export PATH="${JAVA_HOME}/bin:${PATH}"
export BIGTOP_JDK="${COMPONENT_JDK}"

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
  mvn --version
  mvn --version | grep -q "Apache Maven ${MAVEN_VERSION}"
  bash /workspace/scripts/ci/install-spark-r.sh
  # SparkR's upstream vignette disables live Spark examples under GitHub CI,
  # while still rendering and packaging the vignette itself.
  export GITHUB_ACTIONS=true
fi


rm -rf "${BIGTOP_DIR}"
mkdir -p "${WORK_ROOT}/artifacts"/{rpms,logs,evidence}

case "${COMPONENT}" in
  hive|spark|hbase)
    bash /workspace/scripts/ci/prefetch-hadoop-maven-artifacts.sh \
      "${WORK_ROOT}/artifacts/logs"
    ;;
esac

if [[ -n "${EXPECTED_SOURCE_IDENTITY}" ]]; then
  git init "${BIGTOP_DIR}"
  git -C "${BIGTOP_DIR}" remote add origin https://github.com/apache/bigtop.git
  git -C "${BIGTOP_DIR}" fetch --filter=blob:none --depth=1 origin "${EXPECTED_SOURCE_IDENTITY}"
  git -C "${BIGTOP_DIR}" -c advice.detachedHead=false checkout --detach FETCH_HEAD
else
  git clone --filter=blob:none --branch "${BIGTOP_REF}" --single-branch \
    https://github.com/apache/bigtop.git "${BIGTOP_DIR}"
fi

cd "${BIGTOP_DIR}"
bigtop_commit="$(git rev-parse HEAD)"
if [[ -n "${EXPECTED_SOURCE_IDENTITY}" && "${EXPECTED_SOURCE_IDENTITY}" != "${bigtop_commit}" ]]; then
  echo "Resolved Bigtop commit ${bigtop_commit} does not match configured source identity ${EXPECTED_SOURCE_IDENTITY}." >&2
  exit 1
fi

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
bash /workspace/scripts/ci/retry-maven-downloads.sh \
  "${WORK_ROOT}/artifacts/logs/${COMPONENT}-build.log" \
  ./gradlew "${BUILD_TASK}" -Dbuildwithdeps=true --stacktrace
build_rc=$?
set -e

# SRPMs share the binary package NAME and must not enter runtime
# artifact bundles or clean-install repositories.
find "${BIGTOP_DIR}" -type f -name '*.rpm' ! -name '.rpm' \
  ! -name '*.src.rpm' ! -name '*.nosrc.rpm' -print \
  -exec cp -v {} "${WORK_ROOT}/artifacts/rpms/" \; || true

if [[ -n "${COMPONENT_RUNTIME_PACKAGES:-}" ]]; then
  for package in ${COMPONENT_RUNTIME_PACKAGES}; do
    matches=0
    while IFS= read -r rpm; do
      rpm_arch="$(rpm -qp --queryformat '%{ARCH}' "${rpm}")"
      case "${rpm_arch}" in
        src|nosrc) continue ;;
      esac
      rpm_name="$(rpm -qp --queryformat '%{NAME}' "${rpm}")"
      [[ "${rpm_name}" == "${package}" ]] && ((matches += 1))
    done < <(find "${WORK_ROOT}/artifacts/rpms" -type f -name '*.rpm' ! -name '.rpm')
    if [[ "${matches}" -ne 1 ]]; then
      echo "Expected exactly one ${package} runtime RPM, found ${matches}." >&2
      build_rc=1
    fi
  done
fi

find "${WORK_ROOT}/artifacts/rpms" -type f -name '*.rpm' ! -name '.rpm' -printf '%f\n' \
  | sort > "${WORK_ROOT}/artifacts/evidence/package-list.txt"

(
  cd "${WORK_ROOT}/artifacts"
  find rpms -type f -name '*.rpm' ! -name '.rpm' -print0 \
    | sort -z | xargs -0 -r sha256sum > evidence/SHA256SUMS
)

rpm_count="$(find "${WORK_ROOT}/artifacts/rpms" -type f -name '*.rpm' ! -name '.rpm' | wc -l)"
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
artifact_type: ${ARTIFACT_TYPE}
builder: ${BUILDER}
test_profile: ${TEST_PROFILE}
jdk: ${COMPONENT_JDK}
jdk_package: ${COMPONENT_JDK_PACKAGE}
source_identity: ${bigtop_commit}
compatibility_identity: ${COMPONENT_COMPATIBILITY_IDENTITY}
runtime_packages: ${COMPONENT_RUNTIME_PACKAGES:-}
build_run_id: ${BUILD_RUN_ID}
rpm_count: ${rpm_count}
status: ${status}
EOF

[[ "${status}" == PASS ]]
