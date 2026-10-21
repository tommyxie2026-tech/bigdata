#!/usr/bin/env bash
set -euo pipefail
# Repackage one pinned upstream binary. Never compile Hadoop or the AWS SDK.
dnf -y --setopt=timeout=20 --setopt=retries=2 install rpm-build curl python3 unzip
root=/work/rpmbuild
mkdir -p "$root"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS} /work/output/{rpms,evidence}
python3 - <<'PY' > /work/sdk.env
import json,shlex
c=json.load(open('/workspace/scripts/s3a/sdk-contract.json'))
for k in ['version','rpm_release','url','sha256','size']:print('SDK_'+k.upper()+'='+shlex.quote(str(c[k])))
PY
source /work/sdk.env
jar="$root/SOURCES/bundle-$SDK_VERSION.jar"
curl --fail --location --connect-timeout 10 --max-time 300 --retry 2 \
  --max-filesize "$SDK_SIZE" "$SDK_URL" -o "$jar"
printf '%s  %s\n' "$SDK_SHA256" "$jar" | sha256sum -c -
[[ "$(stat -c %s "$jar")" == "$SDK_SIZE" ]]
unzip -Z1 "$jar" | grep -Fx 'software/amazon/awssdk/auth/credentials/AwsCredentialsProvider.class' > /dev/null
# Preserve all upstream license/notice material already shipped inside the JAR.
python3 - <<'PY'
import pathlib,zipfile,json
c=json.load(open('/workspace/scripts/s3a/sdk-contract.json'))
p=pathlib.Path('/work/rpmbuild/SOURCES');z=zipfile.ZipFile(p/('bundle-'+c['version']+'.jar'))
licenses=[n for n in z.namelist() if n.upper().startswith('META-INF/') and any(w in n.upper() for w in ['LICENSE','NOTICE']) and not n.endswith('/')]
assert licenses,'Upstream license material missing'
(p/'UPSTREAM-LICENSES.txt').write_text('\n\n'.join('=== '+n+' ===\n'+z.read(n).decode('utf-8',errors='replace') for n in licenses))
PY
cat > "$root/SPECS/sdk.spec" <<'SPEC'
Name: bigdata-hadoop-aws-sdk
Version: 2.35.4
Release: 1.oe2203sp4
Summary: Optional AWS SDK v2 binary dependency for Hadoop 3.4.3 S3A
License: Apache-2.0
URL: https://github.com/aws/aws-sdk-java-v2
BuildArch: noarch
AutoReqProv: no
Requires: hadoop = 3.4.3
Requires: java-1.8.0-openjdk
%description
Pinned upstream AWS SDK v2 bundle required by the published Hadoop S3A module.
This optional dependency does not replace any Hadoop RPM or recompile Java sources.
%prep
%build
%install
mkdir -p %{buildroot}/usr/lib/hadoop/tools/lib %{buildroot}%{_licensedir}/bigdata-hadoop-aws-sdk
install -m 0644 %{_sourcedir}/bundle-2.35.4.jar %{buildroot}/usr/lib/hadoop/tools/lib/
install -m 0644 %{_sourcedir}/UPSTREAM-LICENSES.txt %{buildroot}%{_licensedir}/bigdata-hadoop-aws-sdk/
%files
%license %{_licensedir}/bigdata-hadoop-aws-sdk/UPSTREAM-LICENSES.txt
/usr/lib/hadoop/tools/lib/bundle-2.35.4.jar
SPEC
rpmbuild --define "_topdir $root" --define '_binary_payload w1.zstdio' -bb "$root/SPECS/sdk.spec"
cp "$root"/RPMS/noarch/*.rpm /work/output/rpms/
rpm -qpl /work/output/rpms/*.rpm > /work/output/evidence/payload.txt
cp /workspace/scripts/s3a/sdk-contract.json /work/output/evidence/
(cd /work/output && sha256sum rpms/*.rpm > evidence/SHA256SUMS)
(cd /workspace && sha256sum scripts/s3a/package-sdk.sh scripts/s3a/sdk-contract.json) > /work/output/evidence/package-inputs.sha256
cat > /work/output/evidence/evidence.md <<EOF
component: hadoop-aws-sdk
version: $SDK_VERSION
upstream_sha256: $SDK_SHA256
upstream_size: $SDK_SIZE
hadoop_recompiled: false
sdk_recompiled: false
build_run_id: ${GITHUB_RUN_ID:?}
status: PASS
EOF
