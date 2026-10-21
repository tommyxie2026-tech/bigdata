#!/usr/bin/env bash
# Sourced by both connector test drivers before compilation.
# Small test harnesses must not inherit multi-hour component build budgets.
export MAVEN_RETRY_ATTEMPTS="${MAVEN_RETRY_ATTEMPTS:-2}"
export MAVEN_RETRY_ATTEMPT_SECONDS="${MAVEN_RETRY_ATTEMPT_SECONDS:-300}"
export MAVEN_RETRY_TOTAL_SECONDS="${MAVEN_RETRY_TOTAL_SECONDS:-600}"
case "${CDC_TARGET:-jdbc}" in
  jdbc) ;;
  paimon)
    paimon_repo=/dependencies/paimon/2.1.0
    grep -qx 'source_identity: 3a5ffe7870697e2c2605e63413fb5ac5800aae7e' "$paimon_repo/manifest.yaml"
    grep -qx 'compatibility_identity: 3dc8c21dd72a53c3d342028823d90a87f728151d6e9d152ea5d7aaac082410c5' "$paimon_repo/manifest.yaml"
    grep -qx 'test_status: PASS' "$paimon_repo/manifest.yaml"
    (cd "$paimon_repo" && sha256sum -c SHA256SUMS)
    printf '[cdc-paimon]\nname=Published Paimon\nbaseurl=file://%s\nenabled=1\ngpgcheck=0\n' "$paimon_repo" > /etc/yum.repos.d/cdc-paimon.repo
    dnf -y --disablerepo='*' --enablerepo=OS,everything,cdc-flink,cdc-hadoop,cdc-common,cdc-paimon install bigdata-paimon-flink hadoop-client
    test -s /usr/lib/flink/lib/paimon-flink-1.20-2.1.0.jar
    rpm -q bigdata-paimon-flink > /evidence/paimon-package.txt
    export HADOOP_CLASSPATH
    HADOOP_CLASSPATH="$(hadoop classpath)"
    test -n "$HADOOP_CLASSPATH"
    install -d -o flink -g flink /var/lib/flink/cdc-paimon
    ;;
  hudi)
    hudi_repo=/dependencies/hudi/1.2.1
    grep -qx 'source_identity: a9185b7c4e83422132c25f2efdf282c5bc6af2c7' "$hudi_repo/manifest.yaml"
    grep -qx 'compatibility_identity: d03b23fa91a87ade2945d677446583554f2376827ed589c71ae05136004b6f03' "$hudi_repo/manifest.yaml"
    grep -qx 'test_status: PASS' "$hudi_repo/manifest.yaml"
    (cd "$hudi_repo" && sha256sum -c SHA256SUMS)
    printf '[cdc-hudi]\nname=Published Hudi\nbaseurl=file://%s\nenabled=1\ngpgcheck=0\n' "$hudi_repo" > /etc/yum.repos.d/cdc-hudi.repo
    dnf -y --disablerepo='*' --enablerepo=OS,everything,cdc-flink,cdc-hadoop,cdc-common,cdc-hudi install bigdata-hudi-flink hadoop-client
    test -s /usr/lib/flink/lib/hudi-flink1.20-bundle-1.2.1.jar
    rpm -q bigdata-hudi-flink > /evidence/hudi-package.txt
    export HADOOP_CLASSPATH
    HADOOP_CLASSPATH="$(hadoop classpath)"
    test -n "$HADOOP_CLASSPATH"
    ;;
  iceberg)
    iceberg_repo=/dependencies/iceberg/1.12.0
    grep -qx 'source_identity: 212aa894e919ff9fdf89160da4aadcbe6858ac01' "$iceberg_repo/manifest.yaml"
    grep -qx 'compatibility_identity: 1afa381f72a739ec42aacc9d0edc6b7e19da6f561dded92ea7b6b7b889077045' "$iceberg_repo/manifest.yaml"
    grep -qx 'test_status: PASS' "$iceberg_repo/manifest.yaml"
    (cd "$iceberg_repo" && sha256sum -c SHA256SUMS)
    printf '[cdc-iceberg]\nname=Published Iceberg\nbaseurl=file://%s\nenabled=1\ngpgcheck=0\n' "$iceberg_repo" > /etc/yum.repos.d/cdc-iceberg.repo
    dnf -y --disablerepo='*' --enablerepo=OS,everything,cdc-flink,cdc-hadoop,cdc-common,cdc-iceberg install bigdata-iceberg-flink hadoop-client
    test -s /usr/lib/flink/lib/iceberg-flink-runtime-1.20-1.12.0.jar
    rpm -q bigdata-iceberg-flink > /evidence/iceberg-package.txt
    export HADOOP_CLASSPATH
    HADOOP_CLASSPATH="$(hadoop classpath)"
    test -n "$HADOOP_CLASSPATH"
    ;;
  *) echo "Unsupported CDC_TARGET: $CDC_TARGET" >&2; exit 1 ;;
esac
cp /workspace/scripts/cdc-lakehouse/PaimonTarget.java /tmp/cdc-harness/src/main/java/bigdata/ci/
cp /workspace/scripts/cdc-lakehouse/WarehouseLocation.java /tmp/cdc-harness/src/main/java/bigdata/ci/

for helper in LakehouseTarget HudiTarget IcebergTarget; do
  cp "/workspace/scripts/cdc-lakehouse/$helper.java" /tmp/cdc-harness/src/main/java/bigdata/ci/
done
