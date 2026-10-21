#!/usr/bin/env bash
# Small live proof: prepare online, delete outputs, then compile with no network.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
context="$(mktemp -d)"
image="bigdata-dependency-policy:${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}"
trap 'rm -rf "${context}"; docker image rm "${image}" >/dev/null 2>&1 || true' EXIT
cp -R "${repo_root}/scripts/ci/fixtures/maven-offline/." "${context}/"
mkdir -p "${context}/policy"
for script in retry-maven-downloads.sh configure-maven-policy.py run-with-deadline.py; do
  cp "${repo_root}/scripts/ci/${script}" "${context}/policy/"
done
docker build --tag "${image}" "${context}"
docker run --rm --init --network none "${image}"
# A cold repository must fail in offline mode, with no online fallback or retry.
set +e
docker run --rm --init --network none "${image}" bash -c \
  'rm -rf /root/.m2/repository /fixture/target; bash /policy/retry-maven-downloads.sh /cold.log mvn -B package; rc=$?; cat /cold.log; exit "$rc"' \
  > "${context}/cold.log" 2>&1
cold_rc=$?
set -e
cat "${context}/cold.log"
[[ "${cold_rc}" -ne 0 ]]
grep -qi 'offline' "${context}/cold.log"
! grep -q 'attempt=2\|Retrying transient' "${context}/cold.log"
echo 'PASS: cached offline rebuild produced identical bytecode; cold offline build failed without retry.'
