#!/usr/bin/env bash
# Disposable standalone HDFS service, separate from the Flink client container.
set -Eeuo pipefail
mkdir -p /evidence
rm -f /evidence/hdfs-ready
processes=()
# shellcheck disable=SC2329 # Invoked by EXIT trap.
cleanup() {
  local status=$?
  for pid in "${processes[@]}"; do kill -TERM -- "-$pid" 2>/dev/null || true; done
  return "$status"
}
trap cleanup EXIT
timeout 600 dnf -y --setopt=timeout=30 --setopt=retries=2 install \
  /dependencies/common/3.6.0/*.rpm /dependencies/hadoop/3.4.3/hadoop{,-client,-hdfs,-mapreduce,-yarn}-3.4.3-1.x86_64.rpm \
  java-1.8.0-openjdk-headless procps-ng util-linux
getent passwd hdfs >/dev/null || useradd --system --home-dir /var/lib/cdc-hdfs --shell /sbin/nologin hdfs
java_bin=$(rpm -ql java-1.8.0-openjdk-headless | awk '/\/bin\/java$/ && !found {print; found=1}')
test -x "$java_bin"
export JAVA_HOME HADOOP_CONF_DIR=/etc/cdc-hdfs HADOOP_LOG_DIR=/evidence HADOOP_HEAPSIZE=512
JAVA_HOME=$(dirname "$(dirname "$java_bin")")
mkdir -p "$HADOOP_CONF_DIR" /var/lib/cdc-hdfs/{name,data,tmp}
chown -R hdfs /var/lib/cdc-hdfs /evidence
cat > "$HADOOP_CONF_DIR/core-site.xml" <<'XML'
<configuration>
 <property><name>fs.defaultFS</name><value>hdfs://127.0.0.1:9000</value></property>
 <property><name>hadoop.tmp.dir</name><value>/var/lib/cdc-hdfs/tmp</value></property>
</configuration>
XML
cat > "$HADOOP_CONF_DIR/hdfs-site.xml" <<'XML'
<configuration>
 <property><name>dfs.replication</name><value>1</value></property>
 <property><name>dfs.namenode.name.dir</name><value>file:///var/lib/cdc-hdfs/name</value></property>
 <property><name>dfs.datanode.data.dir</name><value>file:///var/lib/cdc-hdfs/data</value></property>
 <property><name>dfs.namenode.http-address</name><value>127.0.0.1:9870</value></property>
 <property><name>dfs.datanode.address</name><value>127.0.0.1:9866</value></property>
 <property><name>dfs.datanode.ipc.address</name><value>127.0.0.1:9867</value></property>
 <property><name>dfs.datanode.http.address</name><value>127.0.0.1:9864</value></property>
 <property><name>dfs.namenode.safemode.min.datanodes</name><value>1</value></property>
</configuration>
XML
if [[ ! -s /var/lib/cdc-hdfs/name/current/VERSION ]]; then
  timeout 60 runuser -u hdfs -- hdfs namenode -format -force -nonInteractive > /evidence/hdfs-format.log 2>&1
fi
setsid runuser -u hdfs -- hdfs namenode > /evidence/hdfs-namenode.log 2>&1 & processes+=("$!")
setsid runuser -u hdfs -- hdfs datanode > /evidence/hdfs-datanode.log 2>&1 & processes+=("$!")
for _ in $(seq 1 60); do
  if timeout 5 runuser -u hdfs -- hdfs dfsadmin -report > /evidence/hdfs-report.txt 2>&1 && \
     grep -q 'Live datanodes (1)' /evidence/hdfs-report.txt; then break; fi
  sleep 2
done
grep -q 'Live datanodes (1)' /evidence/hdfs-report.txt
timeout 60 runuser -u hdfs -- hdfs dfsadmin -safemode wait
timeout 30 runuser -u hdfs -- hdfs dfs -mkdir -p /warehouse
timeout 30 runuser -u hdfs -- hdfs dfs -chown flink /warehouse
touch /evidence/hdfs-ready
wait -n "${processes[@]}"
exit 1
