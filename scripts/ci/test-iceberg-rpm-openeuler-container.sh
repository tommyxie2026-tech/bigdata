#!/usr/bin/env bash
set -euo pipefail
: "${COMPONENT:?COMPONENT is required}"
: "${VERSION:?VERSION is required}"
: "${BUILD_RUN_ID:?BUILD_RUN_ID is required}"
: "${TEST_RUN_ID:?TEST_RUN_ID is required}"
: "${ARTIFACT_ROOT:?ARTIFACT_ROOT is required}"
: "${EVIDENCE_ROOT:?EVIDENCE_ROOT is required}"
: "${COMPONENT_COMPATIBILITY_IDENTITY:?COMPONENT_COMPATIBILITY_IDENTITY is required}"
: "${COMPONENT_RUNTIME_PACKAGES:?COMPONENT_RUNTIME_PACKAGES is required}"
REPO_DIR=/tmp/bigdata-iceberg-rpm-repo
LOG_DIR="${EVIDENCE_ROOT}/logs"
[[ "${COMPONENT}" == iceberg && "${VERSION}" == 1.12.0 ]]
[[ "${TEST_PROFILE}" == iceberg-cross-engine-smoke ]]
[[ "${ARTIFACT_TYPE}" == integration-rpm ]]
[[ "${COMPONENT_RUNTIME_PACKAGES}" == "bigdata-iceberg-spark bigdata-iceberg-flink" ]]
grep -qi openEuler /etc/os-release
mkdir -p "${EVIDENCE_ROOT}" "${LOG_DIR}" "${REPO_DIR}"
dnf -y install ca-certificates coreutils createrepo_c dnf-utils findutils java-17-openjdk-devel procps-ng python3 rpm
build_evidence="${ARTIFACT_ROOT}/evidence/evidence.md"
[[ -s "${build_evidence}" ]]
grep -qx "component: ${COMPONENT}" "${build_evidence}"
grep -qx "version: ${VERSION}" "${build_evidence}"
grep -qx 'artifact_type: integration-rpm' "${build_evidence}"
grep -qx 'test_profile: iceberg-cross-engine-smoke' "${build_evidence}"
grep -qx "build_run_id: ${BUILD_RUN_ID}" "${build_evidence}"
source_identity="$(awk -F ': ' '$1 == "source_identity" {print $2}' "${build_evidence}")"
compatibility_identity="$(awk -F ': ' '$1 == "compatibility_identity" {print $2}' "${build_evidence}")"
[[ "${source_identity}" == "${EXPECTED_SOURCE_IDENTITY}" ]]
[[ "${compatibility_identity}" =~ ^[0-9a-f]{64}$ ]]
if [[ "${compatibility_identity}" != "${COMPONENT_COMPATIBILITY_IDENTITY}" ]]; then
  printf 'Iceberg RPM compatibility identity mismatch: artifact=%s expected=%s\n' \
    "${compatibility_identity}" "${COMPONENT_COMPATIBILITY_IDENTITY}" >&2
  exit 1
fi
rpm_files=("${ARTIFACT_ROOT}"/rpms/*.rpm)
[[ "${#rpm_files[@]}" -eq 2 ]]
rpm_names=()
for rpm_file in "${rpm_files[@]}"; do
  rpm_name="$(rpm -qp --queryformat '%{NAME}' "${rpm_file}")"
  rpm_version="$(rpm -qp --queryformat '%{VERSION}' "${rpm_file}")"
  rpm_arch="$(rpm -qp --queryformat '%{ARCH}' "${rpm_file}")"
  [[ "${rpm_version}" == "${VERSION}" && "${rpm_arch}" == noarch ]]
  rpm_names+=("${rpm_name}")
done
printf '%s\n' "${rpm_names[@]}" | LC_ALL=C sort > "${EVIDENCE_ROOT}/rpm-package-names.txt"
printf '%s\n' bigdata-iceberg-flink bigdata-iceberg-spark | LC_ALL=C sort > "${EVIDENCE_ROOT}/expected-rpm-package-names.txt"
diff -u "${EVIDENCE_ROOT}/expected-rpm-package-names.txt" "${EVIDENCE_ROOT}/rpm-package-names.txt"
(cd "${ARTIFACT_ROOT}" && sha256sum -c evidence/SHA256SUMS)
cp -v "${rpm_files[@]}" "${REPO_DIR}/"
createrepo_c --no-database "${REPO_DIR}"
cat > /etc/yum.repos.d/iceberg-ci.repo <<EOF
[iceberg-ci]
name=Iceberg integration CI RPMs
baseurl=file://${REPO_DIR}
enabled=1
gpgcheck=0
metadata_expire=0
EOF
dependency_index=0
IFS=',' read -r -a dependency_paths <<< "${DEPENDENCY_REPO_PATHS:-}"
for dependency_path in "${dependency_paths[@]}"; do
  [[ -n "${dependency_path}" ]] || continue
  dependency_repo="/dependency-repos/${dependency_path}"
  [[ -f "${dependency_repo}/repodata/repomd.xml" ]] || {
    echo "Missing dependency repository metadata: ${dependency_repo}" >&2
    exit 1
  }
  cat >> /etc/yum.repos.d/iceberg-ci.repo <<EOF

[iceberg-dependency-${dependency_index}]
name=Iceberg CI dependency repository ${dependency_path}
baseurl=file://${dependency_repo}
enabled=1
gpgcheck=0
repo_gpgcheck=0
metadata_expire=0
EOF
  dependency_index=$((dependency_index + 1))
done
dnf clean all
read -r -a runtime_packages <<< "${COMPONENT_RUNTIME_PACKAGES}"
[[ "${#runtime_packages[@]}" -eq 2 ]]
dnf -y --enablerepo=iceberg-ci install "${runtime_packages[@]}"
rpm -q bigdata-iceberg-spark bigdata-iceberg-flink spark flink
rpm -ql bigdata-iceberg-spark | grep -Fx '/usr/lib/spark/jars/iceberg-spark-runtime-3.5_2.12-1.12.0.jar'
rpm -ql bigdata-iceberg-flink | grep -Fx '/usr/lib/flink/lib/iceberg-flink-runtime-1.20-1.12.0.jar'
command -v spark-sql >/dev/null
command -v flink >/dev/null
warehouse=file:///tmp/iceberg-spark-ci-warehouse
spark-sql --master 'local[2]' \
  --conf spark.sql.catalogImplementation=in-memory \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.local=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.local.type=hadoop \
  --conf "spark.sql.catalog.local.warehouse=${warehouse}" \
  -e "CREATE NAMESPACE IF NOT EXISTS local.ci; CREATE TABLE local.ci.events (id BIGINT, value STRING) USING iceberg; INSERT INTO local.ci.events VALUES (1, 'alpha'), (2, 'beta'); SELECT count(*) AS iceberg_rows FROM local.ci.events" \
  2>&1 | tee "${LOG_DIR}/spark-sql-smoke.log"
grep -Eq '(^|[[:space:]])2([[:space:]]|$)' "${LOG_DIR}/spark-sql-smoke.log"
echo 'spark_iceberg_table_roundtrip: PASS' > "${EVIDENCE_ROOT}/spark-smoke.txt"
jshell --class-path '/usr/lib/flink/lib/*' <<'EOF' > "${LOG_DIR}/flink-classpath-smoke.log" 2>&1
Class.forName("org.apache.iceberg.flink.FlinkCatalogFactory");
System.out.println("flink_iceberg_catalog_factory: PASS");
/exit
EOF
grep -q 'flink_iceberg_catalog_factory: PASS' "${LOG_DIR}/flink-classpath-smoke.log"
echo 'flink_iceberg_catalog_factory: PASS' > "${EVIDENCE_ROOT}/flink-smoke.txt"
cat > "${EVIDENCE_ROOT}/evidence.md" <<EOF
# CI Evidence — Iceberg RPM Install and Cross-Engine Smoke
schema: bigdata.evidence/v1
stage: test
component: ${COMPONENT}
version: ${VERSION}
artifact_type: integration-rpm
test_profile: ${TEST_PROFILE}
source_identity: ${source_identity}
compatibility_identity: ${compatibility_identity}
build_run_id: ${BUILD_RUN_ID}
test_run_id: ${TEST_RUN_ID}
runtime_packages: ${COMPONENT_RUNTIME_PACKAGES}
environment: openEuler-22.03-LTS-SP4-clean-container
repository: local-createrepo-c
package_manager: dnf
toolchain_jdk: 17
dnf_install: PASS
spark_iceberg_table_roundtrip: PASS
flink_iceberg_catalog_factory: PASS
status: PASS
EOF
