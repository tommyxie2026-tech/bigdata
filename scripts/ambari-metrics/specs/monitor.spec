Name: ambari-metrics-monitor
Version: 3.0.0
Release: 1.oe2203sp4
Summary: Apache Ambari Metrics Python 3 host Monitor
License: Apache-2.0
URL: https://github.com/apache/ambari-metrics
Source0: monitor.tar.gz
BuildArch: noarch
Requires: python3, python3-psutil, systemd
Requires(pre): shadow-utils
AutoReqProv: no

%description
Actual Apache Ambari Metrics host agent, ported from pinned upstream source
to Python 3, collecting CPU, memory, disk, network and configured processes.

%prep
%setup -q -n monitor

%build

%install
mkdir -p %{buildroot}
cp -a . %{buildroot}/

%pre
getent group ams >/dev/null || groupadd --system ams
getent passwd ams >/dev/null || useradd --system --gid ams --home-dir /var/lib/ambari-metrics-monitor --shell /sbin/nologin ams

%post
python3 -c 'from pathlib import Path; import socket; p=Path("/etc/ambari-metrics-monitor/conf/metric_monitor.ini"); s=p.read_text(); p.write_text(s.replace("__INSTALL_HOSTNAME__",socket.getfqdn().lower())) if "__INSTALL_HOSTNAME__" in s else None'
if [ -d /run/systemd/system ]; then systemctl daemon-reload; fi

%preun
if [ "$1" -eq 0 ] && [ -d /run/systemd/system ]; then
  systemctl disable --now ambari-metrics-monitor.service >/dev/null 2>&1 || :
fi

%postun
if [ -d /run/systemd/system ]; then systemctl daemon-reload; fi

%files
%license /usr/share/licenses/ambari-metrics-monitor/LICENSE.txt
/usr/lib/ambari-metrics-monitor
/usr/lib/systemd/system/ambari-metrics-monitor.service
%config(noreplace) /etc/ambari-metrics-monitor/conf/*
%attr(0755,ams,ams) %dir /var/lib/ambari-metrics-monitor
%attr(0755,ams,ams) %dir /var/log/ambari-metrics-monitor
%attr(0755,ams,ams) %dir /var/run/ambari-metrics-monitor
