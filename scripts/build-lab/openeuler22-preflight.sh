#!/usr/bin/env bash
set -euo pipefail

OUT=${1:-validation/bigtop/openeuler22-toolchain-preflight.md}
mkdir -p "$(dirname "$OUT")"

{
  echo "# openEuler22 Toolchain Preflight Evidence"
  echo
  echo "## Metadata"
  echo
  echo '```yaml'
  echo "task: TASK-304"
  echo "issue: '#23'"
  echo "status: EXECUTED"
  echo "result: REVIEW_REQUIRED"
  echo '```'
  echo

  echo "## OS"
  echo '```text'
  cat /etc/os-release || true
  uname -a || true
  echo '```'
  echo

  echo "## Package Manager"
  echo '```text'
  dnf --version || true
  rpm --version || true
  rpmbuild --version || true
  echo '```'
  echo

  echo "## JDK"
  echo '```text'
  java -version 2>&1 || true
  javac -version 2>&1 || true
  echo "JAVA_HOME=${JAVA_HOME:-}"
  echo '```'
  echo

  echo "## Build Tools"
  echo '```text'
  git --version || true
  curl --version | head -1 || true
  wget --version | head -1 || true
  tar --version | head -1 || true
  unzip -v | head -1 || true
  zip -v | head -2 || true
  make --version | head -1 || true
  gcc --version | head -1 || true
  g++ --version | head -1 || c++ --version | head -1 || true
  mvn -version || true
  python3 --version || true
  echo '```'
  echo

  echo "## Native Build Dependencies"
  echo '```text'
  autoconf --version | head -1 || true
  automake --version | head -1 || true
  libtool --version | head -1 || true
  patch --version | head -1 || true
  echo '```'
  echo

  echo "## Repository Tools"
  echo '```text'
  createrepo_c --version || createrepo --version || true
  echo '```'
  echo

  echo "## Service Compatibility"
  echo '```text'
  systemctl --version | head -1 || true
  command -v chkconfig || true
  command -v service || true
  command -v alternatives || true
  rpm -q initscripts || true
  rpm -q chkconfig || true
  echo '```'
  echo

  echo "## Result Matrix"
  echo
  echo '```yaml'
  echo "os_identity: REVIEW_REQUIRED"
  echo "dnf: REVIEW_REQUIRED"
  echo "rpm: REVIEW_REQUIRED"
  echo "rpmbuild: REVIEW_REQUIRED"
  echo "jdk8_runtime: REVIEW_REQUIRED"
  echo "jdk8_compiler: REVIEW_REQUIRED"
  echo "java_home: REVIEW_REQUIRED"
  echo "build_tools: REVIEW_REQUIRED"
  echo "native_build_dependencies: REVIEW_REQUIRED"
  echo "createrepo_or_createrepo_c: REVIEW_REQUIRED"
  echo "service_compatibility: REVIEW_REQUIRED"
  echo '```'
  echo

  echo "## Decision"
  echo
  echo '```yaml'
  echo "result: REVIEW_REQUIRED"
  echo "next_action: Review command output and change result matrix to PASS/FAIL."
  echo '```'
} | tee "$OUT"
