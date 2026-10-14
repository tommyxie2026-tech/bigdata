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
  sqlite-devel
  cyrus-sasl-devel
)

dnf -y install "${packages[@]}"

python3 --version
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
