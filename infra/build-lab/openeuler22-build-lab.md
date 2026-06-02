# M2-Prep openEuler22 Build Lab

## 1. Metadata

```yaml
task: TASK-301
name: Create openEuler22 Build Lab
phase: M2-Prep
status: draft-ready
owner: Agent-C
```

## 2. Objective

建立 BIGDATA-1.0 RC1 的标准构建实验环境，用于真实验证：

```yaml
os: openEuler22
package: rpm
manager: dnf
runtime: JDK8
bigtop: 3.5.0
```

该环境是 M2 Packaging Ready 的前置条件。

## 3. Scope

Build Lab 只负责构建和仓库验证，不负责完整集群运行。

包含：

- Bigtop 源码拉取
- RC1 BOM 适配
- 组件源码下载
- RPM 构建
- RPM 包归档
- DNF Repository 生成
- DNF 安装验证
- 构建日志归档

不包含：

- Ambari 集群部署
- HDFS/YARN/Hive/Spark 全量运行验证
- HA 故障切换
- 性能测试

## 4. Required Build Host

建议最低配置：

```yaml
cpu: 16 cores
memory: 64 GB
disk: 500 GB SSD
os: openEuler 22.x
network: internet access or internal mirror access
```

如使用虚拟机，建议开启：

```yaml
nested_virtualization: optional
selinux: permissive_or_disabled_for_initial_build
firewalld: disabled_for_initial_build
```

## 5. Required Base Packages

初始依赖预检：

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
  python3-pip
```

Issue #20 还要求确认以下兼容工具：

```bash
dnf install -y \
  systemd \
  chkconfig \
  initscripts
```

实际依赖以 Bigtop toolchain 运行结果为准。

## 6. Directory Layout

建议构建主机目录：

```text
/opt/bigdata-rc1/
├── src/
│   └── bigtop/
├── patches/
├── build/
├── rpms/
├── repo/
├── logs/
└── evidence/
```

对应仓库证据目录：

```text
validation/bigtop/
packaging/rpm/
packaging/repo/
```

## 7. Environment Variables

```bash
export BIGDATA_RC1_HOME=/opt/bigdata-rc1
export BIGTOP_JDK=8
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
export PATH=$JAVA_HOME/bin:$PATH
```

## 8. Initial Build Workflow

### Step 0: Prepare Workspace And Run Preflight

```bash
export BIGDATA_RC1_HOME=/opt/bigdata-rc1
export BIGTOP_JDK=8
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
export PATH=$JAVA_HOME/bin:$PATH

infra/build-lab/openeuler22-build-lab-preflight.sh \
  validation/bigtop/openeuler22-toolchain-preflight.md
```

The preflight script creates the standard workspace layout and records OS, kernel, DNF/RPM, JDK8, build tools, repository tools, service compatibility, and network or mirror access evidence.

If any package name differs on the selected openEuler22 minor release, record the mapping in:

```text
validation/bigtop/openeuler22-package-name-mapping.md
```

Record the package installation command output in:

```text
validation/bigtop/openeuler22-toolchain-install-log.md
```

### Step 1: Clone Bigtop

```bash
mkdir -p /opt/bigdata-rc1/src
cd /opt/bigdata-rc1/src
git clone https://github.com/apache/bigtop.git
cd bigtop
```

### Step 2: Create RC1 Adaptation Branch

```bash
git checkout -b bigdata-1.0-rc1-openeuler22-rpm
```

### Step 3: Apply RC1 BOM Patch

Target versions:

```yaml
hadoop: 3.5.0
zookeeper: 3.9.5
hive: 4.2.0
tez: 0.10.5
spark: 3.5.8
hbase: 2.5.14
```

### Step 4: Run Component Build

Initial priority:

```text
1. ZooKeeper 3.9.5
2. Hadoop 3.5.0
3. Hive 4.2.0
4. Spark 3.5.8
5. HBase 2.5.14
```

Reason:

```text
ZooKeeper and Hadoop are prerequisites for HA and HBase.
```

### Step 5: Archive Logs

All build logs must be copied to:

```text
validation/bigtop/<component>-rpm-build-log.md
```

## 9. Evidence Required

For each component:

```yaml
source_download: PASS | FAIL
checksum_or_signature: PASS | FAIL
bom_update: PASS | FAIL
patch_apply: PASS | FAIL
rpm_build: PASS | FAIL
rpm_package_list: PASS | FAIL
```

For repository:

```yaml
createrepo: PASS | FAIL
dnf_makecache: PASS | FAIL
dnf_install: PASS | FAIL
```

## 10. Exit Criteria

TASK-301 is complete when:

```yaml
build_host_ready: PASS
os_identity_recorded: PASS
base_dependencies_installed: PASS
jdk8_runtime_available: PASS
jdk8_compiler_available: PASS
dnf_available: PASS
rpm_available: PASS
rpmbuild_available: PASS
createrepo_c_available: PASS
workspace_created: PASS
network_or_mirror_access_verified: PASS
```

The following items are intentionally outside Issue #20 and belong to downstream M2 issues:

```yaml
bigtop_source_cloned: downstream
rc1_adaptation_branch_created: downstream
first_component_build_started: downstream
component_rpm_built: downstream
rpm_repository_created: downstream
```

## 11. Risks

### R-LAB-001: openEuler Package Name Drift

```yaml
severity: High
risk: Some Bigtop build dependencies may use RHEL/CentOS names that differ on openEuler.
mitigation: Maintain dependency preflight log and patch package names only after evidence.
```

### R-LAB-002: JDK8 Availability

```yaml
severity: Medium
risk: JDK8 package naming may vary across openEuler minor versions.
mitigation: Record exact openEuler release and JDK package name.
```

### R-LAB-003: Build Time And Disk Usage

```yaml
severity: Medium
risk: Hadoop/Hive/Spark builds may consume large disk and time.
mitigation: Use dedicated SSD workspace and archive failed logs immediately.
```

## 12. Decision

M2-Prep starts with openEuler22 Build Lab.

No component should be marked PASS until real build and install evidence is archived.
