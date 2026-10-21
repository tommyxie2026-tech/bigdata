#!/usr/bin/env bash
set -euo pipefail
: "${CONNECTOR:?}" "${CDC_WAREHOUSE:?}" "${STORAGE_STARTED_BEFORE:?}" "${STORAGE_STARTED_AFTER:?}"
[[ "$STORAGE_STARTED_BEFORE" != "$STORAGE_STARTED_AFTER" ]]
export CDC_TARGET=paimon
# shellcheck source=scripts/cdc-lakehouse/s3-runtime.sh
source /workspace/scripts/cdc-lakehouse/s3-runtime.sh
java_bin=$(rpm -ql java-11-openjdk-headless | awk '/\/bin\/java$/ && !found {print; found=1}')
test -x "$java_bin"
case "$CONNECTOR" in
  mysql) main_class=MysqlSmoke ;;
  postgres) main_class=PostgresSmoke ;;
  *) exit 2 ;;
esac
timeout 150 "$java_bin" -cp "/usr/lib/flink/lib/*:/tmp/cdc-harness/target/cdc-$CONNECTOR-smoke-1.jar:$HADOOP_CLASSPATH" \
  "bigdata.ci.$main_class" assert restored > /evidence/s3-restarted-rows.txt
grep -q '^paimon: PASS exact_rows=' /evidence/s3-restarted-rows.txt
printf 's3_service_started_before: %s\ns3_service_started_after: %s\ns3_service_restart_exact_rows: PASS\n' "$STORAGE_STARTED_BEFORE" "$STORAGE_STARTED_AFTER" >> /evidence/evidence.md
