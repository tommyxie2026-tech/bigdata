#!/usr/bin/env bash
# Run only against this disposable CI instance: deliberately blocks all configured remotes.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
: "${PROXY_CERT_DIR:?}"
: "${PROXY_PASSWORD_FILE:?}"
: "${PROXY_CA_FILE:?}"
: "${PROXY_EVIDENCE_ROOT:?}"
mkdir -p "$PROXY_EVIDENCE_ROOT"
base=https://localhost:8443
artifact=junit/junit/4.13.2/junit-4.13.2.jar
fetch() { curl --fail-with-body --silent --show-error --connect-timeout 3 --max-time 60 --cacert "$PROXY_CA_FILE" "$@"; }
echo "Fetching HTTPS upstream reference"
curl --fail --silent --show-error --connect-timeout 3 --max-time 60 --dump-header "$PROXY_EVIDENCE_ROOT/upstream-headers.txt" "https://repo.maven.apache.org/maven2/$artifact" -o "$PROXY_EVIDENCE_ROOT/upstream.jar"
echo "Fetching cold proxy artifact through TLS"
if ! fetch --dump-header "$PROXY_EVIDENCE_ROOT/cold-headers.txt" "$base/repository/ci-maven/$artifact" -o "$PROXY_EVIDENCE_ROOT/cold.jar"; then
  head -c 4096 "$PROXY_EVIDENCE_ROOT/cold.jar" > "$PROXY_EVIDENCE_ROOT/cold-error.txt"
  cat "$PROXY_EVIDENCE_ROOT/cold-error.txt" >&2
  exit 1
fi
cmp "$PROXY_EVIDENCE_ROOT/upstream.jar" "$PROXY_EVIDENCE_ROOT/cold.jar"
python3 configure.py --password-file "$PROXY_PASSWORD_FILE" --block-outbound --allow-anonymous
fetch "$base/repository/ci-maven/$artifact" -o "$PROXY_EVIDENCE_ROOT/warm-blocked.jar"
cmp "$PROXY_EVIDENCE_ROOT/cold.jar" "$PROXY_EVIDENCE_ROOT/warm-blocked.jar"
# This version has never been requested through this freshly created proxy.
uncached_status="$(curl --silent --show-error --connect-timeout 3 --max-time 30 --cacert "$PROXY_CA_FILE" \
  --output "$PROXY_EVIDENCE_ROOT/uncached.jar" --write-out '%{http_code}' \
  "$base/repository/ci-maven/junit/junit/4.13.1/junit-4.13.1.jar")"
case "$uncached_status" in
  404|502|503) ;;
  *) echo "Uncached blocked fetch returned unexpected HTTP $uncached_status" >&2; exit 1 ;;
esac
fetch "$base/service/rest/v1/status" >/dev/null
docker compose restart nexus
python3 configure.py --password-file "$PROXY_PASSWORD_FILE" --wait-only
fetch "$base/repository/ci-maven/$artifact" -o "$PROXY_EVIDENCE_ROOT/restarted-blocked.jar"
cmp "$PROXY_EVIDENCE_ROOT/cold.jar" "$PROXY_EVIDENCE_ROOT/restarted-blocked.jar"
(cd "$PROXY_EVIDENCE_ROOT" && sha256sum upstream.jar cold.jar warm-blocked.jar restarted-blocked.jar > SHA256SUMS)
cat > "$PROXY_EVIDENCE_ROOT/evidence.md" <<EOF
profile: nexus-maven-server-cache
cold_proxy_matches_upstream: PASS
cached_fetch_with_outbound_blocked: PASS
uncached_fetch_with_outbound_blocked: FAIL_EXPECTED
uncached_http_status: $uncached_status
restart_preserves_cached_bytes: PASS
status: PASS
EOF
