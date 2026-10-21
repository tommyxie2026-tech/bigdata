#!/usr/bin/env bash
# A fresh openEuler container installs the RPMs, without Maven or build artifacts.
set -Eeuo pipefail
collect_runtime_logs() {
  status=$?
  for service in collector monitor; do
    if [[ -d /var/log/ambari-metrics-$service ]]; then
      cp -a "/var/log/ambari-metrics-$service" "/evidence/$service-runtime-logs"
    fi
  done
  return "$status"
}
trap collect_runtime_logs EXIT
trap 'echo "Metrics RPM acceptance failed at line $LINENO: $BASH_COMMAND" >&2' ERR
timeout 600 dnf -y --setopt=timeout=30 --setopt=retries=2 install python3 procps-ng util-linux
test ! -e /usr/lib/ambari-metrics-collector
test ! -e /usr/lib/ambari-metrics-monitor
(cd /rpm/rpms && sha256sum -c ../evidence/SHA256SUMS)
timeout 600 dnf -y --setopt=timeout=30 --setopt=retries=2 install /rpm/rpms/*.rpm
rpm -q ambari-metrics-collector ambari-metrics-monitor > /evidence/installed-packages.txt
rpm -V ambari-metrics-collector ambari-metrics-monitor > /evidence/rpm-verification.txt || {
  # The sole permitted post-install edit resolves this host's identity.
  grep -Ev '^[S.][.][5.][.][.][.][.][T.][.]  c /etc/ambari-metrics-monitor/conf/metric_monitor.ini$' /evidence/rpm-verification.txt > /evidence/unexpected-rpm-changes.txt || true
  test ! -s /evidence/unexpected-rpm-changes.txt
}
python3 - <<'PY'
import configparser
from pathlib import Path
p=Path('/etc/ambari-metrics-monitor/conf/metric_monitor.ini')
c=configparser.RawConfigParser();c.read(p)
# Exercise normal collection with a shorter test-only send interval.
c.set('emitter','send_interval','12');c.set('emitter','kinit_cmd','');c.set('emitter','klist_cmd','')
with p.open('w') as f:c.write(f)
PY
systemd-analyze verify /usr/lib/systemd/system/ambari-metrics-{hbase,collector,monitor}.service > /evidence/unit-verification.txt 2>&1
timeout --kill-after=20 1200 python3 /workspace/scripts/ambari-metrics/test_collector_live.py --evidence /evidence
cp /rpm/evidence/package.md /evidence/package.md
