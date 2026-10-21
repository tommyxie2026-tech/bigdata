#!/usr/bin/env bash
# Sourced after Hadoop/Paimon installation, before compiling or starting Flink.
set -euo pipefail
: "${CDC_WAREHOUSE:?}"
(cd /sdk && sha256sum -c evidence/SHA256SUMS)
rpms=(/sdk/rpms/*.rpm)
[[ "${#rpms[@]}" -eq 1 ]]
[[ "$(rpm -qp --queryformat '%{NAME} %{VERSION}' "${rpms[0]}")" == 'bigdata-hadoop-aws-sdk 2.35.4' ]]
dnf -y --setopt=timeout=20 --setopt=retries=2 install "${rpms[0]}"
rpm -q bigdata-hadoop-aws-sdk > /evidence/s3-sdk-package.txt
install -d -m 755 /var/lib/flink/cdc-s3-conf
python3 /workspace/scripts/cdc-lakehouse/s3_config.py "$CDC_WAREHOUSE" /var/lib/flink/cdc-s3-conf/core-site.xml
# Preserve the JDK public roots: Maven still uses HTTPS after this setup.
keytool -importkeystore -noprompt -srckeystore "$JAVA_HOME/lib/security/cacerts" \
  -srcstorepass changeit -destkeystore /var/lib/flink/cdc-s3-conf/trust.jks \
  -deststorepass fixture-trust -deststoretype JKS
keytool -importcert -noprompt -alias fixture -file /fixture/server.crt \
  -keystore /var/lib/flink/cdc-s3-conf/trust.jks -storepass fixture-trust
# shellcheck source=scripts/cdc-lakehouse/s3-runtime.sh
source /workspace/scripts/cdc-lakehouse/s3-runtime.sh
javap -classpath "$HADOOP_CLASSPATH" software.amazon.awssdk.auth.credentials.AwsCredentialsProvider \
  > /evidence/s3-sdk-preflight.txt
