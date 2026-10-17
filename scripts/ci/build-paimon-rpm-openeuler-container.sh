#!/usr/bin/env bash
set -euo pipefail

: "${COMPONENT:?COMPONENT is required}"
: "${VERSION:?VERSION is required}"
: "${BUILD_RUN_ID:?BUILD_RUN_ID is required}"
: "${EXPECTED_SOURCE_IDENTITY:?EXPECTED_SOURCE_IDENTITY is required}"
: "${COMPONENT_RUNTIME_PACKAGES:?COMPONENT_RUNTIME_PACKAGES is required}"
WORK_ROOT="${WORK_ROOT:-/work}"
SOURCE_DIR="${WORK_ROOT}/paimon"
ARTIFACTS="${WORK_ROOT}/artifacts"
RPM_TOP="${WORK_ROOT}/rpmbuild"
SPARK_JAR="paimon-spark-3.5_2.12-${VERSION}.jar"
FLINK_JAR="paimon-flink-1.20-${VERSION}.jar"

mkdir -p "${ARTIFACTS}/rpms" "${ARTIFACTS}/logs" "${ARTIFACTS}/evidence"
[[ "${COMPONENT}" == paimon && "${VERSION}" == 2.1.0 ]] || {
  echo "Only catalog-pinned Paimon 2.1.0 is supported." >&2
  exit 2
}
[[ "${EXPECTED_SOURCE_IDENTITY}" == 3a5ffe7870697e2c2605e63413fb5ac5800aae7e ]]
[[ "${COMPONENT_RUNTIME_PACKAGES}" == "bigdata-paimon-spark bigdata-paimon-flink" ]]
grep -qi openEuler /etc/os-release

dnf -y install ca-certificates curl git java-11-openjdk-devel maven rpm-build tar
javac_path="$(rpm -ql java-11-openjdk-devel | awk '/\/bin\/javac$/ { print; exit }')"
[[ -n "${javac_path}" && -x "${javac_path}" ]] || { echo "JDK 11 javac not found in java-11-openjdk-devel." >&2; exit 1; }
export JAVA_HOME="$(dirname "$(dirname "${javac_path}")")"
export PATH="${JAVA_HOME}/bin:${PATH}"
java -version 2>&1 | grep -Eq 'version "11([.]|")'
javac -version 2>&1 | grep -Eq '^javac 11([.]|$)'

rm -rf "${SOURCE_DIR}"
git init "${SOURCE_DIR}"
git -C "${SOURCE_DIR}" remote add origin https://github.com/apache/paimon.git
git -C "${SOURCE_DIR}" fetch --depth=1 origin "${EXPECTED_SOURCE_IDENTITY}"
git -C "${SOURCE_DIR}" -c advice.detachedHead=false checkout --detach FETCH_HEAD
actual_source_identity="$(git -C "${SOURCE_DIR}" rev-parse HEAD)"
[[ "${actual_source_identity}" == "${EXPECTED_SOURCE_IDENTITY}" ]]

cd "${SOURCE_DIR}"
bash /workspace/scripts/ci/retry-maven-downloads.sh "${ARTIFACTS}/logs/paimon-spark-maven-build.log" \
  mvn -T 2C -B -ntp -DskipTests -Pspark3 \
    -pl paimon-spark/paimon-spark-3.5 -am package
bash /workspace/scripts/ci/retry-maven-downloads.sh "${ARTIFACTS}/logs/paimon-flink-maven-build.log" \
  mvn -T 2C -B -ntp -DskipTests -Pflink1 \
    -pl paimon-flink/paimon-flink-1.20 -am package

mapfile -t spark_jars < <(find paimon-spark/paimon-spark-3.5/target -maxdepth 1 -type f -name "${SPARK_JAR}" -print)
mapfile -t flink_jars < <(find paimon-flink/paimon-flink-1.20/target -maxdepth 1 -type f -name "${FLINK_JAR}" -print)
[[ "${#spark_jars[@]}" -eq 1 && -s "${spark_jars[0]}" ]]
[[ "${#flink_jars[@]}" -eq 1 && -s "${flink_jars[0]}" ]]

mkdir -p "${RPM_TOP}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
for kind in spark flink; do
  if [[ "${kind}" == spark ]]; then
    pkg=bigdata-paimon-spark
    jar="${spark_jars[0]}"
    install_dir=/usr/lib/spark/jars
    engine=spark
  else
    pkg=bigdata-paimon-flink
    jar="${flink_jars[0]}"
    install_dir=/usr/lib/flink/lib
    engine=flink
  fi
  install -m 0644 "${jar}" "${RPM_TOP}/SOURCES/${kind}-bundle.jar"
  install -m 0644 "${SOURCE_DIR}/LICENSE" "${RPM_TOP}/SOURCES/LICENSE"
  install -m 0644 "${SOURCE_DIR}/NOTICE" "${RPM_TOP}/SOURCES/NOTICE"
  cat > "${RPM_TOP}/SPECS/${pkg}.spec" <<EOF
Name:           ${pkg}
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        Apache Paimon ${kind} integration for the BIGDATA platform
License:        Apache-2.0
URL:            https://paimon.apache.org/
Requires:       ${engine}
Requires:       java-11-openjdk

%description
The Apache Paimon ${VERSION} ${kind} bundle built from the pinned upstream release source.

%prep

%build

%install
mkdir -p %{buildroot}${install_dir} %{buildroot}%{_licensedir}/bigdata-paimon
install -m 0644 %{_sourcedir}/${kind}-bundle.jar %{buildroot}${install_dir}/${jar##*/}
install -m 0644 %{_sourcedir}/LICENSE %{buildroot}%{_licensedir}/bigdata-paimon/LICENSE
install -m 0644 %{_sourcedir}/NOTICE %{buildroot}%{_licensedir}/bigdata-paimon/NOTICE

%files
%license %{_licensedir}/bigdata-paimon/LICENSE
%license %{_licensedir}/bigdata-paimon/NOTICE
${install_dir}/${jar##*/}
EOF
  rpmbuild --define "_topdir ${RPM_TOP}" -bb "${RPM_TOP}/SPECS/${pkg}.spec"
done

mapfile -t rpms < <(find "${RPM_TOP}/RPMS" -type f -name '*.rpm' -print)
[[ "${#rpms[@]}" -eq 2 ]]
declare -A found_packages=()
for rpm_file in "${rpms[@]}"; do
  name="$(rpm -qp --queryformat '%{NAME}' "${rpm_file}")"
  version="$(rpm -qp --queryformat '%{VERSION}' "${rpm_file}")"
  arch="$(rpm -qp --queryformat '%{ARCH}' "${rpm_file}")"
  [[ "${version}" == "${VERSION}" && "${arch}" == x86_64 ]]
  case "${name}" in
    bigdata-paimon-spark|bigdata-paimon-flink) ;;
    *) echo "Unexpected RPM package: ${name}" >&2; exit 1 ;;
  esac
  [[ -z "${found_packages[${name}]:-}" ]] || { echo "Duplicate RPM package: ${name}" >&2; exit 1; }
  found_packages["${name}"]=true
  cp -v "${rpm_file}" "${ARTIFACTS}/rpms/"
done
[[ -n "${found_packages[bigdata-paimon-spark]:-}" && -n "${found_packages[bigdata-paimon-flink]:-}" ]]

(cd "${ARTIFACTS}" && sha256sum rpms/*.rpm > evidence/SHA256SUMS)
printf '%s\n' bigdata-paimon-flink bigdata-paimon-spark | LC_ALL=C sort > "${ARTIFACTS}/evidence/package-list.txt"
cat > "${ARTIFACTS}/evidence/evidence.md" <<EOF
# CI Evidence — Paimon Integration RPM Build
schema: bigdata.evidence/v1
stage: build
component: ${COMPONENT}
version: ${VERSION}
artifact_type: integration-rpm
test_profile: paimon-cross-engine-smoke
source_identity: ${actual_source_identity}
compatibility_identity: ${COMPONENT_COMPATIBILITY_IDENTITY:-}
build_run_id: ${BUILD_RUN_ID}
runtime_packages: ${COMPONENT_RUNTIME_PACKAGES}
toolchain_jdk: 11
rpm_arch: x86_64
rpm_count: 2
status: PASS
EOF
printf 'Built Paimon %s Spark/Flink RPMs from %s\n' "${VERSION}" "${actual_source_identity}"
