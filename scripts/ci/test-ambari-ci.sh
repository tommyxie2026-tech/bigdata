#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_SCRIPT="${REPO_ROOT}/scripts/ci/build-ambari-rpms.sh"
TEST_SCRIPT="${REPO_ROOT}/scripts/ci/test-ambari-rpms.sh"
STAGE_SCRIPT="${REPO_ROOT}/scripts/ci/stage-tested-ambari-rpms.sh"
WORKFLOW="${REPO_ROOT}/.github/workflows/build-ambari.yml"
CI_WORKFLOW="${REPO_ROOT}/.github/workflows/ci-pr.yml"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

new_fixture() {
  local root
  root="$(mktemp -d)"
  mkdir -p "${root}/bin" "${root}/source" "${root}/work" "${root}/calls"
  touch "${root}/source/pom.xml"
  printf '%s\n' "${root}"
}

write_common_build_stubs() {
  local root="$1"
  cat > "${root}/bin/java" <<'EOF'
#!/usr/bin/env bash
echo 'openjdk version "17.0.13"'
EOF
  cat > "${root}/bin/node" <<'EOF'
#!/usr/bin/env bash
echo 'v20.18.0'
EOF
  cat > "${root}/bin/npm" <<'EOF'
#!/usr/bin/env bash
echo '10.8.2'
EOF
  cat > "${root}/bin/rpmbuild" <<'EOF'
#!/usr/bin/env bash
echo 'RPM version 4.18.2'
EOF
  chmod +x "${root}/bin/"*
}

test_build_collects_only_core_runtime_rpms() {
  local root
  root="$(new_fixture)"
  trap 'rm -rf "${root}"' RETURN
  write_common_build_stubs "${root}"
  cat > "${root}/bin/mvn" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p \
  ambari-server/target/rpm/ambari-server/RPMS/noarch \
  ambari-agent/target/rpm/ambari-agent/RPMS/x86_64 \
  ambari-agent/target/rpm/ambari-agent/SRPMS \
  ambari-server/target/rpm/ambari-server/RPMS/noarch
touch ambari-server/target/rpm/ambari-server/RPMS/noarch/ambari-server-3.0.0.0-0.noarch.rpm
touch ambari-agent/target/rpm/ambari-agent/RPMS/x86_64/ambari-agent-3.0.0.0-0.x86_64.rpm
touch ambari-agent/target/rpm/ambari-agent/RPMS/x86_64/ambari-agent-debuginfo-3.0.0.0-0.x86_64.rpm
touch ambari-agent/target/rpm/ambari-agent/SRPMS/ambari-agent-3.0.0.0-0.src.rpm
EOF
  chmod +x "${root}/bin/mvn"

  PATH="${root}/bin:${PATH}" \
    JAVA_HOME="${root}/fake-java" \
    AMBARI_SOURCE_DIR="${root}/source" \
    WORK_ROOT="${root}/work" \
    AMBARI_INSTALL_BUILD_DEPS=false \
    bash "${BUILD_SCRIPT}"

  rpm_list="$(find "${root}/work/artifacts/rpms" -maxdepth 1 -type f -name '*.rpm' -exec basename {} \; | sort)"
  expected_list=$'ambari-agent-3.0.0.0-0.x86_64.rpm\nambari-server-3.0.0.0-0.noarch.rpm'
  [[ "${rpm_list}" == "${expected_list}" ]] || fail "unexpected runtime RPM set: ${rpm_list}"
  grep -qx 'status: PASS' "${root}/work/artifacts/evidence/evidence.md"
  grep -qx 'jdk: 17' "${root}/work/artifacts/evidence/evidence.md"
}

test_build_rejects_incomplete_core_package_set() {
  local root
  root="$(new_fixture)"
  trap 'rm -rf "${root}"' RETURN
  write_common_build_stubs "${root}"
  cat > "${root}/bin/mvn" <<'EOF'
#!/usr/bin/env bash
mkdir -p ambari-server/target/rpm/ambari-server/RPMS/noarch
touch ambari-server/target/rpm/ambari-server/RPMS/noarch/ambari-server-3.0.0.0-0.noarch.rpm
EOF
  chmod +x "${root}/bin/mvn"

  if PATH="${root}/bin:${PATH}" \
    JAVA_HOME="${root}/fake-java" \
    AMBARI_SOURCE_DIR="${root}/source" \
    WORK_ROOT="${root}/work" \
    AMBARI_INSTALL_BUILD_DEPS=false \
    bash "${BUILD_SCRIPT}"; then
    fail "build accepted a missing ambari-agent RPM"
  fi
  grep -qx 'status: FAIL' "${root}/work/artifacts/evidence/evidence.md"
}

test_install_smoke_verifies_both_core_packages() {
  local root
  root="$(mktemp -d)"
  trap 'rm -rf "${root}"' RETURN
  mkdir -p "${root}/artifact/rpms" "${root}/artifact/evidence" "${root}/evidence" "${root}/bin"
  touch "${root}/artifact/rpms/ambari-server-3.0.0.0-0.noarch.rpm"
  touch "${root}/artifact/rpms/ambari-agent-3.0.0.0-0.x86_64.rpm"
  (cd "${root}/artifact" && sha256sum rpms/*.rpm > evidence/SHA256SUMS)
  cat > "${root}/bin/dnf" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> '${root}/dnf.calls'
EOF
  cat > "${root}/bin/rpm" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *ambari-server*) echo 'ambari-server-3.0.0.0-0.noarch' ;;
  *ambari-agent*) echo 'ambari-agent-3.0.0.0-0.x86_64' ;;
  *) exit 1 ;;
esac
EOF
  cat > "${root}/bin/ambari-server" <<'EOF'
#!/usr/bin/env bash
echo '3.0.0.0'
EOF
  cat > "${root}/bin/ambari-agent" <<'EOF'
#!/usr/bin/env bash
echo '3.0.0.0'
EOF
  chmod +x "${root}/bin/"*

  PATH="${root}/bin:${PATH}" \
    ARTIFACT_ROOT="${root}/artifact" \
    EVIDENCE_ROOT="${root}/evidence" \
    bash "${TEST_SCRIPT}"

  grep -qx 'status: PASS' "${root}/evidence/evidence.md"
  grep -q 'ambari-server' "${root}/dnf.calls"
  grep -q 'ambari-agent' "${root}/dnf.calls"
}

test_stage_publishes_only_verified_runtime_rpms() {
  local root
  root="$(mktemp -d)"
  trap 'rm -rf "${root}"' RETURN
  mkdir -p "${root}/tested/rpms" "${root}/tested/evidence" "${root}/test-evidence" "${root}/repo/repo" "${root}/bin"
  touch "${root}/tested/rpms/ambari-server-3.0.0.0-0.noarch.rpm"
  touch "${root}/tested/rpms/ambari-agent-3.0.0.0-0.x86_64.rpm"
  touch "${root}/tested/rpms/ambari-agent-debuginfo-3.0.0.0-0.x86_64.rpm"
  (cd "${root}/tested" && sha256sum rpms/*.rpm > evidence/SHA256SUMS)
  cat > "${root}/test-evidence/evidence.md" <<'EOF'
status: PASS
component: ambari
version: 3.0.0
EOF
  cat > "${root}/bin/createrepo_c" <<'EOF'
#!/usr/bin/env bash
target="${@: -1}"
mkdir -p "${target}/repodata"
printf '%s\n' '<repomd/>' > "${target}/repodata/repomd.xml"
EOF
  chmod +x "${root}/bin/createrepo_c"

  PATH="${root}/bin:${PATH}" \
    VERSION=3.0.0 \
    TEST_RUN_ID=123456 \
    SOURCE_SHA=0123456789abcdef0123456789abcdef01234567 \
    REPO_CHECKOUT="${root}/repo" \
    TESTED_RPMS_DIR="${root}/tested" \
    TEST_EVIDENCE_DIR="${root}/test-evidence" \
    bash "${STAGE_SCRIPT}"

  target="${root}/repo/repo/openeuler-22.03-lts-sp4/ambari/3.0.0"
  [[ -f "${target}/ambari-server-3.0.0.0-0.noarch.rpm" ]] || fail "staged server RPM missing"
  [[ -f "${target}/ambari-agent-3.0.0.0-0.x86_64.rpm" ]] || fail "staged agent RPM missing"
  [[ ! -e "${target}/ambari-agent-debuginfo-3.0.0.0-0.x86_64.rpm" ]] || fail "debug RPM was published"
  grep -qx 'test_status: PASS' "${target}/manifest.yaml"
  [[ -s "${target}/repodata/repomd.xml" ]] || fail "repository metadata missing"
}

test_workflow_orders_build_test_release() {
  ruby - "${WORKFLOW}" <<'RUBY'
require "yaml"
workflow = YAML.load_file(ARGV.fetch(0))
jobs = workflow.fetch("jobs")
abort "missing build job" unless jobs.key?("build")
abort "test must need build" unless jobs.dig("test", "needs") == "build"
abort "release must need test" unless jobs.dig("release", "needs") == "test"
abort "build timeout must be bounded" unless jobs.dig("build", "timeout-minutes").to_i.between?(1, 240)
RUBY
}

test_ci_pr_runs_ambari_contract_tests() {
  ruby - "${CI_WORKFLOW}" <<'RUBY'
require "yaml"
workflow = YAML.load_file(ARGV.fetch(0))
steps = workflow.fetch("jobs").fetch("shell").fetch("steps")
commands = steps.map { |step| step["run"] }.compact.join("\n")
abort "CI PR does not execute Ambari CI contract tests" unless commands.include?("bash scripts/ci/test-ambari-ci.sh")
RUBY
}

test_build_collects_only_core_runtime_rpms
test_build_rejects_incomplete_core_package_set
test_install_smoke_verifies_both_core_packages
test_stage_publishes_only_verified_runtime_rpms
test_workflow_orders_build_test_release
test_ci_pr_runs_ambari_contract_tests
echo "Ambari CI tests: PASS"
