#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILDER="${ROOT}/scripts/ci/build-hue-rpm-openeuler-container.sh"

for source in \
  'Source3:        hue.ini' \
  'Source4:        hue-server' \
  'Source5:        hue.service'; do
  grep -Fq "${source}" "${BUILDER}" || {
    echo "Missing RPM source declaration: ${source}" >&2
    exit 1
  }
done

grep -Fq 'install -m 0644 %{SOURCE3} %{buildroot}/etc/hue/hue.ini' "${BUILDER}"
grep -Fq 'install -m 0755 %{SOURCE4} %{buildroot}/usr/libexec/hue/hue-server' "${BUILDER}"
grep -Fq 'install -m 0644 %{SOURCE5} %{buildroot}/usr/lib/systemd/system/hue.service' "${BUILDER}"
grep -Fq '%config(noreplace) /etc/hue/hue.ini' "${BUILDER}"
grep -Fq '/usr/libexec/hue/hue-server' "${BUILDER}"
grep -Fq '/usr/lib/systemd/system/hue.service' "${BUILDER}"

echo "Hue RPM payload contract: PASS"
