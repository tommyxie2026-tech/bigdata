#!/usr/bin/env bash
set -euo pipefail
: "${COMPONENT:?COMPONENT is required}"
: "${VERSION:?VERSION is required}"
: "${BUILD_RUN_ID:?BUILD_RUN_ID is required}"
: "${EXPECTED_SOURCE_IDENTITY:?EXPECTED_SOURCE_IDENTITY is required}"
: "${COMPONENT_RUNTIME_PACKAGES:?COMPONENT_RUNTIME_PACKAGES is required}"
WORK_ROOT="${WORK_ROOT:-/work}"
SOURCE_DIR="${WORK_ROOT}/trino-packages"
ARTIFACTS="${WORK_ROOT}/artifacts"
RPM_NAME="trino-server-rpm-${VERSION}.noarch.rpm"
mkdir -p "${ARTIFACTS}/rpms" "${ARTIFACTS}/logs" "${ARTIFACTS}/evidence"
[[ "${COMPONENT}" == trino && "${VERSION}" == 483 ]] || { echo "Only catalog-pinned Trino 483 is supported." >&2; exit 2; }
[[ "${EXPECTED_SOURCE_IDENTITY}" =~ ^[0-9a-f]{40}$ ]]
[[ "${COMPONENT_RUNTIME_PACKAGES}" == trino-server-rpm ]]
grep -qi openEuler /etc/os-release
dnf -y install python3 ca-certificates curl git gzip make openssl rpm-build rpmdevtools shadow-utils sudo tar unzip which openEuler-rpm-config
source /workspace/scripts/ci/install-pinned-java-runtime.sh
java -version
javac -version
rm -rf "${SOURCE_DIR}"
git init "${SOURCE_DIR}"
git -C "${SOURCE_DIR}" remote add origin https://github.com/trinodb/trino-packages.git
git -C "${SOURCE_DIR}" fetch --depth=1 origin "${EXPECTED_SOURCE_IDENTITY}"
git -C "${SOURCE_DIR}" -c advice.detachedHead=false checkout --detach FETCH_HEAD
actual_source_identity="$(git -C "${SOURCE_DIR}" rev-parse HEAD)"
[[ "${actual_source_identity}" == "${EXPECTED_SOURCE_IDENTITY}" ]]
cd "${SOURCE_DIR}"
grep -q '<dep.trino.version>483</dep.trino.version>' trino-server-rpm/pom.xml
bash /workspace/scripts/ci/retry-maven-downloads.sh \
  "${ARTIFACTS}/logs/trino-build.log" \
  ./mvnw --batch-mode --no-transfer-progress -f trino-server-rpm/pom.xml clean install -DskipTests
rpm_path="${SOURCE_DIR}/trino-server-rpm/target/${RPM_NAME}"
[[ -s "${rpm_path}" ]]
[[ "$(rpm -qp --queryformat '%{NAME}' "${rpm_path}")" == trino-server-rpm ]]
[[ "$(rpm -qp --queryformat '%{VERSION}' "${rpm_path}")" == "${VERSION}" ]]
[[ "$(rpm -qp --queryformat '%{ARCH}' "${rpm_path}")" == noarch ]]
cp -v "${rpm_path}" "${ARTIFACTS}/rpms/"
(cd "${ARTIFACTS}" && sha256sum "rpms/${RPM_NAME}" > evidence/SHA256SUMS)
printf '%s\n' "${RPM_NAME}" > "${ARTIFACTS}/evidence/package-list.txt"
cat > "${ARTIFACTS}/evidence/evidence.md" <<EOF
# CI Evidence — Trino RPM Build
schema: bigdata.evidence/v1
stage: build
component: ${COMPONENT}
version: ${VERSION}
artifact_type: service-rpm
test_profile: trino-single-node-smoke
source_identity: ${actual_source_identity}
compatibility_identity: ${COMPONENT_COMPATIBILITY_IDENTITY:-}
build_run_id: ${BUILD_RUN_ID}
runtime_packages: ${COMPONENT_RUNTIME_PACKAGES}
toolchain_jdk: ${COMPONENT_JDK:-25}
jdk_package: ${COMPONENT_JDK_PACKAGE:-}
jdk_runtime_archive_sha256: ${JDK_RUNTIME_ARCHIVE_SHA256}
rpm_count: 1
status: PASS
EOF
printf 'Built %s from %s using Java %s\n' "${RPM_NAME}" "${actual_source_identity}" "${COMPONENT_JDK:-25}"
