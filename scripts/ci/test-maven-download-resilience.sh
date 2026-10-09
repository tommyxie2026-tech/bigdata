#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RETRY_SCRIPT="${REPO_ROOT}/scripts/ci/retry-maven-downloads.sh"
PREFETCH_SCRIPT="${REPO_ROOT}/scripts/ci/prefetch-hadoop-maven-artifacts.sh"
BUILD_SCRIPT="${REPO_ROOT}/scripts/ci/build-bigtop-component.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

test_retry_count_is_configurable() {
  local root
  root="$(mktemp -d)"
  trap 'rm -rf "${root}"' RETURN
  cat > "${root}/flaky" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
count=0
[[ ! -f "${COUNT_FILE}" ]] || count="$(cat "${COUNT_FILE}")"
count=$((count + 1))
printf '%s\n' "${count}" > "${COUNT_FILE}"
if [[ "${count}" -lt 4 ]]; then
  echo '[ERROR] Could not transfer artifact example:artifact:pom:1.0: Connection timed out'
  exit 1
fi
EOF
  chmod +x "${root}/flaky"

  COUNT_FILE="${root}/count" \
    MAVEN_RETRY_ATTEMPTS=4 \
    MAVEN_RETRY_DELAY_SECONDS=0 \
    bash "${RETRY_SCRIPT}" "${root}/retry.log" "${root}/flaky"

  [[ "$(cat "${root}/count")" -eq 4 ]] || fail "retry helper did not honor MAVEN_RETRY_ATTEMPTS"
}

test_hadoop_prefetch_covers_observed_failures() {
  local root
  root="$(mktemp -d)"
  trap 'rm -rf "${root}"' RETURN
  mkdir -p "${root}/bin" "${root}/logs"
  cat > "${root}/bin/mvn" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${MVN_CALLS}"
EOF
  chmod +x "${root}/bin/mvn"

  PATH="${root}/bin:${PATH}" \
    MVN_CALLS="${root}/calls" \
    MAVEN_RETRY_DELAY_SECONDS=0 \
    bash "${PREFETCH_SCRIPT}" "${root}/logs"

  grep -q -- '-Dartifact=com.googlecode.json-simple:json-simple:1.1.1' "${root}/calls" ||
    fail "json-simple prefetch missing"
  grep -q -- '-Dartifact=org.codehaus.mojo:extra-enforcer-rules:1.5.1' "${root}/calls" ||
    fail "extra-enforcer-rules prefetch missing"
  grep -q -- '-Dartifact=com.huaweicloud:esdk-obs-java:3.20.4.2' "${root}/calls" ||
    fail "Huawei OBS SDK prefetch missing"
  [[ "$(wc -l < "${root}/calls" | tr -d ' ')" -eq 3 ]] || fail "unexpected prefetch command count"
}

test_component_build_bounds_and_prefetches_maven() {
  grep -q -- '-Dmaven.wagon.rto=60000' "${BUILD_SCRIPT}" ||
    fail "component build does not bound Maven read timeouts"
  grep -q 'prefetch-hadoop-maven-artifacts.sh' "${BUILD_SCRIPT}" ||
    fail "component build does not prefetch known Hadoop dependencies"
}

test_retry_count_is_configurable
test_hadoop_prefetch_covers_observed_failures
test_component_build_bounds_and_prefetches_maven
echo "Maven download resilience tests: PASS"
