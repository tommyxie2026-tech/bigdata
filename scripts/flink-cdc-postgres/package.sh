#!/usr/bin/env bash
set -euo pipefail
: "${BUILD_RUN_ID:?}"
: "${SOURCE_RUN_ID:?}"
: "${BUILD_INPUT_IDENTITY:?}"
source_sha=06581fc73b84b1da45fccf93441d96a118d9bfc1
mkdir -p /work/output/rpms /work/output/evidence
grep -qx "source_identity: $source_sha" /source/evidence.md
grep -qx 'compilation: PASS' /source/evidence.md
(cd /source && sha256sum -c SHA256SUMS)
dnf -y --disablerepo='*' --enablerepo=OS,everything install rpm-build curl
top=/work/rpmbuild
mkdir -p "$top"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
cp /source/flink-sql-connector-postgres-cdc-3.4.0.jar "$top/SOURCES/"
for license in LICENSE NOTICE; do
  curl --fail --location --connect-timeout 10 --max-time 60 \
    "https://raw.githubusercontent.com/apache/flink-cdc/$source_sha/$license" \
    -o "$top/SOURCES/$license"
done
cat > "$top/SPECS/cdc.spec" <<'SPEC'
Name: bigdata-flink-cdc-postgres
Version: 3.4.0
Release: 1.oe2203sp4
Summary: Apache Flink CDC PostgreSQL SQL source for Flink 1.20
License: Apache-2.0
URL: https://github.com/apache/flink-cdc
BuildArch: noarch
Requires: flink = 1.20.1
Requires: java-11-openjdk
%description
Apache PostgreSQL CDC connector compiled from the pinned upstream source release.
The upstream PostgreSQL JDBC driver is included in the shaded connector.
%prep
%build
%install
mkdir -p %{buildroot}/usr/lib/flink/lib %{buildroot}%{_licensedir}/bigdata-flink-cdc-postgres
install -m 0644 %{_sourcedir}/*.jar %{buildroot}/usr/lib/flink/lib/
install -m 0644 %{_sourcedir}/LICENSE %{_sourcedir}/NOTICE %{buildroot}%{_licensedir}/bigdata-flink-cdc-postgres/
%files
%license %{_licensedir}/bigdata-flink-cdc-postgres/LICENSE
%license %{_licensedir}/bigdata-flink-cdc-postgres/NOTICE
/usr/lib/flink/lib/flink-sql-connector-postgres-cdc-3.4.0.jar
SPEC
rpmbuild --define "_topdir $top" -bb "$top/SPECS/cdc.spec"
cp "$top"/RPMS/noarch/*.rpm /work/output/rpms/
rpm -qpl /work/output/rpms/*.rpm > /work/output/evidence/payload.txt
(cd /work/output && sha256sum rpms/*.rpm > evidence/SHA256SUMS)
cat > /work/output/evidence/evidence.md <<EOF
stage: build
component: flink-cdc-postgres
version: 3.4.0
source_identity: $source_sha
source_run_id: $SOURCE_RUN_ID
build_run_id: $BUILD_RUN_ID
artifact_type: integration-rpm
jdk: 11
postgres_jdbc_driver_bundled: true
build_input_identity: $BUILD_INPUT_IDENTITY
status: PASS
EOF
