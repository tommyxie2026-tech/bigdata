#!/usr/bin/env bash
set -euo pipefail
trap 'rc=$?; printf "Smoke test command failed at line %s (exit %s): %s\\n" "$LINENO" "$rc" "$BASH_COMMAND" >&2; exit "$rc"' ERR

: "${COMPONENT:?COMPONENT is required}"
: "${VERSION:?VERSION is required}"
: "${BUILD_RUN_ID:?BUILD_RUN_ID is required}"
: "${TEST_RUN_ID:?TEST_RUN_ID is required}"
: "${ARTIFACT_ROOT:?ARTIFACT_ROOT is required}"
: "${EVIDENCE_ROOT:?EVIDENCE_ROOT is required}"
: "${COMPONENT_RUNTIME_PACKAGES:?COMPONENT_RUNTIME_PACKAGES is required}"
: "${COMPONENT_COMPATIBILITY_IDENTITY:?COMPONENT_COMPATIBILITY_IDENTITY is required}"
[[ "${COMPONENT}" == paimon && "${VERSION}" == 2.1.0 ]]
[[ "${TEST_PROFILE}" == paimon-cross-engine-smoke ]]
[[ "${ARTIFACT_TYPE}" == integration-rpm ]]
[[ "${COMPONENT_RUNTIME_PACKAGES}" == "bigdata-paimon-spark bigdata-paimon-flink" ]]
[[ "${EXPECTED_SOURCE_IDENTITY}" == 3a5ffe7870697e2c2605e63413fb5ac5800aae7e ]]
grep -qi openEuler /etc/os-release

REPO_DIR=/tmp/bigdata-paimon-rpm-repo
LOG_DIR="${EVIDENCE_ROOT}/logs"
SPARK_JAR=paimon-spark-3.5_2.12-${VERSION}.jar
FLINK_JAR=paimon-flink-1.20-${VERSION}.jar
mkdir -p "${REPO_DIR}" "${EVIDENCE_ROOT}" "${LOG_DIR}"
chmod 0777 "${LOG_DIR}" # Spark and Flink service users write their test logs here.
dnf -y install ca-certificates createrepo_c findutils java-11-openjdk-devel procps-ng rpm shadow-utils util-linux
javac_path="$(rpm -ql java-11-openjdk-devel | awk '/\/bin\/javac$/ && !found { print; found=1 } END { if (!found) exit 1 }')"
[[ -n "${javac_path}" && -x "${javac_path}" ]] || { echo "JDK 11 javac not found in java-11-openjdk-devel." >&2; exit 1; }
JAVA_HOME="$(dirname "$(dirname "${javac_path}")")"
export JAVA_HOME
PATH="${JAVA_HOME}/bin:${PATH}"
export PATH
java -version 2>&1 | grep -Eq 'version "11([.]|")'

build_evidence="${ARTIFACT_ROOT}/evidence/evidence.md"
[[ -s "${build_evidence}" ]]
grep -qx "component: ${COMPONENT}" "${build_evidence}"
grep -qx "version: ${VERSION}" "${build_evidence}"
grep -qx 'artifact_type: integration-rpm' "${build_evidence}"
grep -qx 'test_profile: paimon-cross-engine-smoke' "${build_evidence}"
grep -qx "build_run_id: ${BUILD_RUN_ID}" "${build_evidence}"
source_identity="$(awk -F ': ' '$1 == "source_identity" {print $2}' "${build_evidence}")"
compatibility_identity="$(awk -F ': ' '$1 == "compatibility_identity" {print $2}' "${build_evidence}")"
[[ "${source_identity}" == "${EXPECTED_SOURCE_IDENTITY}" ]]
[[ "${compatibility_identity}" == "${COMPONENT_COMPATIBILITY_IDENTITY}" ]]
grep -qx 'status: PASS' "${build_evidence}"

rpm_files=("${ARTIFACT_ROOT}"/rpms/*.rpm)
[[ "${#rpm_files[@]}" -eq 2 ]]
(cd "${ARTIFACT_ROOT}" && sha256sum -c evidence/SHA256SUMS)
declare -A found_packages=()
for rpm_file in "${rpm_files[@]}"; do
  name="$(rpm -qp --queryformat '%{NAME}' "${rpm_file}")"
  version="$(rpm -qp --queryformat '%{VERSION}' "${rpm_file}")"
  arch="$(rpm -qp --queryformat '%{ARCH}' "${rpm_file}")"
  [[ "${version}" == "${VERSION}" && "${arch}" == x86_64 ]]
  case "${name}" in
    bigdata-paimon-spark|bigdata-paimon-flink) ;;
    *) echo "Unexpected Paimon RPM: ${name}" >&2; exit 1 ;;
  esac
  [[ -z "${found_packages[${name}]:-}" ]] || { echo "Duplicate RPM package: ${name}" >&2; exit 1; }
  found_packages["${name}"]=true
  cp -v "${rpm_file}" "${REPO_DIR}/"
done
[[ -n "${found_packages[bigdata-paimon-spark]:-}" && -n "${found_packages[bigdata-paimon-flink]:-}" ]]
createrepo_c --no-database "${REPO_DIR}"

dependency_index=0
IFS=',' read -r -a dependency_paths <<< "${DEPENDENCY_REPO_PATHS:-}"
for dependency_path in "${dependency_paths[@]}"; do
  [[ -n "${dependency_path}" ]] || continue
  dependency_repo="/dependency-repos/${dependency_path}"
  [[ -f "${dependency_repo}/repodata/repomd.xml" ]] || {
    echo "Missing dependency repository metadata: ${dependency_repo}" >&2
    exit 1
  }
  cat > "/etc/yum.repos.d/paimon-dependency-${dependency_index}.repo" <<EOF
[paimon-dependency-${dependency_index}]
name=Paimon test dependency ${dependency_path}
baseurl=file://${dependency_repo}
enabled=1
gpgcheck=0
repo_gpgcheck=0
metadata_expire=0
EOF
  dependency_index=$((dependency_index + 1))
done
cat > /etc/yum.repos.d/paimon-ci.repo <<EOF
[paimon-ci]
name=Paimon CI RPM
baseurl=file://${REPO_DIR}
enabled=1
gpgcheck=0
metadata_expire=0
EOF
dnf clean all
dnf -y --enablerepo=paimon-ci install bigdata-paimon-spark bigdata-paimon-flink spark flink
rpm -q bigdata-paimon-spark bigdata-paimon-flink spark flink

spark_bundle="/usr/lib/spark/jars/${SPARK_JAR}"
flink_bundle="/usr/lib/flink/lib/${FLINK_JAR}"
[[ -s "${spark_bundle}" && -s "${flink_bundle}" ]]
spark_sql="$(command -v spark-sql)"
flink_sql=/usr/lib/flink/bin/sql-client.sh
[[ -x "${flink_sql}" ]]
id spark
id flink

rm -rf /tmp/paimon-spark-table /tmp/paimon-flink-table
install -d -m 0777 /tmp/paimon-spark-table /tmp/paimon-flink-table
install -d -o spark -g spark -m 0750 /var/log/spark
install -d -o flink -g flink -m 0750 /var/log/flink

cat > /tmp/paimon-spark.sql <<'SQL'
CREATE TABLE paimon.default.paimon_spark_ci (
  id BIGINT,
  name STRING
) TBLPROPERTIES (
  'primary-key' = 'id',
  'bucket' = '1'
);
INSERT INTO paimon.default.paimon_spark_ci VALUES (42, 'spark-before');
INSERT INTO paimon.default.paimon_spark_ci VALUES (42, 'spark-after');
SELECT assert_true(COUNT(*) = 1 AND MAX(name) = 'spark-after') FROM paimon.default.paimon_spark_ci;
SQL
chown spark:spark /tmp/paimon-spark.sql
runuser -u spark -- bash -c 'umask 000; exec env HOME=/var/lib/spark SPARK_LOCAL_IP=127.0.0.1 HADOOP_CONF_DIR=/etc/hadoop/conf "$1" --master "local[2]" --conf spark.sql.catalog.paimon=org.apache.paimon.spark.SparkCatalog --conf spark.sql.catalog.paimon.warehouse=file:/tmp/paimon-spark-table --conf spark.sql.extensions=org.apache.paimon.spark.extensions.PaimonSparkSessionExtensions -f /tmp/paimon-spark.sql' _ "${spark_sql}" > "${LOG_DIR}/spark-write.log" 2>&1
grep -q 'spark-after' "${LOG_DIR}/spark-write.log"
chmod -R a+rwX /tmp/paimon-spark-table
echo 'spark_paimon_upsert: PASS' > "${EVIDENCE_ROOT}/spark-write.txt"

cat > /tmp/paimon-flink.sql <<'SQL'
SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'tableau';
CREATE CATALOG paimon_catalog WITH (
  'type' = 'paimon',
  'warehouse' = 'file:/tmp/paimon-flink-table'
);
USE CATALOG paimon_catalog;
CREATE TABLE paimon_flink_ci (
  id BIGINT,
  name STRING,
  PRIMARY KEY (id) NOT ENFORCED
) WITH ('bucket' = '1');
INSERT INTO paimon_flink_ci VALUES (42, 'flink-before');
INSERT INTO paimon_flink_ci VALUES (42, 'flink-after');
SELECT * FROM paimon_flink_ci;
SQL
chown flink:flink /tmp/paimon-flink.sql
runuser -u flink -- bash -c 'umask 000; exec env HOME=/var/lib/flink FLINK_HOME=/usr/lib/flink FLINK_CONF_DIR=/etc/flink/conf HADOOP_CONF_DIR=/etc/hadoop/conf "$1" embedded -j "$2" -f /tmp/paimon-flink.sql' _ "${flink_sql}" "${flink_bundle}" > "${LOG_DIR}/flink-write.log" 2>&1
grep -q 'flink-after' "${LOG_DIR}/flink-write.log"
chmod -R a+rwX /tmp/paimon-flink-table
echo 'flink_paimon_upsert: PASS' > "${EVIDENCE_ROOT}/flink-write.txt"

cat > /tmp/paimon-spark-cross-read.sql <<'SQL'
SELECT assert_true(COUNT(*) = 1 AND MAX(name) = 'flink-after') FROM paimon.default.paimon_flink_ci;
SQL
chown spark:spark /tmp/paimon-spark-cross-read.sql
runuser -u spark -- env HOME=/var/lib/spark SPARK_LOCAL_IP=127.0.0.1 HADOOP_CONF_DIR=/etc/hadoop/conf   "${spark_sql}" --master 'local[2]'   --conf spark.sql.catalog.paimon=org.apache.paimon.spark.SparkCatalog   --conf spark.sql.catalog.paimon.warehouse=file:/tmp/paimon-flink-table   --conf spark.sql.extensions=org.apache.paimon.spark.extensions.PaimonSparkSessionExtensions   -f /tmp/paimon-spark-cross-read.sql > "${LOG_DIR}/spark-cross-read.log" 2>&1
echo 'spark_reads_flink_paimon_table: PASS' > "${EVIDENCE_ROOT}/spark-cross-read.txt"

cat > /tmp/paimon-flink-cross-read.sql <<'SQL'
SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'tableau';
CREATE CATALOG paimon_catalog WITH (
  'type' = 'paimon',
  'warehouse' = 'file:/tmp/paimon-spark-table'
);
USE CATALOG paimon_catalog;
SELECT * FROM paimon_spark_ci;
SQL
chown flink:flink /tmp/paimon-flink-cross-read.sql
runuser -u flink -- env HOME=/var/lib/flink FLINK_HOME=/usr/lib/flink FLINK_CONF_DIR=/etc/flink/conf HADOOP_CONF_DIR=/etc/hadoop/conf   "${flink_sql}" embedded -j "${flink_bundle}" -f /tmp/paimon-flink-cross-read.sql > "${LOG_DIR}/flink-cross-read.log" 2>&1
grep -q 'spark-after' "${LOG_DIR}/flink-cross-read.log"
echo 'flink_reads_spark_paimon_table: PASS' > "${EVIDENCE_ROOT}/flink-cross-read.txt"

cat > "${EVIDENCE_ROOT}/evidence.md" <<EOF
# CI Evidence — Paimon Clean Install and Cross-Engine Smoke
schema: bigdata.evidence/v1
stage: test
component: ${COMPONENT}
version: ${VERSION}
artifact_type: integration-rpm
test_profile: ${TEST_PROFILE}
toolchain_jdk: ${COMPONENT_JDK}
jdk_package: ${COMPONENT_JDK_PACKAGE}
source_identity: ${source_identity}
compatibility_identity: ${compatibility_identity}
build_run_id: ${BUILD_RUN_ID}
test_run_id: ${TEST_RUN_ID}
runtime_packages: ${COMPONENT_RUNTIME_PACKAGES}
environment: openEuler-22.03-LTS-SP4-clean-container
repository: local-createrepo-c
dependency_repositories: ${DEPENDENCY_REPO_PATHS}
dnf_install: PASS
spark_paimon_upsert: PASS
flink_paimon_upsert: PASS
spark_reads_flink_paimon_table: PASS
flink_reads_spark_paimon_table: PASS
status: PASS
EOF
