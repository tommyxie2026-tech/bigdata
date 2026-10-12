#!/usr/bin/env bash
set -euo pipefail

EVIDENCE_ROOT="${EVIDENCE_ROOT:-/evidence}"
FLINK_HOME="${FLINK_HOME:-/usr/lib/flink}"
INPUT="$(mktemp /tmp/flink-input.XXXXXX)"
OUTPUT="$(mktemp -u /tmp/flink-output.XXXXXX)"
CLUSTER_LOG="${EVIDENCE_ROOT}/flink-cluster.log"
JOB_LOG="${EVIDENCE_ROOT}/flink-job.log"
SMOKE_STAGE=setup

diagnose_failure() {
  status=$?
  echo "Flink smoke failed during stage: ${SMOKE_STAGE} (exit ${status})" >&2
  for log_file in "${CLUSTER_LOG}" "${JOB_LOG}"; do
    if [[ -s "${log_file}" ]]; then
      echo "--- ${log_file} (last 100 lines) ---" >&2
      tail -n 100 "${log_file}" >&2 || true
    fi
  done
  if [[ -d "${OUTPUT}" ]]; then
    echo "--- Flink output files ---" >&2
    find "${OUTPUT}" -maxdepth 2 -printf '%y %p (%s bytes)\n' >&2 || true
    while IFS= read -r output_file; do
      [[ -f "${output_file}" ]] || continue
      echo "--- ${output_file} ---" >&2
      head -c 4096 "${output_file}" >&2 || true
      echo >&2
    done < <(find "${OUTPUT}" -maxdepth 2 -type f -name 'part-*' -print 2>/dev/null)
  else
    echo "Flink output path was not created: ${OUTPUT}" >&2
  fi
  return "${status}"
}

cleanup() {
  runuser -u flink -- env FLINK_LOG_DIR=/var/log/flink "${FLINK_HOME}/bin/stop-cluster.sh" >>"${CLUSTER_LOG}" 2>&1 || true
}
trap cleanup EXIT
trap diagnose_failure ERR

printf 'alpha beta alpha\ngamma beta\n' > "${INPUT}"
chown flink:flink "${INPUT}"
# The RPM installs its writable service log directory at /var/log/flink.
FLINK_LOG_DIR=/var/log/flink
[[ -d "${FLINK_LOG_DIR}" ]]
runuser -u flink -- test -w "${FLINK_LOG_DIR}"
SMOKE_STAGE=start-cluster
runuser -u flink -- env FLINK_LOG_DIR="${FLINK_LOG_DIR}" "${FLINK_HOME}/bin/start-cluster.sh" >"${CLUSTER_LOG}" 2>&1

SMOKE_STAGE=jobmanager-health
ready=false
for _ in $(seq 1 60); do
  if curl --fail --silent http://127.0.0.1:8081/overview >/dev/null; then
    ready=true
    break
  fi
  sleep 2
done
[[ "${ready}" == true ]] || { cat "${CLUSTER_LOG}" >&2; exit 1; }

SMOKE_STAGE=wordcount-submit
example="${FLINK_HOME}/examples/streaming/WordCount.jar"
[[ -s "${example}" ]]
runuser -u flink -- "${FLINK_HOME}/bin/flink" run -m localhost:8081 \
  "${example}" --input "${INPUT}" --output "${OUTPUT}" \
  >"${JOB_LOG}" 2>&1
echo 'job_submit: PASS' > "${EVIDENCE_ROOT}/job_submit.txt"

SMOKE_STAGE=wordcount-output
result_file=""
for _ in $(seq 1 30); do
  result_file="$(find "${OUTPUT}" -type f -name 'part-*' -print -quit 2>/dev/null || true)"
  [[ -n "${result_file}" && -s "${result_file}" ]] && break
  sleep 1
done
[[ -n "${result_file}" && -s "${result_file}" ]] || {
  echo "No non-empty Flink part file appeared under ${OUTPUT}." >&2
  echo "--- Flink job submission/result log ---" >&2
  tail -n 100 "${JOB_LOG}" >&2 || true
  echo "--- Flink output directory listing ---" >&2
  if [[ -d "${OUTPUT}" ]]; then
    find "${OUTPUT}" -maxdepth 2 -printf '%y %p (%s bytes)\n' >&2 || true
    while IFS= read -r output_file; do
      [[ -f "${output_file}" ]] || continue
      echo "--- ${output_file} ---" >&2
      head -c 4096 "${output_file}" >&2 || true
      echo >&2
    done < <(find "${OUTPUT}" -maxdepth 2 -type f -print 2>/dev/null)
  else
    echo "Output directory was not created." >&2
  fi
  exit 1
}
for expected in '(alpha,2)' '(beta,2)' '(gamma,1)'; do
  grep -Fq "${expected}" "${result_file}" || {
    echo "Expected WordCount result ${expected} missing from ${result_file}." >&2
    exit 1
  }
done
cp "${result_file}" "${EVIDENCE_ROOT}/flink-job-result.txt"
echo 'job_result: PASS' > "${EVIDENCE_ROOT}/job_result.txt"
