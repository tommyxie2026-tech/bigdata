#!/usr/bin/env bash
set -euo pipefail

BIGDATA_RC1_HOME="${BIGDATA_RC1_HOME:-/opt/bigdata-rc1}"
EVIDENCE_DIR="${EVIDENCE_DIR:-validation/bigtop}"
OUT="${1:-${EVIDENCE_DIR}/openeuler22-toolchain-preflight.md}"

mkdir -p "${BIGDATA_RC1_HOME}"/{src,patches,build,rpms,repo,logs,evidence}
mkdir -p "$(dirname "${OUT}")"

status_for_command() {
  if command -v "$1" >/dev/null 2>&1; then
    printf "PASS"
  else
    printf "FAIL"
  fi
}

run_or_note() {
  local label="$1"
  shift
  printf "\n### %s\n\n" "${label}"
  printf '```text\n'
  "$@" 2>&1 || true
  printf '```\n'
}

command_version() {
  local cmd="$1"
  shift
  if command -v "${cmd}" >/dev/null 2>&1; then
    "${cmd}" "$@" 2>&1 | head -20 || true
  else
    printf "%s: NOT_FOUND\n" "${cmd}"
  fi
}

java_runtime_status="FAIL"
if command -v java >/dev/null 2>&1 && java -version 2>&1 | grep -Eq 'version "1\.8\.|openjdk version "1\.8\.'; then
  java_runtime_status="PASS"
fi

javac_status="FAIL"
if command -v javac >/dev/null 2>&1 && javac -version 2>&1 | grep -Eq 'javac 1\.8\.'; then
  javac_status="PASS"
fi

java_home_status="FAIL"
if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
  java_home_status="PASS"
fi

createrepo_status="FAIL"
if command -v createrepo_c >/dev/null 2>&1 || command -v createrepo >/dev/null 2>&1; then
  createrepo_status="PASS"
fi

gxx_status="FAIL"
if command -v g++ >/dev/null 2>&1 || command -v c++ >/dev/null 2>&1; then
  gxx_status="PASS"
fi

{
  printf "# openEuler22 Toolchain Preflight Evidence\n\n"
  printf "## 1. Metadata\n\n"
  printf '```yaml\n'
  printf "task: TASK-301\n"
  printf "issue: 20\n"
  printf "status: EXECUTED\n"
  printf "evidence_type: build_lab_preflight\n"
  printf "generated_at_utc: %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf "bigdata_rc1_home: %s\n" "${BIGDATA_RC1_HOME}"
  printf "java_home: %s\n" "${JAVA_HOME:-}"
  printf '```\n'

  printf "\n## 2. Build Lab Directory Layout\n\n"
  printf '```text\n'
  find "${BIGDATA_RC1_HOME}" -maxdepth 1 -type d | sort || true
  printf '```\n'

  run_or_note "OS" cat /etc/os-release
  run_or_note "Kernel" uname -a
  run_or_note "Package Manager" bash -c 'command_version() { if command -v "$1" >/dev/null 2>&1; then "$@" 2>&1 | head -20 || true; else printf "%s: NOT_FOUND\n" "$1"; fi; }; command_version dnf --version; command_version rpm --version; command_version rpmbuild --version'
  run_or_note "JDK" bash -c 'java -version 2>&1 || true; javac -version 2>&1 || true; printf "JAVA_HOME=%s\n" "${JAVA_HOME:-}"'
  run_or_note "Build Tools" bash -c 'for cmd in git curl wget tar unzip zip make gcc mvn python3; do if command -v "$cmd" >/dev/null 2>&1; then "$cmd" --version 2>&1 | head -5 || true; else printf "%s: NOT_FOUND\n" "$cmd"; fi; done; if command -v g++ >/dev/null 2>&1; then g++ --version | head -5; elif command -v c++ >/dev/null 2>&1; then c++ --version | head -5; else printf "g++/c++: NOT_FOUND\n"; fi'
  run_or_note "Native Build Dependencies" bash -c 'for cmd in autoconf automake libtool patch; do if command -v "$cmd" >/dev/null 2>&1; then "$cmd" --version 2>&1 | head -5 || true; else printf "%s: NOT_FOUND\n" "$cmd"; fi; done'
  run_or_note "Repository Tools" bash -c 'if command -v createrepo_c >/dev/null 2>&1; then createrepo_c --version; elif command -v createrepo >/dev/null 2>&1; then createrepo --version; else printf "createrepo_c/createrepo: NOT_FOUND\n"; fi'
  run_or_note "Service Compatibility" bash -c 'systemctl --version 2>&1 | head -5 || true; command -v chkconfig || true; command -v service || true; command -v alternatives || true; rpm -q initscripts || true; rpm -q chkconfig || true'
  run_or_note "Network Or Mirror Access" bash -c 'curl -I --max-time 10 https://downloads.apache.org/ 2>&1 | head -20 || true; curl -I --max-time 10 https://github.com/apache/bigtop 2>&1 | head -20 || true'

  printf "\n## 3. Result Matrix\n\n"
  printf '```yaml\n'
  printf "workspace_created: PASS\n"
  printf "dnf_available: %s\n" "$(status_for_command dnf)"
  printf "rpm_available: %s\n" "$(status_for_command rpm)"
  printf "rpmbuild_available: %s\n" "$(status_for_command rpmbuild)"
  printf "jdk8_runtime_available: %s\n" "${java_runtime_status}"
  printf "jdk8_compiler_available: %s\n" "${javac_status}"
  printf "java_home_configured: %s\n" "${java_home_status}"
  printf "git: %s\n" "$(status_for_command git)"
  printf "curl: %s\n" "$(status_for_command curl)"
  printf "wget: %s\n" "$(status_for_command wget)"
  printf "tar: %s\n" "$(status_for_command tar)"
  printf "unzip: %s\n" "$(status_for_command unzip)"
  printf "zip: %s\n" "$(status_for_command zip)"
  printf "make: %s\n" "$(status_for_command make)"
  printf "gcc: %s\n" "$(status_for_command gcc)"
  printf "gxx_or_cxx: %s\n" "${gxx_status}"
  printf "maven: %s\n" "$(status_for_command mvn)"
  printf "python3: %s\n" "$(status_for_command python3)"
  printf "autoconf: %s\n" "$(status_for_command autoconf)"
  printf "automake: %s\n" "$(status_for_command automake)"
  printf "libtool: %s\n" "$(status_for_command libtool)"
  printf "patch: %s\n" "$(status_for_command patch)"
  printf "createrepo_or_createrepo_c: %s\n" "${createrepo_status}"
  printf "systemd: %s\n" "$(status_for_command systemctl)"
  printf "chkconfig: %s\n" "$(status_for_command chkconfig)"
  printf "service: %s\n" "$(status_for_command service)"
  printf "alternatives: %s\n" "$(status_for_command alternatives)"
  printf "initscripts_query: %s\n" "$(status_for_command rpm)"
  printf '```\n'

  printf "\n## 4. Decision\n\n"
  printf '```yaml\n'
  printf "result: REVIEW_REQUIRED\n"
  printf "next_action:\n"
  printf "  - Replace any FAIL values by installing the missing package or recording a package-name mapping.\n"
  printf "  - Update validation/bigtop/openeuler22-toolchain-install-log.md with install commands and outputs.\n"
  printf "  - Update validation/bigtop/openeuler22-package-name-mapping.md for openEuler-specific names.\n"
  printf "  - Mark Build Lab ready only after all issue #20 acceptance fields are PASS.\n"
  printf '```\n'
} > "${OUT}"

printf "Wrote %s\n" "${OUT}"
