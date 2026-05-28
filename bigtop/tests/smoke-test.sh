#!/usr/bin/env bash
set -euo pipefail

# Basic smoke test for a Hadoop cluster installed by Ambari.
# Run this script on a gateway/client node with Hadoop client commands available.

TEST_DIR="/tmp/bigdata-smoke-test-$(date +%s)"
TEST_FILE="${TEST_DIR}/hello.txt"

run_cmd() {
  echo "+ $*"
  "$@"
}

echo "Smoke test started."

if ! command -v hdfs >/dev/null 2>&1; then
  echo "hdfs command not found. Please run this on a Hadoop client node." >&2
  exit 1
fi

run_cmd hdfs dfs -mkdir -p "${TEST_DIR}"
echo "hello bigdata" | hdfs dfs -put - "${TEST_FILE}"
run_cmd hdfs dfs -cat "${TEST_FILE}"
run_cmd hdfs dfs -rm -r "${TEST_DIR}"

if command -v yarn >/dev/null 2>&1; then
  run_cmd yarn node -list || true
fi

if command -v hive >/dev/null 2>&1; then
  echo "show databases;" | hive || true
fi

echo "Smoke test completed."
