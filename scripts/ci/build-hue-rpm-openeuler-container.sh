#!/usr/bin/env bash
set -euo pipefail

: "${COMPONENT:?COMPONENT is required}"
: "${VERSION:?VERSION is required}"
: "${BUILD_RUN_ID:?BUILD_RUN_ID is required}"
: "${EXPECTED_SOURCE_IDENTITY:?EXPECTED_SOURCE_IDENTITY is required}"
: "${COMPONENT_RUNTIME_PACKAGES:?COMPONENT_RUNTIME_PACKAGES is required}"
WORK_ROOT="${WORK_ROOT:-/work}"
SOURCE_DIR="${WORK_ROOT}/hue-source"
ARTIFACTS="${WORK_ROOT}/artifacts"
RPM_TOP="${WORK_ROOT}/rpmbuild"
INSTALL_DIR=/usr/share/hue
RPM_NAME="bigdata-hue-server-${VERSION}-1.oe2203sp4.x86_64.rpm"
NODE_ARCHIVE=/tmp/node-v22.23.0-linux-x64.tar.xz
NODE_SHA256=14d7de44f235534799f8b171a4050d9a6a4bc99c87e053a25d3d54afa580aa20
mkdir -p "${ARTIFACTS}/rpms" "${ARTIFACTS}/logs" "${ARTIFACTS}/evidence"
[[ "${COMPONENT}" == hue && "${VERSION}" == 4.11.0 ]] || {
  echo "Only catalog-pinned Hue 4.11.0 is supported." >&2
  exit 2
}
[[ "${EXPECTED_SOURCE_IDENTITY}" == 65d9e489f400ac151029b33c5a2bd9df31e167da ]]
[[ "${COMPONENT_RUNTIME_PACKAGES}" == bigdata-hue-server ]]
[[ "$(uname -m)" == x86_64 ]]
grep -qi openEuler /etc/os-release

dnf -y install \
  ca-certificates curl gcc gcc-c++ git gmp-devel krb5-devel libffi-devel \
  libxml2-devel libxslt-devel make openldap-devel openssl-devel python3 \
  python3-devel python3-pip rsync sqlite-devel cyrus-sasl-devel tar xz rpm-build rpmdevtools \
  shadow-utils openEuler-rpm-config
python3 --version
python3 - <<'PY'
import sys
if sys.version_info[:2] != (3, 9):
    raise SystemExit(f"Hue build requires Python 3.9, found {sys.version.split()[0]}")
PY
python3 -m pip --version

curl --fail --location --retry 5 --retry-all-errors --retry-delay 2 --retry-max-time 300 --output "${NODE_ARCHIVE}" \
  https://nodejs.org/dist/v22.23.0/node-v22.23.0-linux-x64.tar.xz
printf '%s  %s\n' "${NODE_SHA256}" "${NODE_ARCHIVE}" | sha256sum --check
NODE_ROOT=/opt/node-v22.23.0
rm -rf "${NODE_ROOT}"
mkdir -p "${NODE_ROOT}"
tar -xJf "${NODE_ARCHIVE}" --strip-components=1 -C "${NODE_ROOT}"
export PATH="${NODE_ROOT}/bin:${PATH}"
[[ "$(node --version)" == v22.23.0 ]]
npm --version

rm -rf "${SOURCE_DIR}" "${INSTALL_DIR}" "${RPM_TOP}"
git init "${SOURCE_DIR}"
git -C "${SOURCE_DIR}" remote add origin https://github.com/cloudera/hue.git
git -C "${SOURCE_DIR}" fetch --quiet --depth=1 origin "${EXPECTED_SOURCE_IDENTITY}"
git -C "${SOURCE_DIR}" -c advice.detachedHead=false checkout --quiet --detach FETCH_HEAD
actual_source_identity="$(git -C "${SOURCE_DIR}" rev-parse HEAD)"
[[ "${actual_source_identity}" == "${EXPECTED_SOURCE_IDENTITY}" ]]
hue_source_version="$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' "${SOURCE_DIR}/VERSION" | head -n1)"
[[ "${hue_source_version}" == "${VERSION}" ]]
grep -Eq '^apps: desktop$' "${SOURCE_DIR}/Makefile"

# Bootstrap Hue's pinned build tooling in an isolated Python environment.
# The target image's RPM-owned pip has no RECORD file, so upgrading it directly
# from upstream's Makefile fails. A venv-local pip can be upgraded safely.
BOOTSTRAP_PYTHON="${WORK_ROOT}/bootstrap-python"
rm -rf "${BOOTSTRAP_PYTHON}"
python3 -m venv "${BOOTSTRAP_PYTHON}"
export PATH="${BOOTSTRAP_PYTHON}/bin:${PATH}"
SYS_PYTHON="${BOOTSTRAP_PYTHON}/bin/python3.9"
[[ "$(command -v python3.9)" == "${SYS_PYTHON}" ]]
"${SYS_PYTHON}" -m pip --version

# Follow the upstream container build contract: compile apps and install the
# relocatable runtime at its final path so virtualenv shebangs remain valid.
cd "${SOURCE_DIR}"
PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python \
  PREFIX=/usr/share INSTALL_DIR="${INSTALL_DIR}" PYTHON_VER=python3.9 \
  make apps install 2>&1 | tee "${ARTIFACTS}/logs/hue-build.log"

HUE_PYTHON="${INSTALL_DIR}/build/venvs/python3.9/bin/python"
HUE_BIN="${INSTALL_DIR}/build/venvs/python3.9/bin/hue"
[[ -x "${HUE_PYTHON}" && -x "${HUE_BIN}" ]]
"${HUE_PYTHON}" -m pip install --disable-pip-version-check 'trino==0.329.0'
"${HUE_PYTHON}" -m pip freeze | LC_ALL=C sort > "${ARTIFACTS}/evidence/python-requirements.freeze"
install -d -m 0755 /etc/hue /usr/lib/systemd/system /usr/libexec/hue /var/lib/hue /var/log/hue
install -m 0644 "${SOURCE_DIR}/desktop/conf.dist/hue.ini" /etc/hue/hue.ini
install -m 0644 "${SOURCE_DIR}/LICENSE.txt" "${WORK_ROOT}/hue-LICENSE.txt"
install -m 0644 "${SOURCE_DIR}/NOTICE.txt" "${WORK_ROOT}/hue-NOTICE.txt"
cat > /usr/libexec/hue/hue-server <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export HUE_CONF_DIR=/etc/hue
export HOME=/var/lib/hue
cd /usr/share/hue
exec /usr/share/hue/build/venvs/python3.9/bin/hue runcherrypyserver --server-name=0.0.0.0 --port=8888
EOF
chmod 0755 /usr/libexec/hue/hue-server
cat > /usr/lib/systemd/system/hue.service <<'EOF'
[Unit]
Description=Hue SQL Assistant
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=hue
Group=hue
Environment=HUE_CONF_DIR=/etc/hue
Environment=HOME=/var/lib/hue
WorkingDirectory=/usr/share/hue
ExecStart=/usr/libexec/hue/hue-server
Restart=on-failure
RestartSec=5
UMask=0027
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${RPM_TOP}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
tar -C / -czf "${RPM_TOP}/hue-runtime.tar.gz" usr/share/hue
install -m 0644 "${RPM_TOP}/hue-runtime.tar.gz" "${RPM_TOP}/SOURCES/hue-runtime.tar.gz"
install -m 0644 "${WORK_ROOT}/hue-LICENSE.txt" "${RPM_TOP}/SOURCES/LICENSE"
install -m 0644 "${WORK_ROOT}/hue-NOTICE.txt" "${RPM_TOP}/SOURCES/NOTICE"
install -m 0644 /etc/hue/hue.ini "${RPM_TOP}/SOURCES/hue.ini"
install -m 0755 /usr/libexec/hue/hue-server "${RPM_TOP}/SOURCES/hue-server"
install -m 0644 /usr/lib/systemd/system/hue.service "${RPM_TOP}/SOURCES/hue.service"
cat > "${RPM_TOP}/SPECS/bigdata-hue-server.spec" <<'EOF'
Name:           bigdata-hue-server
Version:        4.11.0
Release:        1.oe2203sp4
Summary:        Hue SQL Assistant service
License:        Apache-2.0
URL:            https://github.com/cloudera/hue
BuildArch:      x86_64
Requires:       python3
Requires:       systemd
Source0:        hue-runtime.tar.gz
Source1:        LICENSE
Source2:        NOTICE
Source3:        hue.ini
Source4:        hue-server
Source5:        hue.service

%description
Hue web service and SQL editor built from the pinned upstream source.

%prep

%build

%install
mkdir -p %{buildroot}/usr/share %{buildroot}/etc/hue %{buildroot}/usr/lib/systemd/system %{buildroot}/usr/libexec/hue %{buildroot}/var/lib/hue %{buildroot}/var/log/hue %{buildroot}%{_licensedir}/bigdata-hue
tar -xzf %{SOURCE0} -C %{buildroot}
install -m 0644 %{SOURCE3} %{buildroot}/etc/hue/hue.ini
install -m 0755 %{SOURCE4} %{buildroot}/usr/libexec/hue/hue-server
install -m 0644 %{SOURCE5} %{buildroot}/usr/lib/systemd/system/hue.service
install -m 0644 %{SOURCE1} %{buildroot}%{_licensedir}/bigdata-hue/LICENSE
install -m 0644 %{SOURCE2} %{buildroot}%{_licensedir}/bigdata-hue/NOTICE

%post
getent group hue >/dev/null || groupadd --system hue
getent passwd hue >/dev/null || useradd --system --gid hue --home-dir /var/lib/hue --shell /sbin/nologin hue
chown -R hue:hue /var/lib/hue /var/log/hue /etc/hue
/usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :
if [ "$1" -eq 1 ]; then
  /usr/bin/systemctl preset hue.service >/dev/null 2>&1 || :
fi

%preun
if [ "$1" -eq 0 ]; then
  /usr/bin/systemctl disable --now hue.service >/dev/null 2>&1 || :
fi

%postun
/usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :
if [ "$1" -ge 1 ]; then
  /usr/bin/systemctl try-restart hue.service >/dev/null 2>&1 || :
fi

%files
%license %{_licensedir}/bigdata-hue/LICENSE
%license %{_licensedir}/bigdata-hue/NOTICE
%dir /etc/hue
%config(noreplace) /etc/hue/hue.ini
%dir /usr/libexec/hue
/usr/libexec/hue/hue-server
/usr/lib/systemd/system/hue.service
%dir /var/lib/hue
%dir /var/log/hue
/usr/share/hue

%changelog
* Thu Oct 15 2026 BIGDATA CI <ci@example.invalid> - 4.11.0-1.oe2203sp4
- Build the pinned Hue service for openEuler 22.03 SP4
EOF
rpmbuild --define "_topdir ${RPM_TOP}" -bb "${RPM_TOP}/SPECS/bigdata-hue-server.spec"
mapfile -t rpms < <(find "${RPM_TOP}/RPMS" -type f -name '*.rpm' -print)
[[ "${#rpms[@]}" -eq 1 && "${rpms[0]##*/}" == "${RPM_NAME}" ]]
[[ "$(rpm -qp --queryformat '%{NAME}' "${rpms[0]}")" == bigdata-hue-server ]]
[[ "$(rpm -qp --queryformat '%{VERSION}' "${rpms[0]}")" == "${VERSION}" ]]
[[ "$(rpm -qp --queryformat '%{ARCH}' "${rpms[0]}")" == x86_64 ]]
rpm -qp --requires "${rpms[0]}" | grep -q '^python3$'
rpm -qp --requires "${rpms[0]}" | grep -q '^systemd$'
cp -v "${rpms[0]}" "${ARTIFACTS}/rpms/"
(cd "${ARTIFACTS}" && sha256sum rpms/*.rpm > evidence/SHA256SUMS)
printf '%s\n' bigdata-hue-server > "${ARTIFACTS}/evidence/package-list.txt"
cat > "${ARTIFACTS}/evidence/evidence.md" <<EOF
# CI Evidence — Hue Service RPM Build
schema: bigdata.evidence/v1
stage: build
component: ${COMPONENT}
version: ${VERSION}
artifact_type: service-rpm
test_profile: hue-single-node-smoke
source_identity: ${actual_source_identity}
compatibility_identity: ${COMPONENT_COMPATIBILITY_IDENTITY:-}
build_run_id: ${BUILD_RUN_ID}
runtime_packages: ${COMPONENT_RUNTIME_PACKAGES}
toolchain_python: 3.9
toolchain_node: 22.23.0
node_archive_sha256: ${NODE_SHA256}
trino_python_client: 0.329.0
rpm_count: 1
status: PASS
EOF
