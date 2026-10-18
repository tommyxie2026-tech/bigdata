#!/usr/bin/env bash
set -euo pipefail

# Compile only the pinned PostgreSQL SQL source; the separate Test job is mandatory.
source_sha=06581fc73b84b1da45fccf93441d96a118d9bfc1
version=3.4.0
output=/work/output
mkdir -p "${output}"
grep -qi openeuler /etc/os-release
dnf -y --disablerepo='*' --enablerepo=OS,everything install ca-certificates git java-11-openjdk-devel maven
javac_path="$(rpm -ql java-11-openjdk-devel | awk '/[/]bin[/]javac$/ && !found {print; found=1} END {if (!found) exit 1}')"
JAVA_HOME="$(dirname "$(dirname "${javac_path}")")"
export JAVA_HOME
export PATH="${JAVA_HOME}/bin:${PATH}"
javac -version 2>&1 | grep -Eq '^javac 11([.]|$)'
java -version > "${output}/java-version.txt" 2>&1
mvn -version > "${output}/maven-version.txt" 2>&1
git init /work/source
git -C /work/source remote add origin https://github.com/apache/flink-cdc.git
git -C /work/source fetch --depth=1 origin "${source_sha}"
git -C /work/source checkout --detach FETCH_HEAD
[[ "$(git -C /work/source rev-parse HEAD)" == "${source_sha}" ]]
cd /work/source
bash /workspace/scripts/ci/retry-maven-downloads.sh "${output}/compile.log" \
  mvn -B -ntp -T 2 -DskipTests \
    -pl flink-cdc-connect/flink-cdc-source-connectors/flink-sql-connector-postgres-cdc \
    -am package
jar_path="flink-cdc-connect/flink-cdc-source-connectors/flink-sql-connector-postgres-cdc/target/flink-sql-connector-postgres-cdc-${version}.jar"
[[ -s "${jar_path}" ]]
jar tf "${jar_path}" > "${output}/jar-entries.txt"
grep -q 'PostgreSQLTableFactory.class' "${output}/jar-entries.txt"
grep -q '^org/postgresql/Driver.class$' "$output/jar-entries.txt"
install -m 0644 "${jar_path}" "${output}/"
(cd "${output}" && sha256sum "flink-sql-connector-postgres-cdc-${version}.jar" > SHA256SUMS)
cat > "${output}/evidence.md" <<EOF
stage: source-feasibility
component: flink-cdc-postgres
version: ${version}
source_identity: ${source_sha}
jdk: 11
engine_target: flink-1.20.1
postgres_jdbc_driver_bundled: true
compilation: PASS
rpm_build: NOT_RUN
integration_test: NOT_RUN
release: NOT_RUN
EOF
