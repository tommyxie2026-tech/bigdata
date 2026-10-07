#!/usr/bin/env bash
set -euo pipefail

# openEuler 22.03 does not ship R. Follow Bigtop's renv source-build approach;
# Spark's RPM includes SparkR, so removing -Psparkr is not a valid workaround.
# SparkR's HTML vignette opens an SVG graphics device while R CMD build runs.
# Cairo headers must be present when compiling R itself, not installed later.
dnf -y install gcc-gfortran readline-devel bzip2-devel xz-devel pcre2-devel libcurl-devel \
  cairo-devel pango-devel libpng-devel \
  texlive-latex texlive-pdftex texlive-collection-fontsrecommended
pkg-config --modversion cairo
pkg-config --modversion pangocairo
# SparkR's R CMD check also renders its reference manual as PDF.
command -v pdflatex
pdflatex --version | head -n 1
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
Rscript -e 'stopifnot(getRversion() == "4.4.3", capabilities("cairo")); svg(tempfile(fileext=".svg")); plot(1, 1); dev.off(); library(methods); library(utils)'

# SparkR's R CMD build renders an HTML vignette with knitr and rmarkdown.
# openEuler does not provide Pandoc in the base image, so install a pinned
# upstream binary and verify it before the lengthy Maven and RPM builds.
PANDOC_VERSION=3.12
PANDOC_SHA256=67d7d011fed8c8543306022b985b9b2499ab9b74818df91d8727c7e9ebc5ba06
PANDOC_ARCHIVE="pandoc-${PANDOC_VERSION}-linux-amd64.tar.gz"
curl --fail --location --retry 5 --retry-delay 5 --connect-timeout 30 \
  --output "${source_root}/${PANDOC_ARCHIVE}" \
  "https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/${PANDOC_ARCHIVE}"
printf '%s  %s\n' "${PANDOC_SHA256}" "${source_root}/${PANDOC_ARCHIVE}" | sha256sum -c -
tar -xzf "${source_root}/${PANDOC_ARCHIVE}" -C /opt
ln -s "/opt/pandoc-${PANDOC_VERSION}/bin/pandoc" /usr/local/bin/pandoc
pandoc --version | head -n 1

# fs, an rmarkdown dependency, can compile its bundled libuv when the
# openEuler image has no libuv headers.
USE_BUNDLED_LIBUV=1 Rscript -e 'options(timeout=300); install.packages(c("knitr", "rmarkdown"), repos="https://cloud.r-project.org", Ncpus=2); stopifnot(requireNamespace("knitr", quietly=TRUE), requireNamespace("rmarkdown", quietly=TRUE), rmarkdown::pandoc_available())'
