#!/usr/bin/env bash
set -Eeuo pipefail
: "${CONNECTOR:?}" "${CDC_WAREHOUSE:?}"
[[ "$CDC_WAREHOUSE" == s3a://bigdata-ci-fixture/warehouse/* ]]
export CDC_TARGET=paimon CDC_WAREHOUSE
# The S3 server data directory is never mounted into this client.
test ! -e /data
bash "/workspace/scripts/flink-cdc-$CONNECTOR/test.sh"
grep -qx 'target: paimon' /evidence/evidence.md
for phase in snapshot changes restored-rows; do
  grep -q '^paimon: PASS exact_rows=' "/evidence/$phase.txt"
done
printf 'warehouse: %s\nremote_s3_https: PASS\n' "$CDC_WAREHOUSE" >> /evidence/evidence.md
