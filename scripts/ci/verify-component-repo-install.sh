#!/usr/bin/env bash
set -euo pipefail

COMPONENT="${COMPONENT:?COMPONENT is required}"
VERSION="${VERSION:?VERSION is required}"
PACKAGE_LIST="${PACKAGE_LIST:?PACKAGE_LIST is required}"
REPO_ROOT="${REPO_ROOT:-/bigdata-repo}"
COMPONENT_REPO="${REPO_ROOT}/${COMPONENT}/${VERSION}"
COMMON_REPO="${REPO_ROOT}/common/3.6.0"
DEPENDENCY_REPO_PATHS="${DEPENDENCY_REPO_PATHS:-}"

[[ -f "${COMPONENT_REPO}/repodata/repomd.xml" ]]
[[ -f "${COMMON_REPO}/repodata/repomd.xml" ]]

cat > /etc/yum.repos.d/bigdata-fast-path.repo <<EOF
[bigdata-component]
name=BIGDATA component repository
baseurl=file://${COMPONENT_REPO}
enabled=1
gpgcheck=0
repo_gpgcheck=0
metadata_expire=0

[bigdata-common]
name=BIGDATA common repository
baseurl=file://${COMMON_REPO}
enabled=1
gpgcheck=0
repo_gpgcheck=0
metadata_expire=0
EOF

dependency_index=0
IFS=',' read -r -a dependency_paths <<< "${DEPENDENCY_REPO_PATHS}"
for dependency_path in "${dependency_paths[@]}"; do
  [[ -n "${dependency_path}" ]] || continue
  dependency_repo="${REPO_ROOT}/${dependency_path}"
  [[ -f "${dependency_repo}/repodata/repomd.xml" ]]
  cat >> /etc/yum.repos.d/bigdata-fast-path.repo <<EOF

[bigdata-dependency-${dependency_index}]
name=BIGDATA dependency repository ${dependency_path}
baseurl=file://${dependency_repo}
enabled=1
gpgcheck=0
repo_gpgcheck=0
metadata_expire=0
EOF
  dependency_index=$((dependency_index + 1))
done

dnf clean all
dnf makecache --refresh
while IFS= read -r package; do
  [[ -n "${package}" ]] || continue
  dnf -y install "${package}"
  rpm -q "${package}"
done <<< "${PACKAGE_LIST}"
