#!/usr/bin/env bash
set -euo pipefail

# Publish a local package repository from built DEB or RPM packages.

PACKAGE_DIR="${PACKAGE_DIR:-$(pwd)/packages}"
REPO_DIR="${REPO_DIR:-$(pwd)/repo}"
PACKAGE_FORMAT="${PACKAGE_FORMAT:-deb}"

if [[ ! -d "${PACKAGE_DIR}" ]]; then
  echo "Package directory not found: ${PACKAGE_DIR}" >&2
  exit 1
fi

mkdir -p "${REPO_DIR}"

case "${PACKAGE_FORMAT}" in
  deb)
    find "${PACKAGE_DIR}" -maxdepth 1 -name '*.deb' -exec cp -av {} "${REPO_DIR}/" \;
    if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
      echo "dpkg-scanpackages command not found. Please install dpkg-dev." >&2
      exit 1
    fi
    (
      cd "${REPO_DIR}"
      dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
    )
    repo_type="apt"
    ;;
  rpm)
    find "${PACKAGE_DIR}" -maxdepth 1 -name '*.rpm' -exec cp -av {} "${REPO_DIR}/" \;
    if ! command -v createrepo >/dev/null 2>&1; then
      echo "createrepo command not found. Please install createrepo or createrepo_c." >&2
      exit 1
    fi
    createrepo "${REPO_DIR}"
    repo_type="yum"
    ;;
  *)
    echo "Unsupported PACKAGE_FORMAT: ${PACKAGE_FORMAT}. Use deb or rpm." >&2
    exit 2
    ;;
esac

cat <<EOF
Local ${repo_type} repository published.

repo dir: ${REPO_DIR}

You can serve it with:
  cd ${REPO_DIR}
  python3 -m http.server 8088
EOF
