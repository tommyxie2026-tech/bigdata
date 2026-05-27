#!/usr/bin/env bash

# Ambari REST API environment variables.
# Copy this file to ambari-env.local.sh and override values for your environment.

export AMBARI_HOST="${AMBARI_HOST:-localhost}"
export AMBARI_PORT="${AMBARI_PORT:-8080}"
export AMBARI_USER="${AMBARI_USER:-admin}"
export AMBARI_PASSWORD="${AMBARI_PASSWORD:-admin}"
export AMBARI_CLUSTER="${AMBARI_CLUSTER:-bigdata-cluster}"

export AMBARI_BASE_URL="http://${AMBARI_HOST}:${AMBARI_PORT}/api/v1"

ambari_curl() {
  curl -sS -u "${AMBARI_USER}:${AMBARI_PASSWORD}" \
    -H "X-Requested-By: ambari" \
    -H "Content-Type: application/json" \
    "$@"
}
