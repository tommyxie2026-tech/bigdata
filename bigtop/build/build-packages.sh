#!/usr/bin/env bash
set -euo pipefail

# Bigtop package build script skeleton.
# This script is a placeholder for standardizing component package builds.

BIGTOP_HOME="${BIGTOP_HOME:-/opt/bigtop}"
COMPONENTS="${COMPONENTS:-hadoop hive spark}"
OS_TARGET="${OS_TARGET:-rocky8}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/output}"

mkdir -p "${OUTPUT_DIR}"

cat <<EOF
Bigtop build plan
-----------------
BIGTOP_HOME: ${BIGTOP_HOME}
COMPONENTS : ${COMPONENTS}
OS_TARGET  : ${OS_TARGET}
OUTPUT_DIR : ${OUTPUT_DIR}
EOF

if [[ ! -d "${BIGTOP_HOME}" ]]; then
  echo "Bigtop home not found: ${BIGTOP_HOME}" >&2
  echo "Please clone or mount Apache Bigtop source code before running this script." >&2
  exit 1
fi

cd "${BIGTOP_HOME}"

for component in ${COMPONENTS}; do
  echo "Build component package: ${component}"
  # TODO: Replace with the real Bigtop build command for the target OS.
  # Example placeholder:
  # ./gradlew "${component}-rpm" -PparentDir="${OUTPUT_DIR}"
  echo "TODO build ${component} for ${OS_TARGET}"
done

echo "Build completed. Check output directory: ${OUTPUT_DIR}"
