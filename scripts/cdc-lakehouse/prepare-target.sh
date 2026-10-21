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
  *) echo "Unsupported CDC_TARGET: $CDC_TARGET" >&2; exit 1 ;;
esac
cp /workspace/scripts/cdc-lakehouse/PaimonTarget.java /tmp/cdc-harness/src/main/java/bigdata/ci/
