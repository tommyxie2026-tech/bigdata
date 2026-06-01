# TASK-202R Hadoop 3.5.0 RPM Adaptation Review

## 1. Metadata

```yaml
task: TASK-202R
name: Hadoop 3.5.0 RPM Adaptation Review
owner: Agent-B
sprint: Sprint-1
status: completed-initial-review
result: CONDITIONAL_GO
confidence: medium
```

## 2. Objective

在 RC1 已冻结为 `openEuler22 + RPM + DNF` 的前提下，重新评估 Hadoop 3.5.0 在 Bigtop 3.5.0 上的 RPM 适配路径。

本任务目标不是证明 Hadoop 3.5.0 已经构建成功，而是明确：

```text
Hadoop 3.5.0 要进入 RC1，Bigtop RPM 侧需要验证和适配哪些点。
```

## 3. RC1 Baseline

```yaml
rc1:
  os: openEuler22
  package:
    type: rpm
    manager: dnf
  runtime:
    jdk: JDK8
  bigtop: 3.5.0
  hadoop: 3.5.0
```

## 4. Current Evidence

### 4.1 Bigtop Has Hadoop RPM Spec

Bigtop contains Hadoop RPM spec at:

```text
bigtop-packages/src/rpm/hadoop/SPECS/hadoop.spec
```

The spec defines Hadoop as an RPM package and uses version macros:

```spec
Name: %{hadoop_pkg_name}
Version: %{hadoop_version}
Release: %{hadoop_release}
Source0: %{hadoop_name}-%{hadoop_base_version}.tar.gz
```

### 4.2 RPM Spec Contains HDFS/YARN Service Layout

The Hadoop RPM spec includes HDFS and YARN service definitions:

```spec
%define hdfs_services hdfs-namenode hdfs-secondarynamenode hdfs-datanode hdfs-zkfc hdfs-journalnode hdfs-dfsrouter
%define yarn_services yarn-resourcemanager yarn-nodemanager yarn-proxyserver yarn-timelineserver yarn-router
```

It also references systemd service files such as:

```text
hadoop-hdfs-namenode.service
hadoop-hdfs-datanode.service
hadoop-yarn-resourcemanager.service
hadoop-yarn-nodemanager.service
```

This aligns with RC1 requirements for HDFS/YARN validation and later HDFS HA / YARN HA verification.

### 4.3 Bigtop BOM Version Gap Remains

Current observed Bigtop BOM uses Hadoop 3.4.3, while RC1 requires Hadoop 3.5.0.

```yaml
observed_bom:
  hadoop: 3.4.3
required_rc1:
  hadoop: 3.5.0
```

This gap must be handled by Bigtop BOM adaptation, not by changing the RC1 target.

## 5. Required Adaptation Work

### 5.1 BOM Update

Update Hadoop version in Bigtop BOM from current observed value to:

```groovy
version { base = '3.5.0'; pkg = base; release = 1 }
```

Required validation:

- Source tarball name still matches Bigtop expectation.
- Download path resolves to Apache Hadoop 3.5.0 source distribution.
- SHA/signature verification can be archived.

### 5.2 RPM Spec Compatibility

Validate whether existing RPM spec works unchanged for Hadoop 3.5.0.

Validation scope:

- `%{hadoop_version}` expansion
- source tarball name
- install script compatibility
- service file compatibility
- file list changes
- native library output changes
- unpackaged file behavior

### 5.3 Patch Set Compatibility

Run patch application against Hadoop 3.5.0 source.

Each patch must be classified as:

```yaml
patch_status:
  - applies_cleanly
  - needs_refresh
  - obsolete
  - blocked
```

### 5.4 openEuler22 Dependency Compatibility

Existing RPM spec declares dependencies including:

```text
fuse-devel
fuse
systemd
coreutils
useradd/usermod
chkconfig
service
bigtop-utils
zookeeper
psmisc
netcat package
openssl-devel
```

openEuler22 validation must confirm package names and availability through DNF.

Potential risk points:

- `chkconfig` availability
- `/sbin/service` compatibility
- `nc` vs `netcat-openbsd` package naming
- `fuse` / `fuse-devel` naming
- OpenSSL version compatibility
- systemd unit install behavior

### 5.5 Build Command Validation

Target command should be normalized in the build lab.

Initial candidate:

```bash
BIGTOP_JDK=8 ./gradlew hadoop-rpm
```

If Bigtop uses a different target name for RPM packaging, update this command in the real build log.

### 5.6 Repository Validation

After RPM generation, M2 must validate:

```bash
dnf makecache
dnf search hadoop
dnf install hadoop hadoop-hdfs hadoop-yarn
```

The repository metadata should be generated with an RPM repository tool such as `createrepo` / `createrepo_c`, depending on openEuler22 availability.

## 6. Exit Criteria

TASK-202R can only move from CONDITIONAL_GO to PASS when all conditions are met:

```yaml
source_download: PASS
signature_or_checksum: PASS
bom_update: PASS
patch_apply: PASS
rpm_build: PASS
dnf_repo_metadata: PASS
rpm_install: PASS
hdfs_smoke_test: PASS
yarn_smoke_test: PASS
```

## 7. Risks

### R-HADOOP-RPM-001: RPM Spec Drift

```yaml
severity: High
risk: Hadoop 3.5.0 may change installed file layout, causing RPM file list or service packaging failures.
mitigation: Build once, collect unpackaged/missing file errors, then refresh spec.
```

### R-HADOOP-RPM-002: openEuler22 Dependency Drift

```yaml
severity: High
risk: RPM dependency names may differ from RHEL/CentOS assumptions.
mitigation: Create openEuler22 dependency preflight script.
```

### R-HADOOP-RPM-003: Patch Refresh Cost

```yaml
severity: Medium
risk: Existing Bigtop Hadoop patches may not apply cleanly to 3.5.0.
mitigation: Classify patch failures and remove obsolete patches where safe.
```

### R-HADOOP-RPM-004: Ambari Stack Version Gap

```yaml
severity: High
risk: Ambari BIGTOP stack repo sample references BIGTOP 3.2.0 while RC1 targets Bigtop 3.5.0.
mitigation: Maintain custom BIGTOP 3.5.0 repo definition for openEuler22.
```

## 8. Recommendation

```yaml
result: CONDITIONAL_GO
strategy: proceed_with_hadoop_3_5_0_rpm_adaptation
primary_path:
  os: openEuler22
  package: rpm
  manager: dnf
next_action:
  - create openEuler22 build lab
  - add dependency preflight script
  - update Bigtop BOM to Hadoop 3.5.0 in adaptation branch
  - run Hadoop RPM build
  - archive build logs under validation/bigtop/
```

## 9. Build Evidence Placeholder

Real build evidence must later be added under:

```text
validation/bigtop/hadoop-3.5.0-rpm-build-log.md
validation/bigtop/hadoop-3.5.0-rpm-package-list.txt
validation/bigtop/hadoop-3.5.0-dnf-install.md
```

## 10. Decision

Hadoop 3.5.0 remains the required RC1 target.

The RC1 Hadoop packaging path is now:

```yaml
hadoop: 3.5.0
os: openEuler22
package: rpm
manager: dnf
```

This task remains `CONDITIONAL_GO` until real RPM build and install evidence is produced.
