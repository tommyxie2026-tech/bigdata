#!/usr/bin/env bash
# Retry only Maven dependency transfer failures, preserving the build/cache.
set -euo pipefail

log_file="${1:?log file required}"
shift
for attempt in 1 2 3; do
  attempt_log="${log_file%.log}-attempt-${attempt}.log"
  set +e
  "$@" 2>&1 | tee "${attempt_log}"
  rc=${PIPESTATUS[0]}
  set -e
  cat "${attempt_log}" >> "${log_file}"
  if [[ "${rc}" -eq 0 ]]; then exit 0; fi
  if [[ "${attempt}" -eq 3 ]] || ! grep -Eq \
    '\[ERROR\].*(Could not transfer artifact|Could not transfer metadata).*(timed out|Connection reset|502|503|504)' \
    "${attempt_log}"; then
    exit "${rc}"
  fi
  echo "Retrying transient Maven download failure (${attempt}/3)"
  # Maven caches failed transfers; allow the next invocation to request them again.
  if [[ -d "${HOME}/.m2/repository" ]]; then
    find "${HOME}/.m2/repository" -type f -name '*.lastUpdated' -delete
  fi
  sleep "${MAVEN_RETRY_DELAY_SECONDS:-15}"
done
