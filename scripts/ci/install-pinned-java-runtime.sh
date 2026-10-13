#!/usr/bin/env bash
# Install a catalog-pinned JDK archive into an isolated CI workspace.
set -euo pipefail

: "${JDK_RUNTIME_ARCHIVE_URL:?JDK_RUNTIME_ARCHIVE_URL is required}"
: "${JDK_RUNTIME_ARCHIVE_SHA256:?JDK_RUNTIME_ARCHIVE_SHA256 is required}"
: "${COMPONENT_JDK:?COMPONENT_JDK is required}"
JDK_RUNTIME_ROOT="${JDK_RUNTIME_ROOT:-/opt/bigdata-jdk-${COMPONENT_JDK}}"

[[ "${JDK_RUNTIME_ARCHIVE_URL}" == https://* ]] || {
  echo "JDK runtime archive URL must use HTTPS." >&2
  return 2 2>/dev/null || exit 2
}
[[ "${JDK_RUNTIME_ARCHIVE_SHA256}" =~ ^[0-9a-f]{64}$ ]] || {
  echo "JDK runtime archive SHA256 must be a lowercase 64-character digest." >&2
  return 2 2>/dev/null || exit 2
}
[[ "${COMPONENT_JDK}" =~ ^[0-9]+$ ]] || {
  echo "COMPONENT_JDK must be a numeric major version." >&2
  return 2 2>/dev/null || exit 2
}

mkdir -p "${JDK_RUNTIME_ROOT}"
archive="$(mktemp "${TMPDIR:-/tmp}/bigdata-jdk-${COMPONENT_JDK}.XXXXXX.tar.gz")"
trap 'rm -f "${archive}"' RETURN
curl --fail --location --retry 5 --retry-delay 3 --connect-timeout 30 \
  --output "${archive}" "${JDK_RUNTIME_ARCHIVE_URL}"
actual_sha="$(sha256sum "${archive}" | awk '{print $1}')"
[[ "${actual_sha}" == "${JDK_RUNTIME_ARCHIVE_SHA256}" ]] || {
  echo "JDK runtime archive checksum mismatch: expected ${JDK_RUNTIME_ARCHIVE_SHA256}, got ${actual_sha}." >&2
  return 1 2>/dev/null || exit 1
}

rm -rf "${JDK_RUNTIME_ROOT:?}"/*
tar -xzf "${archive}" -C "${JDK_RUNTIME_ROOT}"
java_binary="$(find "${JDK_RUNTIME_ROOT}" -type f -path '*/bin/java' -print -quit)"
[[ -n "${java_binary}" && -x "${java_binary}" ]] || {
  echo "Pinned runtime archive has no executable bin/java." >&2
  return 1 2>/dev/null || exit 1
}
JAVA_HOME="$(dirname "$(dirname "${java_binary}")")"
export JAVA_HOME
export PATH="${JAVA_HOME}/bin:${PATH}"
java_version="$(java -version 2>&1)"
grep -Eq "version \\\"${COMPONENT_JDK}(\\.|\\\")" <<<"${java_version}" || {
  echo "Installed Java does not match configured major ${COMPONENT_JDK}: ${java_version}" >&2
  return 1 2>/dev/null || exit 1
}
export JAVA_HOME PATH
echo "Installed and verified pinned Java ${COMPONENT_JDK} runtime at ${JAVA_HOME}"
