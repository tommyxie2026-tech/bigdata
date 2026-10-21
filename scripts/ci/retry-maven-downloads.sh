#!/usr/bin/env bash
# Retry transient dependency transfers in the same workspace, within one budget.
set -euo pipefail

log_file="${1:?log file required}"
shift
[[ "$#" -gt 0 ]]
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
attempts="${MAVEN_RETRY_ATTEMPTS:-3}"
attempt_seconds="${MAVEN_RETRY_ATTEMPT_SECONDS:-7200}"
total_seconds="${MAVEN_RETRY_TOTAL_SECONDS:-10800}"
delay_seconds="${MAVEN_RETRY_DELAY_SECONDS:-15}"
for value in "${attempts}" "${attempt_seconds}" "${total_seconds}"; do
  [[ "${value}" =~ ^[1-9][0-9]*$ ]] || { echo 'Retry counts and deadlines must be positive integers.' >&2; exit 2; }
done
[[ "${delay_seconds}" =~ ^[0-9]+$ ]] || exit 2
python3 "${script_dir}/configure-maven-policy.py" \
  --settings-file "${CI_MAVEN_SETTINGS_FILE:-${HOME}/.m2/settings.xml}"
export MAVEN_OPTS="${MAVEN_OPTS:-} -Dmaven.wagon.rto=60000 -Dmaven.wagon.http.retryHandler.count=3 -Dmaven.wagon.httpconnectionManager.ttlSeconds=60 -Daether.connector.connectTimeout=15000 -Daether.connector.requestTimeout=60000"
if [[ "${MAVEN_NETWORK_MODE:-online}" == offline ]]; then
  case "$(basename "$1")" in
    gradlew|gradle) set -- "$1" --offline "${@:2}" ;;
  esac
fi
mkdir -p "$(dirname "${log_file}")"
: > "${log_file}"
deadline=$((SECONDS + total_seconds))
for ((attempt = 1; attempt <= attempts; attempt++)); do
  remaining=$((deadline - SECONDS))
  if [[ "${remaining}" -le 0 ]]; then echo 'Dependency retry total timeout reached.' | tee -a "${log_file}"; exit 124; fi
  limit="${attempt_seconds}"
  if [[ "${remaining}" -lt "${limit}" ]]; then limit="${remaining}"; fi
  attempt_log="${log_file%.log}-attempt-${attempt}.log"
  echo "dependency attempt=${attempt}/${attempts}, timeout=${limit}s, mode=${MAVEN_NETWORK_MODE:-online}" | tee -a "${log_file}"
  set +e
  python3 "${script_dir}/run-with-deadline.py" "${limit}" "$@" 2>&1 | tee "${attempt_log}"
  rc=${PIPESTATUS[0]}
  set -e
  cat "${attempt_log}" >> "${log_file}"
  if [[ "${rc}" -eq 0 ]]; then exit 0; fi
  # Offline misses, compiler errors and deadlines must never restart compilation.
  if [[ "${rc}" -eq 124 || "${MAVEN_NETWORK_MODE:-online}" == offline || "${attempt}" -eq "${attempts}" ]] || ! grep -Eq \
    '\[ERROR\].*(Could not transfer artifact|Could not transfer metadata).*(timed out|Connection reset|502|503|504|429)' \
    "${attempt_log}"; then
    exit "${rc}"
  fi
  remaining=$((deadline - SECONDS))
  if [[ "${remaining}" -le "${delay_seconds}" ]]; then
    echo 'Dependency retry total timeout leaves no time for another attempt.' | tee -a "${log_file}"
    exit 124
  fi
  echo "Retrying transient Maven download failure (${attempt}/${attempts})" | tee -a "${log_file}"
  # Keep downloaded JARs and reactor outputs; clear only failed-transfer markers.
  if [[ -d "${HOME}/.m2/repository" ]]; then
    find "${HOME}/.m2/repository" -type f -name '*.lastUpdated' -delete
  fi
  sleep "${delay_seconds}"
done
