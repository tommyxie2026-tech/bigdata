#!/usr/bin/env bash
set -euo pipefail

# openEuler 22.03 does not ship R. Follow Bigtop's renv source-build approach;
# Spark's RPM includes SparkR, so removing -Psparkr is not a valid workaround.
dnf -y install gcc-gfortran readline-devel bzip2-devel xz-devel pcre2-devel libcurl-devel
R_VERSION=4.4.3
source_root="$(mktemp -d /tmp/spark-r.XXXXXX)"
trap 'rm -rf "${source_root}"' EXIT
curl --fail --location --retry 5 --retry-delay 5 --connect-timeout 30 \
  --output "${source_root}/R.tar.gz" \
  "https://cran.r-project.org/src/base/R-4/R-${R_VERSION}.tar.gz"
tar -xzf "${source_root}/R.tar.gz" -C "${source_root}"
cd "${source_root}/R-${R_VERSION}"
./configure --prefix=/usr/local --enable-R-shlib --with-recommended-packages=yes \
  --without-x --with-readline
make -j2
make install
ldconfig
R --version
Rscript -e 'stopifnot(getRversion() == "4.4.3"); library(methods); library(utils)'
