#!/usr/bin/env bash
set -euo pipefail

# Bigtop package build wrapper.
# Set BIGTOP_GRADLE_TASK_TEMPLATE to the real Gradle task pattern before use.

BIGTOP_HOME="${BIGTOP_HOME:-/opt/bigtop}"
COMPONENTS="${COMPONENTS:-hadoop hive spark}"
OS_TARGET="${OS_TARGET:-openeuler22}"
PACKAGE_FORMAT="${PACKAGE_FORMAT:-rpm}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/output}"
BIGTOP_GRADLE_TASK_TEMPLATE="${BIGTOP_GRADLE_TASK_TEMPLATE:-}"

mkdir -p "${OUTPUT_DIR}"

cat <<EOF
Bigtop build plan
-----------------
BIGTOP_HOME: ${BIGTOP_HOME}
COMPONENTS : ${COMPONENTS}
OS_TARGET  : ${OS_TARGET}
FORMAT     : ${PACKAGE_FORMAT}
OUTPUT_DIR : ${OUTPUT_DIR}
EOF

if [[ ! -d "${BIGTOP_HOME}" ]]; then
  echo "Bigtop home not found: ${BIGTOP_HOME}" >&2
  echo "Please clone or mount Apache Bigtop source code before running this script." >&2
  exit 1
fi

if [[ -z "${BIGTOP_GRADLE_TASK_TEMPLATE}" ]]; then
  cat >&2 <<EOF
Bigtop build command is not configured.

Set BIGTOP_GRADLE_TASK_TEMPLATE to a real Gradle task template before running.
The token {component} will be replaced for each component.

Example:
  BIGTOP_GRADLE_TASK_TEMPLATE='{component}-${PACKAGE_FORMAT}' $0
EOF
  exit 2
fi

cd "${BIGTOP_HOME}"

for component in ${COMPONENTS}; do
  task="${BIGTOP_GRADLE_TASK_TEMPLATE//\{component\}/${component}}"
  echo "Build component package: ${component} with Gradle task ${task}"
  ./gradlew "${task}" -PparentDir="${OUTPUT_DIR}"
done

echo "Build completed. Check output directory: ${OUTPUT_DIR}"
