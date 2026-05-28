#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/ambari-env.sh"

SERVICE_NAME="${1:-HDFS}"

echo "Run service check for ${SERVICE_NAME} in cluster ${AMBARI_CLUSTER}"

ambari_curl -X POST "${AMBARI_BASE_URL}/clusters/${AMBARI_CLUSTER}/requests" \
  -d "{
    \"RequestInfo\": {
      \"context\": \"Run service check for ${SERVICE_NAME}\",
      \"command\": \"${SERVICE_NAME}_SERVICE_CHECK\"
    },
    \"Requests/resource_filters\": [
      {
        \"service_name\": \"${SERVICE_NAME}\"
      }
    ]
  }"

echo "Service check request submitted."
