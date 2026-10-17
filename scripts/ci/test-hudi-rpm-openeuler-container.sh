#!/usr/bin/env bash
set -euo pipefail
report_smoke_failure() {
  local rc=$?
  local failed_line=${BASH_LINENO[0]}
  printf 'Smoke test command failed at line %s (exit %s): %s\\n' "${failed_line}" "${rc}" "${BASH_COMMAND}" >&2
  if [[ -n "${LOG_DIR:-}" && -d "${LOG_DIR}" ]]; then
    local log_file
    for log_file in "${LOG_DIR}"/*.log; do
      [[ -f "${log_file}" ]] || continue
      printf '\\n--- Last 200 lines of %s ---\\n' "${log_file}" >&2
      tail -n 200 "${log_file}" >&2
    done
  else
    echo "Smoke-test log directory is missing: ${LOG_DIR:-unset}" >&2
  fi
  return "${rc}"
}
trap report_smoke_failure ERR

: "${COMPONENT:?COMPONENT is required}"
: "${VERSION:?VERSION is required}"
: "${BUILD_RUN_ID:?BUILD_RUN_ID is required}"
: "${TEST_RUN_ID:?TEST_RUN_ID is required}"
: "${ARTIFACT_ROOT:?ARTIFACT_ROOT is required}"
: "${EVIDENCE_ROOT:?EVIDENCE_ROOT is required}"
: "${COMPONENT_RUNTIME_PACKAGES:?COMPONENT_RUNTIME_PACKAGES is required}"
: "${COMPONENT_COMPATIBILITY_IDENTITY:?COMPONENT_COMPATIBILITY_IDENTITY is required}"
[[ "${COMPONENT}" == hudi && "${VERSION}" == 1.2.1 ]]
[[ "${TEST_PROFILE}" == hudi-cross-engine-smoke ]]
[[ "${ARTIFACT_TYPE}" == integration-rpm ]]
[[ "${COMPONENT_RUNTIME_PACKAGES}" == "bigdata-hudi-spark bigdata-hudi-flink" ]]
[[ "${EXPECTED_SOURCE_IDENTITY}" == a9185b7c4e83422132c25f2efdf282c5bc6af2c7 ]]
grep -qi openEuler /etc/os-release

REPO_DIR=/tmp/bigdata-hudi-rpm-repo
LOG_DIR="${EVIDENCE_ROOT}/logs"
SPARK_JAR=hudi-spark3.5-bundle_2.12-${VERSION}.jar
FLINK_JAR=hudi-flink1.20-bundle-${VERSION}.jar
mkdir -p "${REPO_DIR}" "${EVIDENCE_ROOT}" "${LOG_DIR}"
chmod 0777 "${LOG_DIR}" # Spark and Flink service users write their test logs here.
dnf -y install ca-certificates createrepo_c curl dnf-utils findutils hadoop-client hadoop-conf-pseudo java-11-openjdk-devel procps-ng rpm shadow-utils
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
grep -qx 'test_profile: hudi-cross-engine-smoke' "${build_evidence}"
grep -qx "build_run_id: ${BUILD_RUN_ID}" "${build_evidence}"
source_identity="$(awk -F ': ' '$1 == "source_identity" {print $2}' "${build_evidence}")"
compatibility_identity="$(awk -F ': ' '$1 == "compatibility_identity" {print $2}' "${build_evidence}")"
[[ "${source_identity}" == "${EXPECTED_SOURCE_IDENTITY}" ]]
[[ "${compatibility_identity}" == "${COMPONENT_COMPATIBILITY_IDENTITY}" ]]
grep -qx 'status: PASS' "${build_evidence}"

rpm_files=("${ARTIFACT_ROOT}"/rpms/*.rpm)
[[ "${#rpm_files[@]}" -eq 2 ]]
(cd "${ARTIFACT_ROOT}" && sha256sum -c evidence/SHA256SUMS)
for rpm_file in "${rpm_files[@]}"; do
  name="$(rpm -qp --queryformat '%{NAME}' "${rpm_file}")"
  version="$(rpm -qp --queryformat '%{VERSION}' "${rpm_file}")"
  arch="$(rpm -qp --queryformat '%{ARCH}' "${rpm_file}")"
  [[ "${version}" == "${VERSION}" && "${arch}" == x86_64 ]]
  case "${name}" in
    bigdata-hudi-spark|bigdata-hudi-flink) ;;
    *) echo "Unexpected Hudi RPM: ${name}" >&2; exit 1 ;;
  esac
  cp -v "${rpm_file}" "${REPO_DIR}/"
done
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
  cat > "/etc/yum.repos.d/hudi-dependency-${dependency_index}.repo" <<EOF
[hudi-dependency-${dependency_index}]
name=Hudi test dependency ${dependency_path}
baseurl=file://${dependency_repo}
enabled=1
gpgcheck=0
repo_gpgcheck=0
metadata_expire=0
EOF
  dependency_index=$((dependency_index + 1))
done
cat > /etc/yum.repos.d/hudi-ci.repo <<EOF
[hudi-ci]
name=Hudi CI RPM
baseurl=file://${REPO_DIR}
enabled=1
gpgcheck=0
metadata_expire=0
EOF
dnf clean all
dnf -y --enablerepo=hudi-ci install bigdata-hudi-spark bigdata-hudi-flink spark flink
rpm -q bigdata-hudi-spark bigdata-hudi-flink spark flink

spark_bundle="/usr/lib/spark/jars/${SPARK_JAR}"
flink_bundle="/usr/lib/flink/lib/${FLINK_JAR}"
[[ -s "${spark_bundle}" && -s "${flink_bundle}" ]]
spark_sql="$(command -v spark-sql)"
flink_sql=/usr/lib/flink/bin/sql-client.sh
[[ -x "${flink_sql}" ]]
id spark
id flink
install -d -o spark -g spark -m 0750 /tmp/hudi-spark-table
install -d -o flink -g flink -m 0750 /tmp/hudi-flink-table /var/log/flink
install -d -o flink -g flink -m 0750 /usr/lib/flink/log /etc/flink/conf
flink_conf=/etc/flink/conf/flink-conf.yaml
touch "${flink_conf}"
chmod 0640 "${flink_conf}"
chown flink:flink "${flink_conf}"
cat >> "${flink_conf}" <<'EOF'
jobmanager.bind-host: 127.0.0.1
jobmanager.rpc.address: 127.0.0.1
rest.bind-address: 127.0.0.1
rest.address: 127.0.0.1
taskmanager.bind-host: 127.0.0.1
taskmanager.host: 127.0.0.1
EOF

cat > /tmp/hudi-spark-write.sql <<'SQL'
CREATE TABLE hudi_spark_ci (
  id STRING,
  name STRING,
  ts BIGINT
) USING hudi
TBLPROPERTIES (type='cow', primaryKey='id', preCombineField='ts')
LOCATION 'file:///tmp/hudi-spark-table';
INSERT INTO hudi_spark_ci VALUES ('42', 'spark-before', 1);
MERGE INTO hudi_spark_ci AS target
USING (SELECT '42' AS id, 'spark-after' AS name, CAST(2 AS BIGINT) AS ts) AS source
ON target.id = source.id
WHEN MATCHED THEN UPDATE SET target.name = source.name, target.ts = source.ts
WHEN NOT MATCHED THEN INSERT (id, name, ts) VALUES (source.id, source.name, source.ts);
SELECT concat(CAST(COUNT(*) AS STRING), ':', CAST(SUM(CASE WHEN name = 'spark-after' THEN 1 ELSE 0 END) AS STRING)) FROM hudi_spark_ci;
SQL
chown spark:spark /tmp/hudi-spark-write.sql
runuser -u spark -- env HOME=/var/lib/spark SPARK_LOCAL_IP=127.0.0.1 HADOOP_CONF_DIR=/etc/hadoop/conf \
  "${spark_sql}" --master 'local[2]' \
  --conf spark.sql.catalogImplementation=in-memory \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.sql.extensions=org.apache.spark.sql.hudi.HoodieSparkSessionExtension \
  --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.hudi.catalog.HoodieCatalog \
  -f /tmp/hudi-spark-write.sql > "${LOG_DIR}/spark-write.log" 2>&1
grep -q '1:1' "${LOG_DIR}/spark-write.log"
echo 'spark_hudi_upsert: PASS' > "${EVIDENCE_ROOT}/spark-write.txt"

cat > /tmp/hudi-flink-write.sql <<'SQL'
SET 'execution.runtime-mode' = 'batch';
CREATE TABLE hudi_flink_ci (
  id STRING PRIMARY KEY NOT ENFORCED,
  name STRING,
  ts BIGINT
) WITH (
  'connector' = 'hudi',
  'path' = 'file:///tmp/hudi-flink-table',
  'table.type' = 'COPY_ON_WRITE',
  'ordering.fields' = 'ts',
  'write.tasks' = '1',
  'compaction.schedule.enabled' = 'false',
  'compaction.async.enabled' = 'false',
  'clean.async.enabled' = 'false'
);
INSERT INTO hudi_flink_ci VALUES ('42', 'flink-before', 1);
INSERT INTO hudi_flink_ci VALUES ('42', 'flink-after', 2);
SQL
chown flink:flink /tmp/hudi-flink-write.sql
hadoop_classpath=''
if command -v hadoop >/dev/null 2>&1; then
  hadoop_classpath="$(hadoop classpath)"
fi
runuser -u flink -- env HOME=/var/lib/flink FLINK_HOME=/usr/lib/flink FLINK_CONF_DIR=/etc/flink/conf \
  HADOOP_CONF_DIR=/etc/hadoop/conf HADOOP_CLASSPATH="${hadoop_classpath}" \
  "${flink_sql}" embedded -j "${flink_bundle}" -f /tmp/hudi-flink-write.sql \
  > "${LOG_DIR}/flink-write.log" 2>&1
[[ -s /tmp/hudi-flink-table/.hoodie/hoodie.properties ]]
echo 'flink_hudi_upsert: PASS' > "${EVIDENCE_ROOT}/flink-write.txt"

cat > /tmp/hudi-spark-cross-read.sql <<'SQL'
CREATE TABLE hudi_flink_output (
  id STRING,
  name STRING,
  ts BIGINT
) USING hudi
TBLPROPERTIES (type='cow', primaryKey='id', preCombineField='ts')
LOCATION 'file:///tmp/hudi-flink-table';
SELECT assert_true(COUNT(*) = 1 AND MAX(name) = 'flink-after') FROM hudi_flink_output;
SQL
chown spark:spark /tmp/hudi-spark-cross-read.sql
runuser -u spark -- env HOME=/var/lib/spark SPARK_LOCAL_IP=127.0.0.1 HADOOP_CONF_DIR=/etc/hadoop/conf \
  "${spark_sql}" --master 'local[2]' \
  --conf spark.sql.catalogImplementation=in-memory \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.sql.extensions=org.apache.spark.sql.hudi.HoodieSparkSessionExtension \
  --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.hudi.catalog.HoodieCatalog \
  -f /tmp/hudi-spark-cross-read.sql > "${LOG_DIR}/spark-cross-read.log" 2>&1
echo 'spark_reads_flink_hudi_commit: PASS' > "${EVIDENCE_ROOT}/spark-cross-read.txt"

cat > /tmp/hudi-flink-cross-read.sql <<'SQL'
SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'tableau';
CREATE TABLE hudi_spark_output (
  id STRING PRIMARY KEY NOT ENFORCED,
  name STRING,
  ts BIGINT
) WITH (
  'connector' = 'hudi',
  'path' = 'file:///tmp/hudi-spark-table',
  'table.type' = 'COPY_ON_WRITE'
);
SELECT id, name, ts FROM hudi_spark_output;
SQL
chown flink:flink /tmp/hudi-flink-cross-read.sql
runuser -u flink -- env HOME=/var/lib/flink FLINK_HOME=/usr/lib/flink FLINK_CONF_DIR=/etc/flink/conf \
  HADOOP_CONF_DIR=/etc/hadoop/conf HADOOP_CLASSPATH="${hadoop_classpath}" \
  "${flink_sql}" embedded -j "${flink_bundle}" -f /tmp/hudi-flink-cross-read.sql \
  > "${LOG_DIR}/flink-cross-read.log" 2>&1
grep -q 'spark-after' "${LOG_DIR}/flink-cross-read.log"
echo 'flink_reads_spark_hudi_commit: PASS' > "${EVIDENCE_ROOT}/flink-cross-read.txt"

cat > "${EVIDENCE_ROOT}/evidence.md" <<EOF
# CI Evidence — Hudi Clean Install and Cross-Engine Smoke
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
spark_hudi_upsert: PASS
flink_hudi_upsert: PASS
spark_reads_flink_hudi_commit: PASS
flink_reads_spark_hudi_commit: PASS
status: PASS
EOF
