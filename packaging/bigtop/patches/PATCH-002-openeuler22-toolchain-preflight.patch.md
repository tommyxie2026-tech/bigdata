# PATCH-002 openEuler22 Toolchain Preflight Patch

## 1. Metadata

```yaml
patch: PATCH-002
name: openEuler22 Toolchain Preflight Patch
phase: M2-Prep
task: TASK-304
status: draft-ready
owner: Agent-C
component: build-toolchain
```

## 2. Objective

在正式构建 ZooKeeper/Hadoop/Hive/Spark/HBase RPM 之前，先建立 openEuler22 构建工具链预检流程。

目标是把构建失败明确分类为：

```yaml
failure_class:
  - environment_missing_dependency
  - package_name_mismatch
  - jdk_mismatch
  - rpm_toolchain_issue
  - component_source_issue
  - component_patch_issue
  - component_packaging_issue
```

PATCH-002 不修改组件版本，不修改组件 RPM spec，不修复具体组件构建失败。

## 3. Scope

PATCH-002 允许新增：

```text
bigdata-rc1-notes/toolchain/
bigdata-rc1-notes/toolchain/openeuler22-preflight.sh
bigdata-rc1-notes/toolchain/openeuler22-preflight-result.md
```

如需要，也可以在仓库外 Build Lab 中保存实际执行日志：

```text
validation/bigtop/openeuler22-toolchain-preflight.md
```

## 4. Required Toolchain Checks

### 4.1 OS Identity

```bash
cat /etc/os-release
uname -a
```

Required evidence:

```yaml
os_name:
os_version:
kernel:
architecture:
```

### 4.2 Package Manager

```bash
dnf --version
rpm --version
rpmbuild --version
```

Required evidence:

```yaml
dnf: PASS | FAIL
rpm: PASS | FAIL
rpmbuild: PASS | FAIL
```

### 4.3 JDK8

```bash
java -version
javac -version
echo $JAVA_HOME
```

Required evidence:

```yaml
jdk8_runtime: PASS | FAIL
jdk8_compiler: PASS | FAIL
java_home: PASS | FAIL
```

### 4.4 Build Tools

```bash
git --version
curl --version
wget --version
tar --version
unzip -v | head
zip -v | head
make --version
gcc --version
g++ --version || c++ --version
mvn -version
python3 --version
```

Required evidence:

```yaml
git: PASS | FAIL
curl: PASS | FAIL
wget: PASS | FAIL
tar: PASS | FAIL
unzip: PASS | FAIL
zip: PASS | FAIL
make: PASS | FAIL
gcc: PASS | FAIL
gxx_or_cxx: PASS | FAIL
maven: PASS | FAIL
python3: PASS | FAIL
```

### 4.5 Native Build Dependencies

```bash
autoconf --version
automake --version
libtool --version || true
patch --version
```

Required evidence:

```yaml
autoconf: PASS | FAIL
automake: PASS | FAIL
libtool: PASS | FAIL
patch: PASS | FAIL
```

### 4.6 RPM Repository Tooling

```bash
createrepo_c --version || createrepo --version
```

Required evidence:

```yaml
createrepo_or_createrepo_c: PASS | FAIL
```

### 4.7 Service Compatibility Tools

Bigtop RPM specs may reference tools such as:

```text
systemd
chkconfig
initscripts
alternatives
service
```

Preflight commands:

```bash
systemctl --version
command -v chkconfig || true
command -v service || true
command -v alternatives || true
rpm -q initscripts || true
rpm -q chkconfig || true
```

Required evidence:

```yaml
systemd: PASS | FAIL
chkconfig: PASS | FAIL | NOT_INSTALLED
service: PASS | FAIL | NOT_INSTALLED
alternatives: PASS | FAIL | NOT_INSTALLED
initscripts: PASS | FAIL | NOT_INSTALLED
```

## 5. Candidate Install Command

Initial candidate install command:

```bash
dnf install -y \
  git \
  curl \
  wget \
  tar \
  unzip \
  zip \
  which \
  make \
  gcc \
  gcc-c++ \
  autoconf \
  automake \
  libtool \
  patch \
  rpm-build \
  rpmdevtools \
  createrepo_c \
  java-1.8.0-openjdk-devel \
  maven \
  python3 \
  python3-pip \
  systemd \
  chkconfig \
  initscripts
```

If any package name differs on the selected openEuler22 minor release, record the actual package name in the preflight evidence.

## 6. Preflight Script Skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail

OUT=${1:-validation/bigtop/openeuler22-toolchain-preflight.md}
mkdir -p "$(dirname "$OUT")"

{
  echo "# openEuler22 Toolchain Preflight"
  echo
  echo "## OS"
  cat /etc/os-release || true
  uname -a || true

  echo
  echo "## Package Manager"
  dnf --version || true
  rpm --version || true
  rpmbuild --version || true

  echo
  echo "## JDK"
  java -version 2>&1 || true
  javac -version 2>&1 || true
  echo "JAVA_HOME=${JAVA_HOME:-}"

  echo
  echo "## Build Tools"
  git --version || true
  curl --version | head -1 || true
  wget --version | head -1 || true
  tar --version | head -1 || true
  unzip -v | head -1 || true
  zip -v | head -2 || true
  make --version | head -1 || true
  gcc --version | head -1 || true
  g++ --version | head -1 || c++ --version | head -1 || true
  mvn -version || true
  python3 --version || true

  echo
  echo "## Native Build Dependencies"
  autoconf --version | head -1 || true
  automake --version | head -1 || true
  libtool --version | head -1 || true
  patch --version | head -1 || true

  echo
  echo "## Repository Tools"
  createrepo_c --version || createrepo --version || true

  echo
  echo "## Service Compatibility"
  systemctl --version | head -1 || true
  command -v chkconfig || true
  command -v service || true
  command -v alternatives || true
  rpm -q initscripts || true
  rpm -q chkconfig || true
} | tee "$OUT"
```

## 7. Exit Criteria

PATCH-002 is complete when:

```yaml
preflight_script_created: PASS
preflight_script_executed: PASS
os_identity_recorded: PASS
dnf_rpm_rpmbuild_recorded: PASS
jdk8_recorded: PASS
build_tools_recorded: PASS
repository_tool_recorded: PASS
service_compatibility_recorded: PASS
missing_dependencies_classified: PASS
```

## 8. Evidence Required

Required evidence file:

```text
validation/bigtop/openeuler22-toolchain-preflight.md
```

Optional supporting files:

```text
validation/bigtop/openeuler22-toolchain-install-log.md
validation/bigtop/openeuler22-package-name-mapping.md
```

## 9. Failure Handling Rule

If a dependency is missing:

```yaml
allowed_response:
  - record missing dependency
  - identify openEuler package name
  - update install command
  - rerun preflight

forbidden_response:
  - start component build without preflight evidence
  - classify component build failure before environment is verified
  - skip missing dependency log
```

## 10. Risks

### R-PATCH-002-001: openEuler Package Name Drift

```yaml
severity: High
risk: Some package names may differ from CentOS/RHEL assumptions in Bigtop specs.
mitigation: Maintain package-name mapping evidence.
```

### R-PATCH-002-002: JDK8 Toolchain Drift

```yaml
severity: Medium
risk: JDK8 package may differ by openEuler22 minor release.
mitigation: Record exact JDK package and JAVA_HOME path.
```

### R-PATCH-002-003: Init Script Compatibility

```yaml
severity: Medium
risk: Bigtop specs reference legacy init tools while openEuler22 primarily uses systemd.
mitigation: Verify chkconfig/service/initscripts availability before build.
```

## 11. Decision

PATCH-002 is approved as the second engineering patch on the Bigtop RC1 adaptation branch.

No component RPM build should start until openEuler22 toolchain preflight evidence is archived.
