#!/usr/bin/env bash
set -euo pipefail

EVIDENCE_ROOT="${EVIDENCE_ROOT:-/evidence}"
FLINK_HOME="${FLINK_HOME:-/usr/lib/flink}"
INPUT="$(mktemp /tmp/flink-input.XXXXXX)"
OUTPUT="$(mktemp -u /tmp/flink-output.XXXXXX)"
CLUSTER_LOG="${EVIDENCE_ROOT}/flink-cluster.log"

cleanup() {
  runuser -u flink -- "${FLINK_HOME}/bin/stop-cluster.sh" >>"${CLUSTER_LOG}" 2>&1 || true
}
trap cleanup EXIT

printf 'alpha beta alpha\ngamma beta\n' > "${INPUT}"
chown flink:flink "${INPUT}"
runuser -u flink -- "${FLINK_HOME}/bin/start-cluster.sh" >"${CLUSTER_LOG}" 2>&1

ready=false
for _ in $(seq 1 60); do
  if curl --fail --silent http://127.0.0.1:8081/overview >/dev/null; then
    ready=true
    break
  fi
  sleep 2
done
[[ "${ready}" == true ]] || { cat "${CLUSTER_LOG}" >&2; exit 1; }

example="${FLINK_HOME}/examples/streaming/WordCount.jar"
[[ -s "${example}" ]]
runuser -u flink -- "${FLINK_HOME}/bin/flink" run -m localhost:8081 \
  "${example}" --input "${INPUT}" --output "${OUTPUT}" \
  >"${EVIDENCE_ROOT}/flink-job.log" 2>&1
echo 'job_submit: PASS' > "${EVIDENCE_ROOT}/job_submit.txt"

for _ in $(seq 1 30); do
  [[ -s "${OUTPUT}" ]] && break
  sleep 1
done
[[ -s "${OUTPUT}" ]]
grep -Fq '(alpha,2)' "${OUTPUT}"
grep -Fq '(beta,2)' "${OUTPUT}"
grep -Fq '(gamma,1)' "${OUTPUT}"
cp "${OUTPUT}" "${EVIDENCE_ROOT}/flink-job-result.txt"
echo 'job_result: PASS' > "${EVIDENCE_ROOT}/job_result.txt"
