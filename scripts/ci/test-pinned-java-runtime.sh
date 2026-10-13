#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="${ROOT}/scripts/ci/install-pinned-java-runtime.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

mkdir -p "${tmp}/payload/jdk-test/bin" "${tmp}/fake-bin"
cat > "${tmp}/payload/jdk-test/bin/java" <<'JAVA'
#!/usr/bin/env bash
echo 'openjdk version "25.0.1"' >&2
JAVA
chmod +x "${tmp}/payload/jdk-test/bin/java"
tar -czf "${tmp}/jdk.tar.gz" -C "${tmp}/payload" jdk-test
cat > "${tmp}/fake-bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
output=
while (($#)); do
  if [[ "$1" == --output ]]; then output="$2"; shift 2; else shift; fi
done
[[ -n "${output}" ]]
cp "${FAKE_JDK_ARCHIVE}" "${output}"
CURL
chmod +x "${tmp}/fake-bin/curl"

archive_sha="$(sha256sum "${tmp}/jdk.tar.gz" | awk '{print $1}')"
PATH="${tmp}/fake-bin:${PATH}" FAKE_JDK_ARCHIVE="${tmp}/jdk.tar.gz" \
  JDK_RUNTIME_ARCHIVE_URL=https://example.invalid/jdk.tar.gz \
  JDK_RUNTIME_ARCHIVE_SHA256="${archive_sha}" COMPONENT_JDK=25 \
  JDK_RUNTIME_ROOT="${tmp}/installed" \
  bash -c 'source "$1"; [[ "$JAVA_HOME" == "'"${tmp}/installed"'/jdk-test" ]]; java -version 2>&1 | grep -q "25\.0\.1"' _ "${HELPER}"

if PATH="${tmp}/fake-bin:${PATH}" FAKE_JDK_ARCHIVE="${tmp}/jdk.tar.gz" \
  JDK_RUNTIME_ARCHIVE_URL=https://example.invalid/jdk.tar.gz \
  JDK_RUNTIME_ARCHIVE_SHA256="$(printf '%064d' 0)" COMPONENT_JDK=25 \
  JDK_RUNTIME_ROOT="${tmp}/bad-install" bash -c 'source "$1"' _ "${HELPER}"; then
  echo "expected invalid runtime archive checksum to fail" >&2
  exit 1
fi

echo "PASS: pinned Java runtime archive installs by SHA256 and rejects mismatches"
