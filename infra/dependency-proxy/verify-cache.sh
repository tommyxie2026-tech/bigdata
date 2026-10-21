#!/usr/bin/env bash
# Only the disposable fixture may have its upstream network deliberately removed.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
: "${PROXY_CA_FILE:?}" "${PROXY_EVIDENCE_ROOT:?}" "${COMPOSE_PROJECT_NAME:?}"
[[ "${PROXY_DISPOSABLE:-}" == 1 && "$COMPOSE_PROJECT_NAME" == *-ci ]]
mkdir -p "$PROXY_EVIDENCE_ROOT"
for path in maven/ci-maven/ npm/ pypi/; do
  for method in POST PUT DELETE; do
    denied=$(curl --silent --show-error --connect-timeout 3 --max-time 10 --cacert "$PROXY_CA_FILE" \
      --request "$method" --output /dev/null --write-out '%{http_code}' "https://localhost:8443/$path")
    [[ "$denied" == 405 ]]
  done
done
python3 probe.py cold --evidence "$PROXY_EVIDENCE_ROOT"
for service in maven npm pypi; do
  container=$(docker compose ps -q "$service")
  docker network disconnect "$COMPOSE_PROJECT_NAME-egress" "$container"
  docker inspect "$container" --format '{{json .NetworkSettings.Networks}}' > "$PROXY_EVIDENCE_ROOT/$service-networks.json"
  python3 - "$PROXY_EVIDENCE_ROOT/$service-networks.json" "$COMPOSE_PROJECT_NAME-internal" <<'PY'
import json,sys
assert set(json.load(open(sys.argv[1])))=={sys.argv[2]},'Proxy retains an external network'
PY
done
# Devpi's explicit offline mode also suppresses metadata revalidation after restart.
docker compose exec -T pypi touch /data/offline
python3 probe.py warm --evidence "$PROXY_EVIDENCE_ROOT"
status=$(curl --silent --show-error --connect-timeout 3 --max-time 30 --cacert "$PROXY_CA_FILE" \
  --output "$PROXY_EVIDENCE_ROOT/uncached-error.txt" --write-out '%{http_code}' \
  https://localhost:8443/maven/ci-maven/junit/junit/4.13.1/junit-4.13.1.jar)
case "$status" in 404|502|503|504) ;; *) echo "Uncached artifact unexpectedly returned $status" >&2; exit 1 ;; esac
# Confirm backend health independently; a dead server is not a successful offline miss.
container=$(docker compose ps -q maven)
[[ "$(docker inspect "$container" --format '{{.State.Health.Status}}')" == healthy ]]
docker compose restart maven npm pypi
for _ in $(seq 1 60); do
  maven=$(docker compose ps -q maven)
  if [[ "$(docker inspect "$maven" --format '{{.State.Health.Status}}')" == healthy ]] && curl --fail --silent --connect-timeout 2 --max-time 5 --cacert "$PROXY_CA_FILE" \
    https://localhost:8443/pypi/+status >/dev/null; then break; fi
  sleep 2
done
python3 probe.py restarted --evidence "$PROXY_EVIDENCE_ROOT"
printf 'profile: reposilite-verdaccio-devpi\ncold_bytes: PASS\nnetwork_isolated_warm_bytes: PASS\nrestart_bytes: PASS\nuncached_http_status: %s\nstatus: PASS\n' "$status" > "$PROXY_EVIDENCE_ROOT/evidence.md"
