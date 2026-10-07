#!/usr/bin/env bash
set -euo pipefail

REPO_CHECKOUT="${REPO_CHECKOUT:?REPO_CHECKOUT is required}"
base="${REPO_CHECKOUT}/repo/openeuler-22.03-lts-sp4/bigtop-3.6"
for component_version in common/3.6.0 zookeeper/3.8.4 hadoop/3.4.3 tez/0.10.5 hive/4.0.1; do
  test -s "${base}/${component_version}/repodata/repomd.xml"
  test -s "${base}/${component_version}/SHA256SUMS"
  (cd "${base}/${component_version}" && sha256sum -c SHA256SUMS)
done

docker pull openeuler/openeuler:22.03-lts-sp4
docker run --rm -v "${base}:/repo:ro" openeuler/openeuler:22.03-lts-sp4 bash -euo pipefail -c '
  cat > /etc/yum.repos.d/bigdata-slim.repo <<EOF
[bigdata-common]
name=BIGDATA common runtime packages
baseurl=file:///repo/common/3.6.0
enabled=1
gpgcheck=0
[bigdata-zookeeper]
name=BIGDATA ZooKeeper
baseurl=file:///repo/zookeeper/3.8.4
enabled=1
gpgcheck=0
[bigdata-hadoop]
name=BIGDATA Hadoop
baseurl=file:///repo/hadoop/3.4.3
enabled=1
gpgcheck=0
[bigdata-tez]
name=BIGDATA Tez
baseurl=file:///repo/tez/0.10.5
enabled=1
gpgcheck=0
[bigdata-hive]
name=BIGDATA Hive
baseurl=file:///repo/hive/4.0.1
enabled=1
gpgcheck=0
EOF
  dnf -y install java-1.8.0-openjdk-devel zookeeper-server hadoop-client hadoop-conf-pseudo tez hive
  export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
  export PATH="${JAVA_HOME}/bin:${PATH}"
  rpm -q zookeeper-server hadoop-client hadoop-conf-pseudo tez hive
  hadoop version
  hive --version
'
