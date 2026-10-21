#!/usr/bin/env bash
set -Eeuo pipefail
: "${CONNECTOR:?}" "${CDC_WAREHOUSE:?}"
[[ "$CDC_WAREHOUSE" == hdfs://127.0.0.1:9000/warehouse/* ]]
export CDC_TARGET=hudi CDC_WAREHOUSE
# Hadoop's warehouse is in the storage container, never mounted into this client.
test ! -e /var/lib/cdc-hdfs
bash "/workspace/scripts/flink-cdc-$CONNECTOR/test.sh"
grep -qx 'target: hudi' /evidence/evidence.md
for phase in snapshot changes restored-rows; do
  grep -q '^hudi: PASS exact_rows=' "/evidence/$phase.txt"
done
printf 'warehouse: %s\nremote_hdfs: PASS\n' "$CDC_WAREHOUSE" >> /evidence/evidence.md
