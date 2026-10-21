#!/usr/bin/env bash
set -euo pipefail
java_bin=$(rpm -ql java-1.8.0-openjdk-headless | awk '/\/bin\/java$/ && !found {print; found=1}')
test -x "$java_bin"
export JAVA_HOME
JAVA_HOME=$(dirname "$(dirname "$java_bin")")
export HBASE_LOG_DIR=/var/log/ams-hbase HBASE_PID_DIR=/var/run/ams-hbase HBASE_HEAPSIZE=768
case "${1:?service required}" in
  hbase) exec /usr/lib/ams-hbase/bin/hbase --config /etc/ams-hbase/conf master start ;;
  collector)
    exec "$java_bin" -Xms256m -Xmx768m -Djava.net.preferIPv4Stack=true \
      -Dams.log.dir=/var/log/ambari-metrics-collector \
      -cp '/etc/ambari-metrics-collector/conf:/usr/lib/ambari-metrics-collector/*' \
      org.apache.ambari.metrics.AMSApplicationServer
    ;;
  *) exit 2 ;;
esac
