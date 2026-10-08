#!/usr/bin/env bash
set -euo pipefail

AMBARI_REF="${AMBARI_REF:-release-3.0.0}"
AMBARI_VERSION="${AMBARI_VERSION:-3.0.0}"
AMBARI_REPO_URL="${AMBARI_REPO_URL:-https://github.com/apache/ambari.git}"
WORK_ROOT="${WORK_ROOT:-/work}"
AMBARI_SOURCE_DIR="${AMBARI_SOURCE_DIR:-${WORK_ROOT}/src/ambari}"
AMBARI_INSTALL_BUILD_DEPS="${AMBARI_INSTALL_BUILD_DEPS:-true}"

artifacts="${WORK_ROOT}/artifacts"
rpms="${artifacts}/rpms"
evidence="${artifacts}/evidence"
logs="${artifacts}/logs"
mkdir -p "${rpms}" "${evidence}" "${logs}" "$(dirname "${AMBARI_SOURCE_DIR}")"

if [[ "${AMBARI_INSTALL_BUILD_DEPS}" == true ]]; then
  dnf -y install \
    curl findutils gcc gcc-c++ git gzip java-17-openjdk-devel make maven \
    openssl-devel python3-devel python3-pip rpm-build tar unzip which
fi

for command in java mvn rpmbuild; do
  command -v "${command}" >/dev/null
done

export JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v javac || command -v java)")")")}"
export PATH="${JAVA_HOME}/bin:${PATH}"
export MAVEN_OPTS="${MAVEN_OPTS:-} -Xmx4g -XX:MaxMetaspaceSize=1g -Dmaven.wagon.http.retryHandler.count=5 -Dmaven.wagon.http.retryHandler.requestSentEnabled=true"

if [[ ! -f "${AMBARI_SOURCE_DIR}/pom.xml" ]]; then
  rm -rf "${AMBARI_SOURCE_DIR}"
  git clone --depth 1 --branch "${AMBARI_REF}" "${AMBARI_REPO_URL}" "${AMBARI_SOURCE_DIR}"
fi

set +e
(
  cd "${AMBARI_SOURCE_DIR}"
  mvn -B -T 1C clean install package rpm:rpm \
    -Drat.skip=true \
    -DskipTests \
    -Dmaven.test.skip=true \
    -Dfindbugs.skip=true \
    -Dcheckstyle.skip=true
) 2>&1 | tee "${logs}/ambari-build.log"
build_rc=${PIPESTATUS[0]}
set -e

find "${AMBARI_SOURCE_DIR}" -type f -name '*.rpm' -print0 | while IFS= read -r -d '' rpm; do
  name="${rpm##*/}"
  case "${name}" in
    *.src.rpm|*-debuginfo-*|*-debugsource-*|*-devel-*|*-test-*|*-tests-*|*-doc-*|*-javadoc-*) ;;
    ambari-server-*.rpm|ambari-agent-*.rpm) cp -v "${rpm}" "${rpms}/${name}" ;;
  esac
done

server_count="$(find "${rpms}" -maxdepth 1 -type f -name 'ambari-server-*.rpm' | wc -l | tr -d ' ')"
agent_count="$(find "${rpms}" -maxdepth 1 -type f -name 'ambari-agent-*.rpm' | wc -l | tr -d ' ')"
rpm_count="$(find "${rpms}" -maxdepth 1 -type f -name '*.rpm' | wc -l | tr -d ' ')"
status=PASS
if [[ "${build_rc}" -ne 0 || "${server_count}" -ne 1 || "${agent_count}" -ne 1 || "${rpm_count}" -ne 2 ]]; then
  status=FAIL
fi

find "${rpms}" -maxdepth 1 -type f -name '*.rpm' -exec basename {} \; | sort > "${evidence}/package-list.txt"
(
  cd "${artifacts}"
  find rpms -maxdepth 1 -type f -name '*.rpm' -print0 | sort -z | xargs -0 -r sha256sum > evidence/SHA256SUMS
)

cat > "${evidence}/evidence.md" <<EOF
# CI Evidence — Ambari RPM Build

schema: bigdata.evidence/v1
stage: build
component: ambari
version: ${AMBARI_VERSION}
ambari_ref: ${AMBARI_REF}
os: openEuler 22.03 LTS SP4
jdk: 17
rpm_count: ${rpm_count}
server_rpm_count: ${server_count}
agent_rpm_count: ${agent_count}
status: ${status}
EOF

cat "${evidence}/evidence.md"
[[ "${status}" == PASS ]]
