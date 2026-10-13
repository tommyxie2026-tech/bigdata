#!/usr/bin/env bash
set -euo pipefail
: "${COMPONENT:?COMPONENT is required}"
: "${VERSION:?VERSION is required}"
: "${BUILD_RUN_ID:?BUILD_RUN_ID is required}"
: "${EXPECTED_SOURCE_IDENTITY:?EXPECTED_SOURCE_IDENTITY is required}"
: "${COMPONENT_RUNTIME_PACKAGES:?COMPONENT_RUNTIME_PACKAGES is required}"
WORK_ROOT="${WORK_ROOT:-/work}"
SOURCE_DIR="${WORK_ROOT}/iceberg"
ARTIFACTS="${WORK_ROOT}/artifacts"
RPM_TOP="${WORK_ROOT}/rpmbuild"
SPARK_JAR="iceberg-spark-runtime-3.5_2.12-${VERSION}.jar"
FLINK_JAR="iceberg-flink-runtime-1.20-${VERSION}.jar"
mkdir -p "${ARTIFACTS}/rpms" "${ARTIFACTS}/logs" "${ARTIFACTS}/evidence"
[[ "${COMPONENT}" == iceberg && "${VERSION}" == 1.12.0 ]] || {
  echo "Only catalog-pinned Iceberg 1.12.0 is supported." >&2
  exit 2
}
[[ "${EXPECTED_SOURCE_IDENTITY}" =~ ^[0-9a-f]{40}$ ]]
[[ "${COMPONENT_RUNTIME_PACKAGES}" == "bigdata-iceberg-spark bigdata-iceberg-flink" ]]
grep -qi openEuler /etc/os-release
dnf -y install ca-certificates curl git java-17-openjdk-devel make openssl rpm-build rpmdevtools tar
java -version
javac -version
rm -rf "${SOURCE_DIR}"
git init "${SOURCE_DIR}"
git -C "${SOURCE_DIR}" remote add origin https://github.com/apache/iceberg.git
git -C "${SOURCE_DIR}" fetch --depth=1 origin "${EXPECTED_SOURCE_IDENTITY}"
git -C "${SOURCE_DIR}" -c advice.detachedHead=false checkout --detach FETCH_HEAD
actual_source_identity="$(git -C "${SOURCE_DIR}" rev-parse HEAD)"
[[ "${actual_source_identity}" == "${EXPECTED_SOURCE_IDENTITY}" ]]
cd "${SOURCE_DIR}"
grep -q "icebergVersion = '1.12.0'" gradle.properties
bash /workspace/scripts/ci/retry-maven-downloads.sh "${ARTIFACTS}/logs/iceberg-gradle-build.log" \
  ./gradlew --no-daemon --stacktrace \
    -DflinkVersions=1.20 -DsparkVersions=3.5 -DscalaVersion=2.12 \
    :iceberg-spark:iceberg-spark-runtime-3.5_2.12:shadowJar \
    :iceberg-flink:iceberg-flink-runtime-1.20:shadowJar
mapfile -t spark_jars < <(find spark/v3.5/spark-runtime/build/libs -maxdepth 1 -type f -name "${SPARK_JAR}" -print)
mapfile -t flink_jars < <(find flink/v1.20/flink-runtime/build/libs -maxdepth 1 -type f -name "${FLINK_JAR}" -print)
[[ "${#spark_jars[@]}" -eq 1 && -s "${spark_jars[0]}" ]]
[[ "${#flink_jars[@]}" -eq 1 && -s "${flink_jars[0]}" ]]
rpmdev-setuptree --define "_topdir ${RPM_TOP}"
for kind in spark flink; do
  if [[ "${kind}" == spark ]]; then
    pkg=bigdata-iceberg-spark
    jar="${spark_jars[0]}"
    install_dir=/usr/lib/spark/jars
  else
    pkg=bigdata-iceberg-flink
    jar="${flink_jars[0]}"
    install_dir=/usr/lib/flink/lib
  fi
  install -m 0644 "${jar}" "${RPM_TOP}/SOURCES/${kind}-runtime.jar"
  install -m 0644 "${SOURCE_DIR}/LICENSE" "${RPM_TOP}/SOURCES/LICENSE"
  install -m 0644 "${SOURCE_DIR}/NOTICE" "${RPM_TOP}/SOURCES/NOTICE"
  cat > "${RPM_TOP}/SPECS/${pkg}.spec" <<EOF
Name:           ${pkg}
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        Apache Iceberg ${kind} runtime for the BIGDATA platform
License:        Apache-2.0
URL:            https://iceberg.apache.org/
BuildArch:      noarch
Requires:       ${kind}

%description
The pinned Apache Iceberg ${VERSION} runtime integration for the platform's ${kind} engine.

%prep

%build

%install
mkdir -p %{buildroot}${install_dir}
install -m 0644 %{_sourcedir}/${kind}-runtime.jar %{buildroot}${install_dir}/${jar##*/}

%files
%license %{_licensedir}/bigdata-iceberg/LICENSE
%license %{_licensedir}/bigdata-iceberg/NOTICE
${install_dir}/${jar##*/}

%prep
mkdir -p %{buildroot}%{_licensedir}/bigdata-iceberg
install -m 0644 %{_sourcedir}/LICENSE %{buildroot}%{_licensedir}/bigdata-iceberg/LICENSE
install -m 0644 %{_sourcedir}/NOTICE %{buildroot}%{_licensedir}/bigdata-iceberg/NOTICE
EOF
  rpmbuild --define "_topdir ${RPM_TOP}" -bb "${RPM_TOP}/SPECS/${pkg}.spec"
done
mapfile -t rpms < <(find "${RPM_TOP}/RPMS" -type f -name '*.rpm' -print)
[[ "${#rpms[@]}" -eq 2 ]]
for rpm_file in "${rpms[@]}"; do
  name="$(rpm -qp --queryformat '%{NAME}' "${rpm_file}")"
  version="$(rpm -qp --queryformat '%{VERSION}' "${rpm_file}")"
  arch="$(rpm -qp --queryformat '%{ARCH}' "${rpm_file}")"
  [[ "${version}" == "${VERSION}" && "${arch}" == noarch ]]
  case "${name}" in
    bigdata-iceberg-spark|bigdata-iceberg-flink) ;;
    *) echo "Unexpected RPM package: ${name}" >&2; exit 1 ;;
  esac
  cp -v "${rpm_file}" "${ARTIFACTS}/rpms/"
done
(cd "${ARTIFACTS}" && sha256sum rpms/*.rpm > evidence/SHA256SUMS)
printf '%s\n' bigdata-iceberg-flink bigdata-iceberg-spark | LC_ALL=C sort > "${ARTIFACTS}/evidence/package-list.txt"
cat > "${ARTIFACTS}/evidence/evidence.md" <<EOF
# CI Evidence — Iceberg Integration RPM Build
schema: bigdata.evidence/v1
stage: build
component: ${COMPONENT}
version: ${VERSION}
artifact_type: integration-rpm
test_profile: iceberg-cross-engine-smoke
source_identity: ${actual_source_identity}
compatibility_identity: ${COMPONENT_COMPATIBILITY_IDENTITY:-}
build_run_id: ${BUILD_RUN_ID}
runtime_packages: ${COMPONENT_RUNTIME_PACKAGES}
toolchain_jdk: 17
rpm_count: 2
status: PASS
EOF
printf 'Built Iceberg %s Spark/Flink integration RPMs from %s\n' "${VERSION}" "${actual_source_identity}"
