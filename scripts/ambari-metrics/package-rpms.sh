#!/usr/bin/env bash
# Assemble real Collector/Monitor RPMs from the verified immutable source artifact.
set -Eeuo pipefail
trap 'echo "Metrics packaging failed at line $LINENO: $BASH_COMMAND" >&2' ERR
: "${SOURCE_BUILD_RUN_ID:?}"
timeout 600 dnf -y --setopt=timeout=30 --setopt=retries=2 install rpm-build python3 python3-pip curl tar gzip findutils
timeout 120 python3 -m pip install --disable-pip-version-check fissix==24.4.24 appdirs==1.4.4
input=/input
grep -qx 'source_identity: ce919386e963841ea37f032c5ba6ed9c48298dd8' "$input/evidence/evidence.md"
grep -qx "build_run_id: $SOURCE_BUILD_RUN_ID" "$input/evidence/evidence.md"
grep -qx 'collector_entrypoint: PASS' "$input/evidence/evidence.md"
grep -qx 'status: PASS' "$input/evidence/evidence.md"
(cd "$input" && sha256sum -c evidence/SHA256SUMS)
work=/work/package
mkdir -p "$work" /work/downloads /work/output/rpms /work/output/evidence
fetch() {
  local filename=$1 checksum=$2 url=$3
  if [[ -f "/work/downloads/$filename" ]] && echo "$checksum  /work/downloads/$filename" | sha512sum -c -; then return; fi
  curl --fail --location --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 360 \
    --retry 2 --retry-max-time 600 --output "/work/downloads/$filename.partial" "$url"
  echo "$checksum  /work/downloads/$filename.partial" | sha512sum -c -
  mv "/work/downloads/$filename.partial" "/work/downloads/$filename"
}
fetch hbase-2.4.13-bin.tar.gz \
  944208a875da7da345d1918ac012f512a6e32032c4b6702b22c6ff251c4bb2787695b6b3b7018034fad0e6cbb2dd2a7454d961c8b270539a0df64a1d5591390d \
  https://archive.apache.org/dist/hbase/2.4.13/hbase-2.4.13-bin.tar.gz
fetch phoenix-hbase-2.4-5.1.2-bin.tar.gz \
  9a671abf73a5c56f1adb173ef8a0dca33cbe15f219e7dc55d92a6f136a8e3549593d2f14bd185f221e1238554d13f86b75253e7e05e53f699fe4c7e1fe854c48 \
  https://s3.amazonaws.com/repo.bigtop.apache.org/bigtop-stack-binary/3.2.0/centos-7/x86_64/phoenix-hbase-2.4-5.1.2-bin.tar.gz
mkdir -p "$work/extracted"
tar -xzf /work/downloads/hbase-2.4.13-bin.tar.gz -C "$work/extracted"
tar -xzf /work/downloads/phoenix-hbase-2.4-5.1.2-bin.tar.gz -C "$work/extracted"
collector="$work/collector"
monitor="$work/monitor"
mkdir -p "$collector/usr/lib/ambari-metrics-collector" "$collector/usr/libexec/ambari-metrics" \
  "$collector/etc/ambari-metrics-collector/conf" "$collector/etc/ams-hbase/conf" \
  "$collector/usr/lib/systemd/system" "$collector/usr/share/licenses/ambari-metrics-collector" \
  "$monitor/usr/lib/ambari-metrics-monitor" "$monitor/etc/ambari-metrics-monitor/conf" \
  "$monitor/usr/lib/systemd/system" "$monitor/usr/share/licenses/ambari-metrics-monitor"
cp -a "$work/extracted/hbase-2.4.13" "$collector/usr/lib/ams-hbase"
cp "$work/extracted/phoenix-hbase-2.4-5.1.2-bin/phoenix-server-hbase-2.4-5.1.2.jar" \
  "$collector/usr/lib/ams-hbase/lib/phoenix-5.1.2-server.jar"
cp -a "$input/collector/lib/." "$collector/usr/lib/ambari-metrics-collector/"
cp "$input/collector/ambari-metrics-timelineservice-3.0.0.jar" "$collector/usr/lib/ambari-metrics-collector/"
cp -a "$input/collector/conf/." "$collector/etc/ambari-metrics-collector/conf/"
cp -a "$collector/usr/lib/ams-hbase/conf/." "$collector/etc/ams-hbase/conf/"
cp "$input/collector/conf/hbase-site.xml" "$collector/etc/ams-hbase/conf/"
cp "$input/LICENSE.txt" "$collector/usr/share/licenses/ambari-metrics-collector/"
cp "$input/LICENSE.txt" "$monitor/usr/share/licenses/ambari-metrics-monitor/"
mkdir -p "$collector/usr/share/licenses/ambari-metrics-collector/phoenix"
cp "$work/extracted/phoenix-hbase-2.4-5.1.2-bin/"{LICENSE,NOTICE} \
  "$collector/usr/share/licenses/ambari-metrics-collector/phoenix/"
python3 /workspace/scripts/ambari-metrics/port_monitor.py --source "$input/monitor/python" \
  --output "$work/ported" --manifest /work/output/evidence/monitor-port-manifest.json
cp -a "$work/ported/." "$monitor/usr/lib/ambari-metrics-monitor/"
cp "$input/monitor/conf/metric_monitor.ini" "$monitor/etc/ambari-metrics-monitor/conf/"
python3 /workspace/scripts/ambari-metrics/prepare-rpm-config.py "$collector" "$monitor" "$input/monitor/conf/metric_groups.conf"
cp /workspace/scripts/ambari-metrics/runtime.sh "$collector/usr/libexec/ambari-metrics/runtime"
chmod 755 "$collector/usr/libexec/ambari-metrics/runtime"
cp /workspace/scripts/ambari-metrics/units/ambari-metrics-{hbase,collector}.service "$collector/usr/lib/systemd/system/"
cp /workspace/scripts/ambari-metrics/units/ambari-metrics-monitor.service "$monitor/usr/lib/systemd/system/"
for package in collector monitor; do
  tree="$work/$package"
  install -d -m 755 "$tree/var/log/ambari-metrics-$package" "$tree/var/run/ambari-metrics-$package" "$tree/var/lib/ambari-metrics-$package"
done
install -d -m 755 "$collector/var/log/ams-hbase" "$collector/var/run/ams-hbase"
mkdir -p "$work/rpmbuild/"{SOURCES,SPECS,BUILD,RPMS,SRPMS}
for package in collector monitor; do
  tar -czf "$work/rpmbuild/SOURCES/$package.tar.gz" -C "$work" "$package"
  cp "/workspace/scripts/ambari-metrics/specs/$package.spec" "$work/rpmbuild/SPECS/"
  rpmbuild --define "_topdir $work/rpmbuild" -bb "$work/rpmbuild/SPECS/$package.spec"
done
find "$work/rpmbuild/RPMS" -name '*.rpm' -exec cp {} /work/output/rpms/ \;
(cd /work/output/rpms && sha256sum ./*.rpm > ../evidence/SHA256SUMS)
cp "$input/evidence/evidence.md" /work/output/evidence/original-source-build.md
sha512sum /work/downloads/*.tar.gz > /work/output/evidence/embedded-distribution-checksums.txt
printf 'source_build_run_id: %s\nsource_identity: ce919386e963841ea37f032c5ba6ed9c48298dd8\nstage: rpm-package\n' \
  "$SOURCE_BUILD_RUN_ID" > /work/output/evidence/package.md
