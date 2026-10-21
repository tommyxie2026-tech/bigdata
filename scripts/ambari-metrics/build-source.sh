#!/usr/bin/env bash
# Compile the pinned Collector once; package/runtime adapters consume this artifact later.
set -Eeuo pipefail
: "${BUILD_RUN_ID:?}"
mkdir -p /work/output/evidence /work/output/collector /work/output/monitor
report_failure() {
  local code=$?
  echo "Metrics source build failed at line ${BASH_LINENO[0]}: ${BASH_COMMAND}" >&2
  return "$code"
}
trap report_failure ERR
expected=ce919386e963841ea37f032c5ba6ed9c48298dd8
timeout 600 dnf -y --setopt=timeout=30 --setopt=retries=2 install java-1.8.0-openjdk-devel maven python3 findutils git
[[ "$(git -c safe.directory=/source -C /source rev-parse HEAD)" == "$expected" ]]
javac_path="$(rpm -ql java-1.8.0-openjdk-devel | awk '/[/]bin[/]javac$/ && !found {print;found=1}')"
[[ -n "$javac_path" && -x "$javac_path" ]]
JAVA_HOME="$(dirname "$(dirname "$javac_path")")"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
java -version 2>&1 | tee /work/output/evidence/java-version.txt
java -version 2>&1 | grep -q 'version "1.8.'
cp -a /source /work/source
cd /work/source
# Deactivate only upstream binary-tar downloads. Do not download unrelated Grafana/Hadoop
# distributions or rebuild them merely to check the Collector Java source.
export MAVEN_RETRY_ATTEMPTS=2 MAVEN_RETRY_ATTEMPT_SECONDS=1200 MAVEN_RETRY_TOTAL_SECONDS=1500
bash /workspace/scripts/ci/retry-maven-downloads.sh /work/output/evidence/compile.log \
  mvn -B -ntp -P!linux -pl ambari-metrics-timelineservice -am \
    -DskipTests -DskipSurefireTests -Drat.skip=true package
collector=ambari-metrics-timelineservice/target/ambari-metrics-timelineservice-3.0.0.jar
[[ -s "$collector" ]]
jar tf "$collector" > /work/output/evidence/collector-entries.txt
grep -qx 'org/apache/ambari/metrics/AMSApplicationServer.class' /work/output/evidence/collector-entries.txt
cp "$collector" /work/output/collector/
cp -a ambari-metrics-timelineservice/target/lib /work/output/collector/
cp -a ambari-metrics-timelineservice/conf/unix /work/output/collector/conf
cp -a ambari-metrics-host-monitoring/src/main/python /work/output/monitor/
cp -a ambari-metrics-host-monitoring/conf/unix /work/output/monitor/conf
cp LICENSE NOTICE /work/output/
(cd /work/output && find collector monitor -type f -print0 | sort -z | xargs -0 sha256sum > evidence/SHA256SUMS)
cat > /work/output/evidence/evidence.md <<EOF
stage: compile
component: ambari-metrics
version: 3.0.0
source_identity: $expected
build_run_id: $BUILD_RUN_ID
jdk: 8
collector_entrypoint: PASS
monitor_source: PRESERVED_UNPORTED
rpm_build: NOT_RUN
installation_and_collection: NOT_RUN
status: PASS
EOF
