#!/usr/bin/env bash
set -euo pipefail
phase="$1"
if [[ "$phase" == prepare ]]; then
  # Resolve the whole published closure before downloading the JDK.
  dnf -y --setopt=timeout=20 --setopt=retries=2 install \
    /dependencies/common/3.6.0/*.rpm /dependencies/hadoop/3.4.3/*.rpm \
    java-1.8.0-openjdk-devel findutils diffutils procps-ng
  rpm -q hadoop hadoop-client > /evidence/s3a-installed-rpms.txt
  hadoop version > /evidence/s3a-hadoop-version.txt 2>&1
  grep -qx 'Hadoop 3.4.3' /evidence/s3a-hadoop-version.txt
  mkdir -p /opt/s3a
  cp /workspace/scripts/s3a/S3AProbe.java /opt/s3a/
  export HADOOP_OPTIONAL_TOOLS=hadoop-aws
  cp="$(hadoop classpath --glob)"
  aws="$(find /usr/lib/hadoop* -type f -name 'hadoop-aws-3.4.3.jar' -print -quit)"
  [[ -n "$aws" ]] || { echo 'Published RPM lacks matching hadoop-aws'; exit 1; }
  # Bigtop keeps optional SDK dependencies in tools/lib, separately from
  # hadoop-aws copies in lib. Do not infer the SDK directory from that copy.
  tools=/usr/lib/hadoop/tools/lib
  [[ -d "$tools" ]]
  rpm -ql hadoop > /evidence/s3a-rpm-files.txt
  find /usr/lib/hadoop -name '*.jar' -print > /evidence/s3a-jar-inventory.txt
  cp="$cp:$(dirname "$aws")/*:$tools/*"
  javap -classpath "$cp" software.amazon.awssdk.auth.credentials.AwsCredentialsProvider \
    > /evidence/s3a-sdk-preflight.txt
  printf '%s' "$cp" > /opt/s3a/classpath
  sha256sum "$aws" > /evidence/s3a-dependency-sha256.txt
  find "$tools" -maxdepth 1 -type f -name '*.jar' -exec sha256sum {} \; >> /evidence/s3a-dependency-sha256.txt
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
