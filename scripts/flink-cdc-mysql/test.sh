#!/usr/bin/env bash
set -euo pipefail
: "${BUILD_RUN_ID:?}"
: "${TEST_RUN_ID:?}"
mkdir -p /evidence
cleanup() {
  status=$?
  timeout 20 runuser -u flink -- env FLINK_LOG_DIR=/var/log/flink /usr/lib/flink/bin/taskmanager.sh stop || true
  timeout 20 runuser -u flink -- env FLINK_LOG_DIR=/var/log/flink /usr/lib/flink/bin/jobmanager.sh stop || true
  cp -R /var/log/flink /evidence/flink-logs 2>/dev/null || true
  return "$status"
}
trap cleanup EXIT
# shellcheck source=scripts/cdc-lakehouse/java-runtime.sh
source /workspace/scripts/cdc-lakehouse/java-runtime.sh
dnf -y install "java-$CDC_JDK-openjdk-devel" maven python3 curl procps-ng
for component in flink/1.20.1 hadoop/3.4.3 common/3.6.0; do
  name="${component%%/*}"
  printf '[cdc-%s]\nname=CDC fixture %s\nbaseurl=file:///dependencies/%s\nenabled=1\ngpgcheck=0\n' \
    "$name" "$name" "$component" > "/etc/yum.repos.d/cdc-$name.repo"
done
(cd /rpm && sha256sum -c evidence/SHA256SUMS)
grep -qx 'source_identity: 06581fc73b84b1da45fccf93441d96a118d9bfc1' /rpm/evidence/evidence.md
grep -qx "build_run_id: $BUILD_RUN_ID" /rpm/evidence/evidence.md
grep -qx 'status: PASS' /rpm/evidence/evidence.md
rpms=(/rpm/rpms/*.rpm)
[[ "${#rpms[@]}" -eq 1 ]]
[[ "$(rpm -qp --queryformat '%{NAME} %{VERSION} %{ARCH}' "${rpms[0]}")" == 'bigdata-flink-cdc-mysql 3.4.0 noarch' ]]
dnf -y install flink flink-jobmanager flink-taskmanager "${rpms[0]}"
javac_path="$(rpm -ql "java-$CDC_JDK-openjdk-devel" | awk '/[/]bin[/]javac$/ && !found {print; found=1}')"
JAVA_HOME="$(dirname "$(dirname "$javac_path")")"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
java -version 2>&1 | grep -Eq "version \"$CDC_JDK([.]|\")"
cp -R /workspace/scripts/flink-cdc-mysql/harness /tmp/cdc-harness
# shellcheck source=scripts/cdc-lakehouse/prepare-target.sh
source /workspace/scripts/cdc-lakehouse/prepare-target.sh
bash /workspace/scripts/ci/retry-maven-downloads.sh /evidence/harness-build.log \
  mvn -B -ntp -f /tmp/cdc-harness/pom.xml -DskipTests package
bash /workspace/scripts/ci/retry-maven-downloads.sh /evidence/jdbc-driver-download.log \
  mvn -B -ntp org.apache.maven.plugins:maven-dependency-plugin:3.6.1:copy \
  -Dartifact=mysql:mysql-connector-java:8.0.27 \
  -DoutputDirectory=/usr/lib/flink/lib
jar tf /usr/lib/flink/lib/flink-sql-connector-mysql-cdc-3.4.0.jar > /evidence/connector-entries.txt
if grep -q '^com/mysql/' /evidence/connector-entries.txt; then exit 1; fi
harness=/tmp/cdc-harness/target/cdc-mysql-smoke-1.jar
fixture() { timeout 150 java -cp "/usr/lib/flink/lib/*:$harness:${HADOOP_CLASSPATH:-}" bigdata.ci.MysqlSmoke "$@"; }
fixture prepare
mkdir -p /var/lib/flink/cdc-tmp /var/lib/flink/cdc-savepoints /var/lib/flink/cdc-checkpoints
chown -R flink:flink /var/lib/flink
cat > /etc/flink/conf/flink-conf.yaml <<'CONF'
jobmanager.rpc.address: localhost
jobmanager.bind-host: 127.0.0.1
rest.address: localhost
rest.bind-address: 127.0.0.1
taskmanager.bind-host: 127.0.0.1
taskmanager.host: localhost
taskmanager.numberOfTaskSlots: 2
taskmanager.memory.process.size: 1536m
jobmanager.memory.process.size: 1024m
parallelism.default: 1
io.tmp.dirs: /var/lib/flink/cdc-tmp
CONF
flink() {
  timeout 120 runuser -u flink -- env JAVA_HOME="$JAVA_HOME" FLINK_LOG_DIR=/var/log/flink \
    CDC_TARGET="${CDC_TARGET:-jdbc}" HADOOP_CLASSPATH="${HADOOP_CLASSPATH:-}" \
    FLINK_CONF_DIR=/etc/flink/conf /usr/lib/flink/bin/flink "$@"
}
rest() { curl --fail --silent --show-error --connect-timeout 2 --max-time 5 "$@"; }
runuser -u flink -- env JAVA_HOME="$JAVA_HOME" FLINK_LOG_DIR=/var/log/flink \
  FLINK_CONF_DIR=/etc/flink/conf /usr/lib/flink/bin/jobmanager.sh start
runuser -u flink -- env JAVA_HOME="$JAVA_HOME" FLINK_LOG_DIR=/var/log/flink \
  FLINK_CONF_DIR=/etc/flink/conf /usr/lib/flink/bin/taskmanager.sh start
for _ in $(seq 1 60); do
  if rest http://127.0.0.1:8081/overview > /evidence/overview.json; then break; fi
  sleep 2
done
rest http://127.0.0.1:8081/overview > /evidence/overview.json
flink run -d -m localhost:8081 -c bigdata.ci.MysqlSmoke "$harness" job > /evidence/submit.log 2>&1
job_id="$(sed -n 's/.*Job has been submitted with JobID \([0-9a-f]*\).*/\1/p' /evidence/submit.log | tail -1)"
[[ "$job_id" =~ ^[0-9a-f]{32}$ ]]
fixture assert snapshot > /evidence/snapshot.txt
fixture mutate
fixture assert changes > /evidence/changes.txt
for _ in $(seq 1 60); do
  rest "http://127.0.0.1:8081/jobs/$job_id/checkpoints" > /evidence/checkpoints.json
  if python3 -c 'import json; d=json.load(open("/evidence/checkpoints.json")); assert d.get("latest",{}).get("completed",{}).get("status") == "COMPLETED"'; then break; fi
  sleep 2
done
python3 -c 'import json; d=json.load(open("/evidence/checkpoints.json")); assert d.get("latest",{}).get("completed",{}).get("status") == "COMPLETED"'
rest -H 'Content-Type: application/json' -X POST \
  -d '{"drain":false,"targetDirectory":"file:///var/lib/flink/cdc-savepoints"}' \
  "http://127.0.0.1:8081/jobs/$job_id/stop" > /evidence/stop.json
request_id="$(python3 -c 'import json; print(json.load(open("/evidence/stop.json"))["request-id"])')"
[[ "$request_id" =~ ^[0-9a-f]{32}$ ]]
for _ in $(seq 1 60); do
  rest "http://127.0.0.1:8081/jobs/$job_id/savepoints/$request_id" > /evidence/savepoint.json
  if python3 /workspace/scripts/flink-cdc-mysql/protocol.py location < /evidence/savepoint.json > /evidence/savepoint-path.txt 2>/dev/null; then break; fi
  sleep 2
done
savepoint="$(python3 /workspace/scripts/flink-cdc-mysql/protocol.py location < /evidence/savepoint.json)"
for _ in $(seq 1 30); do
  rest "http://127.0.0.1:8081/jobs/$job_id" > /evidence/stopped-job.json
  if python3 /workspace/scripts/flink-cdc-mysql/protocol.py stopped < /evidence/stopped-job.json 2>/dev/null; then break; fi
  sleep 2
done
python3 /workspace/scripts/flink-cdc-mysql/protocol.py stopped < /evidence/stopped-job.json
fixture offline
flink run -d -m localhost:8081 -s "$savepoint" -c bigdata.ci.MysqlSmoke "$harness" job > /evidence/restore-submit.log 2>&1
restored_id="$(sed -n 's/.*Job has been submitted with JobID \([0-9a-f]*\).*/\1/p' /evidence/restore-submit.log | tail -1)"
[[ "$restored_id" =~ ^[0-9a-f]{32}$ && "$restored_id" != "$job_id" ]]
fixture assert restored > /evidence/restored-rows.txt
rest "http://127.0.0.1:8081/jobs/$restored_id/checkpoints" > /evidence/restored-checkpoints.json
python3 /workspace/scripts/flink-cdc-mysql/protocol.py restored "$savepoint" < /evidence/restored-checkpoints.json
cat > /evidence/evidence.md <<EOF
stage: test
component: flink-cdc-mysql
version: 3.4.0
source_identity: 06581fc73b84b1da45fccf93441d96a118d9bfc1
build_run_id: $BUILD_RUN_ID
test_run_id: $TEST_RUN_ID
artifact_type: integration-rpm
test_profile: mysql-snapshot-changelog-savepoint
jdk: $CDC_JDK
flink_version: 1.20.1
mysql_version: 8.0.36
mysql_jdbc_driver: 8.0.27
clean_install: PASS
snapshot_exact_rows: PASS
insert_update_delete_exact_rows: PASS
completed_checkpoint: PASS
savepoint_restore_path: PASS
restored_exact_rows: PASS
target: ${CDC_TARGET:-jdbc}
status: PASS
EOF
