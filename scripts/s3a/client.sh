#!/usr/bin/env bash
set -euo pipefail
phase="$1"
if [[ "$phase" == prepare ]]; then
  dnf -y install java-1.8.0-openjdk-devel findutils diffutils procps-ng
  # The published, checksum-verified RPM closure is mounted read-only.
  dnf -y install /dependencies/common/3.6.0/bigtop-utils-3.6.0-1.noarch.rpm \
    /dependencies/hadoop/3.4.3/hadoop-3.4.3-1.x86_64.rpm \
    /dependencies/hadoop/3.4.3/hadoop-client-3.4.3-1.x86_64.rpm
  rpm -q hadoop hadoop-client > /evidence/s3a-installed-rpms.txt
  hadoop version > /evidence/s3a-hadoop-version.txt 2>&1
  grep -qx 'Hadoop 3.4.3' /evidence/s3a-hadoop-version.txt
  mkdir -p /opt/s3a
  cp /workspace/scripts/s3a/S3AProbe.java /opt/s3a/
  export HADOOP_OPTIONAL_TOOLS=hadoop-aws
  cp="$(hadoop classpath --glob)"
  aws="$(find /usr/lib/hadoop* -type f -name 'hadoop-aws-3.4.3.jar' -print -quit)"
  [[ -n "$aws" ]] || { echo 'Published RPM lacks matching hadoop-aws'; exit 1; }
  tools="$(dirname "$aws")"
  cp="$cp:$tools/*"
  printf '%s' "$cp" > /opt/s3a/classpath
  find "$tools" -maxdepth 1 -type f \( -name '*aws*jar' -o -name 'bundle-*jar' \) -exec sha256sum {} \; > /evidence/s3a-dependency-sha256.txt
  javac -cp "$cp" /opt/s3a/S3AProbe.java
  keytool -importcert -noprompt -alias fixture -file /fixture/server.crt \
    -keystore /opt/s3a/trust.jks -storepass fixture-trust
  exit 0
fi
[[ "$phase" == initial || "$phase" == restored ]]
cp="/opt/s3a:$(cat /opt/s3a/classpath)"
if [[ "$phase" == initial ]]; then
  set +e
  timeout 90 java -cp "$cp" S3AProbe initial > /evidence/s3a-untrusted-tls.log 2>&1
  rc=$?
  set -e
  [[ "$rc" != 0 && "$rc" != 124 ]]
  grep -Eq 'PKIX path building failed|unable to find valid certification path' /evidence/s3a-untrusted-tls.log
fi
timeout 240 java -Djavax.net.ssl.trustStore=/opt/s3a/trust.jks \
  -Djavax.net.ssl.trustStorePassword=fixture-trust \
  -cp "$cp" S3AProbe "$phase" 2>&1 | tee "/evidence/s3a-$phase.log"
