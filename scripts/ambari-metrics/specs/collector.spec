# Repackage validated upstream binaries; no native compilation or debug sources.
%global debug_package %{nil}

Name: ambari-metrics-collector
Version: 3.0.0
Release: 1.oe2203sp4
Summary: Apache Ambari Metrics Collector with embedded HBase and Phoenix
License: Apache-2.0
URL: https://github.com/apache/ambari-metrics
Source0: collector.tar.gz
BuildArch: x86_64
Requires: java-1.8.0-openjdk-headless, bash, procps-ng, systemd, python3
Requires(pre): shadow-utils
AutoReqProv: no

%description
Real Apache Ambari Metrics timeline Collector, immutable upstream source,
with HBase 2.4.13 and Phoenix 5.1.2 for durable embedded metric storage.

%prep
%setup -q -n collector

%build

%install
mkdir -p %{buildroot}
cp -a . %{buildroot}/

%pre
getent group ams >/dev/null || groupadd --system ams
getent passwd ams >/dev/null || useradd --system --gid ams --home-dir /var/lib/ambari-metrics-collector --shell /sbin/nologin ams

%post
if [ -d /run/systemd/system ]; then systemctl daemon-reload; fi

%preun
if [ "$1" -eq 0 ] && [ -d /run/systemd/system ]; then
  systemctl disable --now ambari-metrics-collector.service ambari-metrics-hbase.service >/dev/null 2>&1 || :
fi

%postun
if [ -d /run/systemd/system ]; then systemctl daemon-reload; fi

%files
%license /usr/share/licenses/ambari-metrics-collector
/usr/lib/ambari-metrics-collector
/usr/lib/ams-hbase
/usr/libexec/ambari-metrics
/usr/lib/systemd/system/ambari-metrics-collector.service
/usr/lib/systemd/system/ambari-metrics-hbase.service
%config(noreplace) /etc/ambari-metrics-collector/conf/*
%config(noreplace) /etc/ams-hbase/conf/*
%attr(0755,ams,ams) %dir /var/lib/ambari-metrics-collector
%attr(0755,ams,ams) %dir /var/log/ambari-metrics-collector
%attr(0755,ams,ams) %dir /var/run/ambari-metrics-collector
%attr(0755,ams,ams) %dir /var/log/ams-hbase
%attr(0755,ams,ams) %dir /var/run/ams-hbase
