#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p /work/evidence
trap 'cp /var/log/ambari-metrics-monitor/ambari-metrics-monitor.log /work/evidence/monitor-runtime.log 2>/dev/null || true' EXIT
timeout 300 dnf -y --disablerepo='*' --enablerepo=OS,everything --setopt=timeout=30 --setopt=retries=2 install python3 python3-pip python3-psutil
timeout 120 python3 -m pip install --disable-pip-version-check fissix==24.4.24 appdirs==1.4.4
rpm -q python3 python3-psutil > /work/evidence/runtime-packages.txt
export METRICS_MONITOR_UPSTREAM_SOURCE=/source/ambari-metrics-host-monitoring/src/main/python
python3 /workspace/scripts/ambari-metrics/test_port_monitor.py
python3 /workspace/scripts/ambari-metrics/test_monitor_payload.py
python3 /workspace/scripts/ambari-metrics/port_monitor.py \
  --source /source/ambari-metrics-host-monitoring/src/main/python \
  --output /work/ported --manifest /work/evidence/port-manifest.json
python3 -m compileall -q /work/ported
timeout --kill-after=15 360 python3 /workspace/scripts/ambari-metrics/test_monitor_live.py \
  --monitor-root /work/ported --config-source /source/ambari-metrics-host-monitoring/conf/unix \
  --evidence-root /work/evidence
