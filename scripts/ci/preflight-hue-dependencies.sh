#!/usr/bin/env bash
set -euo pipefail

# Resolve and install Hue's documented native build prerequisites in the
# target openEuler image. This is a package-resolution gate only: no Hue
# source is cloned, no Python requirements are installed, and no compilation
# is attempted.
packages=(
  ca-certificates
  curl
  gcc
  gcc-c++
  git
  gmp-devel
  krb5-devel
  libffi-devel
  libxml2-devel
  libxslt-devel
  make
  openldap-devel
  openssl-devel
  python3
  python3-devel
  python3-pip
  sqlite-devel
  cyrus-sasl-devel
  tar
  xz
)

dnf -y install "${packages[@]}"

python3 --version
python3 -m pip --version
bootstrap_python="$(mktemp -d /tmp/hue-bootstrap.XXXXXX)"
python3 -m venv "${bootstrap_python}"
[[ -x "${bootstrap_python}/bin/python3.9" && -x "${bootstrap_python}/bin/pip3.9" ]]
[[ "$(PATH="${bootstrap_python}/bin:${PATH}" command -v python3.9)" == "${bootstrap_python}/bin/python3.9" ]]
"${bootstrap_python}/bin/python3.9" -m pip --version
rm -rf "${bootstrap_python}"
python3 - <<'PY'
import sys

if sys.version_info[:2] != (3, 9):
    raise SystemExit(
        f"Hue preflight requires Python 3.9; found {sys.version.split()[0]}"
    )
print(f"python_build_runtime: {sys.version.split()[0]}")
PY

for tool in gcc g++ git make; do
  command -v "$tool"
done

rpm -q \
  gcc gcc-c++ gmp-devel krb5-devel libffi-devel libxml2-devel \
  libxslt-devel openldap-devel openssl-devel python3 python3-devel \
  sqlite-devel cyrus-sasl-devel

echo "Hue openEuler native/Python dependency preflight: PASS"
echo "No Hue source build or RPM build was performed."

# Verify the pinned source and build-only Node toolchain without compiling Hue.
: "${HUE_SOURCE_IDENTITY:?HUE_SOURCE_IDENTITY is required}"
: "${HUE_VERSION:?HUE_VERSION is required}"
[[ "${HUE_SOURCE_IDENTITY}" =~ ^[0-9a-f]{40}$ ]]
[[ "$(uname -m)" == x86_64 ]]
node_archive="/tmp/node-v22.23.0-linux-x64.tar.xz"
node_sha256=14d7de44f235534799f8b171a4050d9a6a4bc99c87e053a25d3d54afa580aa20
curl --fail --location --retry 3 --output "${node_archive}" \
  https://nodejs.org/dist/v22.23.0/node-v22.23.0-linux-x64.tar.xz
printf '%s  %s\n' "${node_sha256}" "${node_archive}" | sha256sum --check --status
node_root="$(mktemp -d /tmp/hue-node.XXXXXX)"
tar -xJf "${node_archive}" --strip-components=1 -C "${node_root}"
export PATH="${node_root}/bin:${PATH}"
[[ "$(node --version)" == v22.23.0 ]]
npm --version

hue_source="$(mktemp -d /tmp/hue-source.XXXXXX)"
git -C "${hue_source}" init --quiet
git -C "${hue_source}" remote add origin https://github.com/cloudera/hue.git
git -C "${hue_source}" fetch --quiet --depth=1 origin "${HUE_SOURCE_IDENTITY}"
git -C "${hue_source}" -c advice.detachedHead=false checkout --quiet --detach FETCH_HEAD
actual_source_identity="$(git -C "${hue_source}" rev-parse HEAD)"
[[ "${actual_source_identity}" == "${HUE_SOURCE_IDENTITY}" ]]
hue_source_version="$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' "${hue_source}/VERSION" | head -n1)"
[[ "${hue_source_version}" == "${HUE_VERSION}" ]]
grep -Eq '^apps: desktop$' "${hue_source}/Makefile"
grep -Eq '^install: virtual-env install-check install-core-structure install-desktop install-apps install-env$' "${hue_source}/Makefile"
grep -Eq '^npm-install:' "${hue_source}/Makefile"
[[ -s "${hue_source}/package.json" && -s "${hue_source}/package-lock.json" ]]
python3 - "${hue_source}/package.json" "${hue_source}/package-lock.json" <<'PY'
import json
import pathlib
import sys

package = json.loads(pathlib.Path(sys.argv[1]).read_text())
lock = json.loads(pathlib.Path(sys.argv[2]).read_text())
if package.get("name") != "gethue":
    raise SystemExit(f"unexpected Hue frontend package: {package.get('name')!r}")
if lock.get("lockfileVersion", 0) < 2:
    raise SystemExit("Hue package-lock.json is not a modern reproducibility lock")
for task in ("webpack", "webpack-login", "webpack-workers"):
    if task not in package.get("scripts", {}):
        raise SystemExit(f"missing pinned frontend task: {task}")
print(f"frontend_package: {package['name']}@{package['version']}")
print(f"npm_lockfile_version: {lock['lockfileVersion']}")
PY

echo "hue_source_identity: ${actual_source_identity}"
echo "hue_source_version: ${hue_source_version}"
echo "node_build_toolchain: $(node --version)"
echo "Hue source and build-input preflight: PASS"
echo "No Hue Python requirements were installed and no Hue compilation or RPM build was performed."
