#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/ambari-env.sh"

BLUEPRINT_FILE="${1:-${SCRIPT_DIR}/../blueprints/single-node-hadoop.json}"
HOST_MAPPING_FILE="${2:-}"
BLUEPRINT_NAME="${BLUEPRINT_NAME:-single-node-hadoop}"

if [[ ! -f "${BLUEPRINT_FILE}" ]]; then
  echo "Blueprint file not found: ${BLUEPRINT_FILE}" >&2
  exit 1
fi

echo "Register blueprint: ${BLUEPRINT_NAME}"
ambari_curl -X POST "${AMBARI_BASE_URL}/blueprints/${BLUEPRINT_NAME}" \
  --data-binary "@${BLUEPRINT_FILE}"

if [[ -z "${HOST_MAPPING_FILE}" ]]; then
  cat <<EOF
Blueprint registered.

To create a cluster, provide a host mapping file:
  ./create-cluster.sh ${BLUEPRINT_FILE} host-mapping.json
EOF
  exit 0
fi

if [[ ! -f "${HOST_MAPPING_FILE}" ]]; then
  echo "Host mapping file not found: ${HOST_MAPPING_FILE}" >&2
  exit 1
fi

echo "Create cluster: ${AMBARI_CLUSTER}"
ambari_curl -X POST "${AMBARI_BASE_URL}/clusters/${AMBARI_CLUSTER}" \
  --data-binary "@${HOST_MAPPING_FILE}"

echo "Cluster creation request submitted."
