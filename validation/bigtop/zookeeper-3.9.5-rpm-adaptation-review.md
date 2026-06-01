# TASK-205R ZooKeeper 3.9.5 RPM Adaptation Review

## 1. Metadata

```yaml
task: TASK-205R
name: ZooKeeper 3.9.5 RPM Adaptation Review
owner: Agent-B
sprint: Sprint-1
status: completed-initial-review
result: CONDITIONAL_GO
confidence: medium
```

## 2. Objective

在 RC1 已冻结为 `openEuler22 + RPM + DNF` 的前提下，评估 ZooKeeper 3.9.5 进入 BIGDATA-1.0 RC1 的 Bigtop RPM 适配路径。

ZooKeeper 是 HDFS HA、YARN HA、HBase、Ambari 管理路径的重要基础依赖，因此该任务属于 RC1 前置风险验证。

本任务不声明 ZooKeeper 3.9.5 已经构建成功，只明确适配点、风险和真实验证入口。

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
  zookeeper: 3.9.5
  hadoop: 3.5.0
  hbase: 2.5.14
```

## 4. Current Evidence

### 4.1 Bigtop Has ZooKeeper RPM Spec

Bigtop contains ZooKeeper RPM spec at:

```text
bigtop-packages/src/rpm/zookeeper/SPECS/zookeeper.spec
```

The spec defines ZooKeeper as an RPM package and uses version macros:

```spec
Name: %{zookeeper_pkg_name}
Version: %{zookeeper_version}
Release: %{zookeeper_release}
Source0: apache-%{zookeeper_name}-%{zookeeper_base_version}.tar.gz
```

### 4.2 RPM Spec Contains Server, REST, Native Packages

The ZooKeeper RPM spec contains multiple subpackages:

- zookeeper-server
- zookeeper-rest
- zookeeper-native

For RC1, the blocking package is:

```text
zookeeper-server
```

The REST and native packages are useful but should not block RC1 unless required by downstream components.

### 4.3 RPM Spec Contains openEuler Conditional Logic

The spec contains an openEuler-specific condition around `systemd-rpm-macros`:

```spec
%if 0%{?openEuler} == 0
BuildRequires: systemd-rpm-macros
%endif
```

This is a strong positive signal that openEuler-specific RPM behavior has already been considered in upstream packaging.

### 4.4 RPM Spec Uses systemd Service And tmpfiles

The ZooKeeper RPM spec installs:

- ZooKeeper server systemd service file
- ZooKeeper tmpfiles configuration
- ZooKeeper runtime directory
- ZooKeeper log directory

This aligns with RC1 service management needs.

### 4.5 Current Bigtop BOM Version Gap

Observed Bigtop BOM during Sprint-1 review likely differs from RC1 target.

Required RC1 version:

```yaml
required_rc1:
  zookeeper: 3.9.5
```

The actual Bigtop BOM version must be verified in the adaptation branch before real build.

## 5. Required Adaptation Work

### 5.1 BOM Update

Update ZooKeeper version in Bigtop BOM to:

```groovy
version { base = '3.9.5'; pkg = base; release = 1 }
```

Required validation:

- Source tarball name matches Bigtop expectation: `apache-zookeeper-3.9.5.tar.gz`
- Download path resolves correctly
- Signature/checksum verification is archived

### 5.2 RPM Spec Compatibility

Validate whether existing ZooKeeper RPM spec works for ZooKeeper 3.9.5.

Validation scope:

- `%{zookeeper_version}` expansion
- source tarball naming
- install script compatibility
- systemd service install path
- tmpfiles behavior
- server package layout
- native package build behavior

### 5.3 openEuler22 Dependency Compatibility

Existing RPM spec references dependencies and tools including:

- autoconf
- automake
- cppunit-devel
- systemd
- coreutils
- groupadd/useradd
- alternatives/chkconfig/initscripts behavior
- bigtop-utils

openEuler22 validation must confirm package names and DNF availability.

Potential risk points:

- `chkconfig` and `initscripts` compatibility
- `alternatives` command behavior
- `cppunit-devel` availability
- systemd service unit behavior
- tmpfiles creation behavior

### 5.4 HDFS HA / YARN HA Compatibility

ZooKeeper 3.9.5 must support RC1 HA scenarios:

- HDFS ZKFC coordination
- NameNode HA failover
- YARN ResourceManager HA failover

Validation must include:

```text
zkServer status
zkCli connection
HDFS HA bootstrap
ZKFC failover
YARN RM failover
```

### 5.5 HBase Compatibility

HBase 2.5.14 will depend on ZooKeeper.

HBase is still part of the RC1 target list, but if schedule pressure appears, HBase may be treated as a conditionally validated feature. ZooKeeper must still be stable because it is also required by Hadoop HA.

## 6. Exit Criteria

TASK-205R can only move from CONDITIONAL_GO to PASS when all conditions are met:

```yaml
source_download: PASS
signature_or_checksum: PASS
bom_update: PASS
patch_apply: PASS
rpm_build: PASS
dnf_repo_metadata: PASS
rpm_install: PASS
zookeeper_server_start: PASS
zkcli_connection: PASS
hdfs_ha_dependency: PASS
yarn_ha_dependency: PASS
```

## 7. Risks

### R-ZK-RPM-001: Version Gap To ZooKeeper 3.9.5

```yaml
severity: High
risk: Bigtop current packaging may not have been validated against ZooKeeper 3.9.5.
mitigation: Update BOM and run real RPM build.
```

### R-ZK-RPM-002: openEuler Dependency Drift

```yaml
severity: Medium
risk: chkconfig/initscripts/alternatives dependencies may differ on openEuler22.
mitigation: Add openEuler22 dependency preflight and adjust spec if needed.
```

### R-ZK-RPM-003: HA Runtime Risk

```yaml
severity: Critical
risk: ZooKeeper may build and install successfully but still fail HDFS/YARN HA runtime validation.
mitigation: Treat HDFS HA and YARN HA dependency checks as blocking RC1 tests.
```

### R-ZK-RPM-004: Native Package Build Risk

```yaml
severity: Low
risk: Native package may require additional C/C++ build dependencies.
mitigation: Do not block RC1 on zookeeper-native unless required by runtime tests.
```

## 8. Recommendation

```yaml
result: CONDITIONAL_GO
strategy: proceed_with_zookeeper_3_9_5_rpm_adaptation
primary_path:
  os: openEuler22
  package: rpm
  manager: dnf
rc1_blocking_tests:
  - zookeeper_server_start
  - zkcli_connection
  - hdfs_ha_dependency
  - yarn_ha_dependency
non_blocking_for_rc1:
  - zookeeper_rest
  - zookeeper_native
next_action:
  - update Bigtop BOM to ZooKeeper 3.9.5 in adaptation branch
  - verify source download and checksum
  - run ZooKeeper RPM build under JDK8
  - install ZooKeeper RPMs from DNF repository
  - validate ZooKeeper quorum startup
  - validate HDFS HA and YARN HA dependency path
```

## 9. Build Evidence Placeholder

Real build evidence must later be added under:

```text
validation/bigtop/zookeeper-3.9.5-rpm-build-log.md
validation/bigtop/zookeeper-3.9.5-rpm-package-list.txt
validation/bigtop/zookeeper-3.9.5-dnf-install.md
validation/ha/zookeeper-quorum.md
validation/ha/hdfs-ha.md
validation/ha/yarn-ha.md
```

## 10. Decision

ZooKeeper 3.9.5 remains the required RC1 coordination service target.

The RC1 ZooKeeper packaging path is:

```yaml
zookeeper: 3.9.5
os: openEuler22
package: rpm
manager: dnf
runtime: JDK8
```

This task remains `CONDITIONAL_GO` until real RPM build, install, quorum startup, zkCli connection, HDFS HA dependency, and YARN HA dependency evidence is produced.
