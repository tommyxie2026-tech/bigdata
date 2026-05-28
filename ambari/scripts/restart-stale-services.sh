#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/ambari-env.sh"

echo "Restart services/components that require restart in cluster ${AMBARI_CLUSTER}"

ambari_curl -X PUT "${AMBARI_BASE_URL}/clusters/${AMBARI_CLUSTER}/host_components" \
  -d '{
    "RequestInfo": {
      "context": "Restart all stale services after configuration changes",
      "operation_level": {
        "level": "CLUSTER"
      }
    },
    "Body": {
      "HostRoles": {
        "state": "INSTALLED"
      }
    },
    "QueryInfo": {
      "query": "HostRoles/stale_configs=true&HostRoles/maintenance_state=OFF"
    }
  }'

ambari_curl -X PUT "${AMBARI_BASE_URL}/clusters/${AMBARI_CLUSTER}/host_components" \
  -d '{
    "RequestInfo": {
      "context": "Start restarted stale services",
      "operation_level": {
        "level": "CLUSTER"
      }
    },
    "Body": {
      "HostRoles": {
        "state": "STARTED"
      }
    },
    "QueryInfo": {
      "query": "HostRoles/stale_configs=true&HostRoles/maintenance_state=OFF"
    }
  }'

echo "Restart requests submitted."
