#!/usr/bin/env bash
# Warm the Maven cache for dependencies that repeatedly timed out late in the
# Hadoop 3.4.3 build. Fetching them up front keeps retries short and avoids
# repeating a nearly complete Hadoop build for each transient transfer failure.
set -euo pipefail

log_dir="${1:?log directory required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
retry_script="${script_dir}/retry-maven-downloads.sh"
mkdir -p "${log_dir}"

artifacts=(
  com.googlecode.json-simple:json-simple:1.1.1
  org.codehaus.mojo:extra-enforcer-rules:1.5.1
  com.huaweicloud:esdk-obs-java:3.20.4.2
  org.junit.jupiter:junit-jupiter-engine:5.8.2
  org.apache.maven:maven-core:3.6.3
  org.powermock:powermock-api-mockito:1.7.4
)

for artifact in "${artifacts[@]}"; do
  log_name="${artifact//[:.]/-}"
  MAVEN_RETRY_ATTEMPTS="${MAVEN_PREFETCH_RETRY_ATTEMPTS:-8}" \
    bash "${retry_script}" "${log_dir}/prefetch-${log_name}.log" \
    mvn -B org.apache.maven.plugins:maven-dependency-plugin:3.8.1:get \
      -Dartifact="${artifact}" \
      -Dtransitive=true
done
