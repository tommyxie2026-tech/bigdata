#!/usr/bin/env bash
set -euo pipefail

# Publish a local yum repository from built RPM packages.

PACKAGE_DIR="${PACKAGE_DIR:-$(pwd)/packages}"
REPO_DIR="${REPO_DIR:-$(pwd)/repo}"

if [[ ! -d "${PACKAGE_DIR}" ]]; then
  echo "Package directory not found: ${PACKAGE_DIR}" >&2
  exit 1
fi

mkdir -p "${REPO_DIR}"
cp -av "${PACKAGE_DIR}"/*.rpm "${REPO_DIR}/" || true

if ! command -v createrepo >/dev/null 2>&1; then
  echo "createrepo command not found. Please install createrepo or createrepo_c." >&2
  exit 1
fi

createrepo "${REPO_DIR}"

cat <<EOF
Local yum repository published.

repo dir: ${REPO_DIR}

You can serve it with:
  cd ${REPO_DIR}
  python3 -m http.server 8088
EOF
