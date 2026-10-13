#!/usr/bin/env bash
set -euo pipefail

COMPONENT="${COMPONENT:?COMPONENT is required}"
VERSION="${VERSION:?VERSION is required}"
TEST_RUN_ID="${TEST_RUN_ID:?TEST_RUN_ID is required}"
BUILD_RUN_ID="${BUILD_RUN_ID:-${TEST_RUN_ID}}"
SOURCE_SHA="${SOURCE_SHA:?SOURCE_SHA is required}"
REPO_CHECKOUT="${REPO_CHECKOUT:?REPO_CHECKOUT is required}"
TESTED_RPMS_DIR="${TESTED_RPMS_DIR:-/tmp/tested-rpms}"
TEST_EVIDENCE_DIR="${TEST_EVIDENCE_DIR:-/tmp/test-evidence}"
CI_SOURCE_ROOT="${CI_SOURCE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SOURCE_IDENTITY="${SOURCE_IDENTITY:-}"
COMPATIBILITY_IDENTITY="${COMPATIBILITY_IDENTITY:-}"
ARTIFACT_TYPE="${ARTIFACT_TYPE:-service-rpm}"
TEST_PROFILE="${TEST_PROFILE:-legacy-smoke}"
COMPONENT_JDK="${COMPONENT_JDK:-8}"
COMPONENT_JDK_PACKAGE="${COMPONENT_JDK_PACKAGE-java-1.8.0-openjdk}"
JDK_RUNTIME_ARCHIVE_SHA256="${JDK_RUNTIME_ARCHIVE_SHA256:-}"

case "${COMPONENT}" in
  zookeeper|hadoop|tez|hive|spark|hbase|kafka|flink|trino|hue|iceberg|hudi|paimon) ;;
  *) echo "Unsupported component: ${COMPONENT}" >&2; exit 2 ;;
esac
[[ "${VERSION}" =~ ^[0-9]+(\.[0-9]+){0,3}$ ]]
[[ "${TEST_RUN_ID}" =~ ^[0-9]+$ ]]
[[ "${SOURCE_SHA}" =~ ^[0-9a-f]{40}$ ]]
if [[ -n "${COMPATIBILITY_IDENTITY}" ]]; then
  [[ "${COMPATIBILITY_IDENTITY}" =~ ^[0-9a-f]{64}$ ]]
  grep -qx "compatibility_identity: ${COMPATIBILITY_IDENTITY}" "${TEST_EVIDENCE_DIR}/evidence.md"
fi
if [[ -n "${JDK_RUNTIME_ARCHIVE_SHA256}" ]]; then
  [[ "${JDK_RUNTIME_ARCHIVE_SHA256}" =~ ^[0-9a-f]{64}$ ]]
  grep -qx "jdk_runtime_archive_sha256: ${JDK_RUNTIME_ARCHIVE_SHA256}" "${TEST_EVIDENCE_DIR}/evidence.md"
fi

grep -qx 'status: PASS' "${TEST_EVIDENCE_DIR}/evidence.md"
grep -qx "component: ${COMPONENT}" "${TEST_EVIDENCE_DIR}/evidence.md"
grep -qx "version: ${VERSION}" "${TEST_EVIDENCE_DIR}/evidence.md"
if [[ -n "${SOURCE_IDENTITY}" ]]; then
  grep -qx "artifact_type: ${ARTIFACT_TYPE}" "${TEST_EVIDENCE_DIR}/evidence.md"
  grep -qx "test_profile: ${TEST_PROFILE}" "${TEST_EVIDENCE_DIR}/evidence.md"
  grep -qx "build_run_id: ${BUILD_RUN_ID}" "${TEST_EVIDENCE_DIR}/evidence.md"
  grep -qx "test_run_id: ${TEST_RUN_ID}" "${TEST_EVIDENCE_DIR}/evidence.md"
  grep -qx "source_identity: ${SOURCE_IDENTITY}" "${TEST_EVIDENCE_DIR}/evidence.md"
fi
(
  cd "${TESTED_RPMS_DIR}"
  # Older ZooKeeper/Hadoop build artifacts recorded container-absolute RPM
  # paths. Artifact download places all RPMs in rpms/, so normalize each
  # checksum entry before checking the exact uploaded file set and its hashes.
  normalized_checksums="$(mktemp)"
  trap 'rm -f "${normalized_checksums}"' EXIT
  awk 'NF >= 2 {
    name = $2
    sub(/^.*\//, "", name)
    if (name != ".rpm") print $1 "  rpms/" name
  }' evidence/SHA256SUMS > "${normalized_checksums}"
  [[ -s "${normalized_checksums}" ]]
  diff -u \
    <(awk '{print $2}' "${normalized_checksums}" | LC_ALL=C sort) \
    <(find rpms -maxdepth 1 -type f -name '*.rpm' ! -name '.rpm' \
      -print | LC_ALL=C sort)
  sha256sum -c "${normalized_checksums}"
)

repo_root="${REPO_CHECKOUT}/repo/openeuler-22.03-lts-sp4/bigtop-3.6"
target="${repo_root}/${COMPONENT}/${VERSION}"
common="${repo_root}/common/3.6.0"
if [[ -e "${target}" ]]; then
  case "${COMPONENT}" in
    tez|hive|spark|hbase|kafka|flink|trino|hue|iceberg|hudi)
      set +e
      python3 "${CI_SOURCE_ROOT}/scripts/ci/check-component-repo-fast-path.py" \
        --component "${COMPONENT}" \
        --version "${VERSION}" \
        --repo-checkout "${REPO_CHECKOUT}" \
        --components-file "${CI_SOURCE_ROOT}/ci/components.yaml" \
        --source-identity "${SOURCE_IDENTITY}" \
        --compatibility-identity "${COMPATIBILITY_IDENTITY}" \
        --artifact-type "${ARTIFACT_TYPE}" \
        --test-profile "${TEST_PROFILE}" \
        --jdk "${COMPONENT_JDK}" \
        --jdk-package "${COMPONENT_JDK_PACKAGE}"
      check_status=$?
      set -e
      case "${check_status}" in
        0)
          echo "Already promoted and verified: ${target}"
          exit 0
          ;;
        1)
          echo "Replacing stale or incomplete RPM repository directory: ${target}"
          rm -rf -- "${target}"
          ;;
        *)
          echo "Unable to safely validate existing RPM repository directory: ${target}" >&2
          exit "${check_status}"
          ;;
      esac
      ;;
    *)
      grep -qx "component: ${COMPONENT}" "${target}/manifest.yaml"
      grep -qx "version: ${VERSION}" "${target}/manifest.yaml"
      grep -qx 'test_status: PASS' "${target}/manifest.yaml"
      echo "Already promoted: ${target}"
      exit 0
      ;;
  esac
fi
mkdir -p "${target}" "${common}"
common_changed=false
runtime_packages_text="$(ruby -ryaml -e 'YAML.load_file(ARGV.fetch(0)).fetch("components").fetch(ARGV.fetch(1)).fetch("runtime_packages").each { |name| puts name }' \
  "${CI_SOURCE_ROOT}/ci/components.yaml" "${COMPONENT}")"
runtime_packages=()
while IFS= read -r package; do
  [[ -n "${package}" ]] && runtime_packages+=("${package}")
done <<< "${runtime_packages_text}"
[[ "${#runtime_packages[@]}" -gt 0 ]]
for package in "${runtime_packages[@]}"; do
  matches=()
  for rpm in "${TESTED_RPMS_DIR}"/rpms/*.rpm; do
    name="${rpm##*/}"
    case "${name}" in
      *.src.rpm|*-debuginfo-*|*-debugsource-*|*-doc-*|*-devel-*|*-test-*|*-tests-*|*-javadoc-*) continue ;;
    esac
    # Most RPMs include a release segment after the version; Trino's pinned
    # package deliberately uses package-version.arch.rpm without that segment.
    if [[ "${name}" == "${package}-${VERSION}-"* || "${name}" == "${package}-${VERSION}."* ]]; then
      matches+=("${rpm}")
    fi
  done
  if [[ "${#matches[@]}" -ne 1 ]]; then
    if [[ "${#matches[@]}" -eq 0 ]]; then
      echo "Missing configured runtime package ${package}; refusing incomplete promotion." >&2
    else
      echo "Multiple RPM artifacts match runtime package ${package}: ${matches[*]}" >&2
    fi
    exit 1
  fi
  cp "${matches[0]}" "${target}/"
done
for rpm in "${TESTED_RPMS_DIR}"/rpms/*.rpm; do
  name="${rpm##*/}"
  case "${name}" in
    *.src.rpm|*-debuginfo-*|*-debugsource-*|*-doc-*|*-devel-*|*-test-*|*-tests-*|*-javadoc-*) continue ;;
    bigtop-*)
      if [[ ! -e "${common}/${name}" ]]; then
        cp "${rpm}" "${common}/"
        common_changed=true
      fi
      ;;
    *) echo "Not staging non-allow-listed RPM: ${name}" ;;
  esac
done
rpm_count="$(find "${target}" -maxdepth 1 -type f -name '*.rpm' | wc -l | tr -d ' ')"
[[ "${rpm_count}" -gt 0 ]]

(
  cd "${target}"
  find . -maxdepth 1 -type f -name '*.rpm' -print0 | sort -z \
    | xargs -0 -r sha256sum > SHA256SUMS
  createrepo_c --no-database .
)

if [[ "${common_changed}" == true ]]; then
  (
    cd "${common}"
    find . -maxdepth 1 -type f -name '*.rpm' -print0 | sort -z \
      | xargs -0 -r sha256sum > SHA256SUMS
    createrepo_c --no-database .
  )
  common_count="$(find "${common}" -maxdepth 1 -type f -name '*.rpm' | wc -l | tr -d ' ')"
  cat > "${common}/manifest.yaml" <<EOF
schema: bigdata.rpm-repo/v2
component: common
version: 3.6.0
rpm_count: ${common_count}
test_status: PASS
repository_layout: split-runtime/v2
EOF
fi

manifest_schema=bigdata.rpm-repo/v1
if [[ -n "${SOURCE_IDENTITY}" || -n "${COMPATIBILITY_IDENTITY}" ]]; then manifest_schema=bigdata.rpm-repo/v2; fi
cat > "${target}/manifest.yaml" <<EOF
schema: ${manifest_schema}
component: ${COMPONENT}
version: ${VERSION}
bigtop_version: 3.6.0
artifact_type: ${ARTIFACT_TYPE}
test_profile: ${TEST_PROFILE}
jdk: ${COMPONENT_JDK}
jdk_package: ${COMPONENT_JDK_PACKAGE}
jdk_runtime_archive_sha256: ${JDK_RUNTIME_ARCHIVE_SHA256}
source_identity: ${SOURCE_IDENTITY}
compatibility_identity: ${COMPATIBILITY_IDENTITY}
build_run_id: ${BUILD_RUN_ID:-${TEST_RUN_ID}}
test_run_id: ${TEST_RUN_ID}
os: openEuler 22.03 LTS SP4
promotion_workflow_commit: ${SOURCE_SHA}
tested_artifact_run_id: ${TEST_RUN_ID}
rpm_count: ${rpm_count}
test_status: PASS
repository_layout: split-runtime/v2
EOF

echo "Staged ${rpm_count} verified RPMs in ${target}"
