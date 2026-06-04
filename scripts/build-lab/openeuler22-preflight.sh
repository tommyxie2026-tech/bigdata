#!/usr/bin/env bash
set -euo pipefail

OUT=${1:-validation/bigtop/openeuler22-toolchain-preflight.md}
CALLER_DIR=$(pwd)
RUN_VERSION_DETAILS=${RUN_VERSION_DETAILS:-0}

case "$OUT" in
  /*) OUT_PATH="$OUT" ;;
  *) OUT_PATH="$CALLER_DIR/$OUT" ;;
esac

mkdir -p "$(dirname "$OUT_PATH")"

status_for_command() {
  if command -v "$1" >/dev/null 2>&1; then
    printf "PASS"
  else
    printf "FAIL"
  fi
}

status_for_any_command() {
  for cmd in "$@"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf "PASS"
      return
    fi
  done
  printf "FAIL"
}

status_for_rpm_package() {
  if command -v rpm >/dev/null 2>&1 && rpm -q "$1" >/dev/null 2>&1; then
    printf "PASS"
  else
    printf "FAIL"
  fi
}

emit_command_path() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    command -v "$cmd"
  else
    echo "$cmd: NOT_FOUND"
  fi
}

emit_optional_version() {
  if [ "$RUN_VERSION_DETAILS" != "1" ]; then
    return
  fi
  "$@" 2>&1 | head -20 || true
}

jdk8_runtime_status="FAIL"
if command -v java >/dev/null 2>&1 && java -version 2>&1 | grep -Eq 'version "1\.8\.|openjdk version "1\.8\.'; then
  jdk8_runtime_status="PASS"
fi

jdk8_compiler_status="FAIL"
if command -v javac >/dev/null 2>&1 && javac -version 2>&1 | grep -Eq 'javac 1\.8\.'; then
  jdk8_compiler_status="PASS"
fi

java_home_status="FAIL"
if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
  java_home_status="PASS"
fi

os_identity_status="FAIL"
if [ -r /etc/os-release ] && grep -qi 'openeuler' /etc/os-release; then
  os_identity_status="PASS"
fi

dnf_status=$(status_for_command dnf)
rpm_status=$(status_for_command rpm)
rpmbuild_status=$(status_for_command rpmbuild)
git_status=$(status_for_command git)
curl_status=$(status_for_command curl)
wget_status=$(status_for_command wget)
tar_status=$(status_for_command tar)
unzip_status=$(status_for_command unzip)
zip_status=$(status_for_command zip)
make_status=$(status_for_command make)
gcc_status=$(status_for_command gcc)
cxx_status=$(status_for_any_command g++ c++)
maven_status=$(status_for_command mvn)
python3_status=$(status_for_command python3)
autoconf_status=$(status_for_command autoconf)
automake_status=$(status_for_command automake)
libtool_status=$(status_for_command libtool)
patch_status=$(status_for_command patch)
createrepo_status=$(status_for_any_command createrepo_c createrepo)
systemd_status=$(status_for_command systemctl)
chkconfig_status=$(status_for_command chkconfig)
service_status=$(status_for_command service)
alternatives_status=$(status_for_command alternatives)
initscripts_status=$(status_for_rpm_package initscripts)

result="PASS"
for value in \
  "$os_identity_status" \
  "$dnf_status" \
  "$rpm_status" \
  "$rpmbuild_status" \
  "$jdk8_runtime_status" \
  "$jdk8_compiler_status" \
  "$java_home_status" \
  "$git_status" \
  "$curl_status" \
  "$wget_status" \
  "$tar_status" \
  "$unzip_status" \
  "$zip_status" \
  "$make_status" \
  "$gcc_status" \
  "$cxx_status" \
  "$maven_status" \
  "$python3_status" \
  "$autoconf_status" \
  "$automake_status" \
  "$libtool_status" \
  "$patch_status" \
  "$createrepo_status" \
  "$systemd_status" \
  "$chkconfig_status" \
  "$service_status" \
  "$alternatives_status" \
  "$initscripts_status"; do
  if [ "$value" != "PASS" ]; then
    result="REVIEW_REQUIRED"
    break
  fi
done

{
  echo "# openEuler22 Toolchain Preflight Evidence"
  echo
  echo "## Metadata"
  echo
  echo '```yaml'
  echo "task: TASK-304"
  echo "issue: '#23'"
  echo "status: EXECUTED"
  echo "result: $result"
  echo "generated_at_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
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
  emit_command_path dnf
  emit_command_path rpm
  emit_command_path rpmbuild
  emit_optional_version dnf --version
  emit_optional_version rpm --version
  emit_optional_version rpmbuild --version
  echo '```'
  echo

  echo "## JDK"
  echo '```text'
  emit_command_path java
  emit_command_path javac
  emit_optional_version java -version
  emit_optional_version javac -version
  echo "JAVA_HOME=${JAVA_HOME:-}"
  echo '```'
  echo

  echo "## Build Tools"
  echo '```text'
  for cmd in git curl wget tar unzip zip make gcc g++ c++ mvn python3; do
    emit_command_path "$cmd"
  done
  emit_optional_version git --version
  emit_optional_version curl --version
  emit_optional_version wget --version
  emit_optional_version tar --version
  emit_optional_version unzip -v
  emit_optional_version zip -v
  emit_optional_version make --version
  emit_optional_version gcc --version
  emit_optional_version g++ --version
  emit_optional_version c++ --version
  emit_optional_version mvn -version
  emit_optional_version python3 --version
  echo '```'
  echo

  echo "## Native Build Dependencies"
  echo '```text'
  for cmd in autoconf automake libtool patch; do
    emit_command_path "$cmd"
  done
  emit_optional_version autoconf --version
  emit_optional_version automake --version
  emit_optional_version libtool --version
  emit_optional_version patch --version
  echo '```'
  echo

  echo "## Repository Tools"
  echo '```text'
  emit_command_path createrepo_c
  emit_command_path createrepo
  emit_optional_version createrepo_c --version
  emit_optional_version createrepo --version
  echo '```'
  echo

  echo "## Service Compatibility"
  echo '```text'
  emit_command_path systemctl
  emit_command_path chkconfig
  emit_command_path service
  emit_command_path alternatives
  if command -v rpm >/dev/null 2>&1; then
    rpm -q initscripts || true
    rpm -q chkconfig || true
  else
    echo "rpm: NOT_FOUND"
  fi
  echo '```'
  echo

  echo "## Result Matrix"
  echo
  echo '```yaml'
  echo "preflight_script_executed: PASS"
  echo "os_identity_recorded: $os_identity_status"
  echo "dnf_recorded: $dnf_status"
  echo "rpm_recorded: $rpm_status"
  echo "rpmbuild_recorded: $rpmbuild_status"
  echo "jdk8_runtime_verified: $jdk8_runtime_status"
  echo "jdk8_compiler_verified: $jdk8_compiler_status"
  echo "java_home_recorded: $java_home_status"
  echo "git_recorded: $git_status"
  echo "curl_recorded: $curl_status"
  echo "wget_recorded: $wget_status"
  echo "tar_recorded: $tar_status"
  echo "unzip_recorded: $unzip_status"
  echo "zip_recorded: $zip_status"
  echo "make_recorded: $make_status"
  echo "gcc_recorded: $gcc_status"
  echo "cxx_recorded: $cxx_status"
  echo "maven_recorded: $maven_status"
  echo "python3_recorded: $python3_status"
  echo "autoconf_recorded: $autoconf_status"
  echo "automake_recorded: $automake_status"
  echo "libtool_recorded: $libtool_status"
  echo "patch_recorded: $patch_status"
  echo "createrepo_recorded: $createrepo_status"
  echo "systemd_recorded: $systemd_status"
  echo "chkconfig_recorded: $chkconfig_status"
  echo "service_recorded: $service_status"
  echo "alternatives_recorded: $alternatives_status"
  echo "initscripts_recorded: $initscripts_status"
  echo "missing_dependencies_classified: REVIEW_REQUIRED"
  echo "package_name_mapping_recorded_if_needed: REVIEW_REQUIRED"
  echo '```'
  echo

  echo "## Decision"
  echo
  echo '```yaml'
  echo "result: $result"
  if [ "$result" = "PASS" ]; then
    echo "next_action: Proceed to Build ZooKeeper 3.9.5 RPM."
  else
    echo "next_action: Review FAIL values, install missing dependencies, update package-name mapping if needed, and rerun preflight."
  fi
  echo '```'
} | tee "$OUT_PATH"
