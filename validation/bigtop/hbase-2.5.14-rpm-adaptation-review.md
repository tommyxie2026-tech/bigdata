# TASK-206R HBase 2.5.14 RPM Adaptation Review

## 1. Metadata

```yaml
task: TASK-206R
name: HBase 2.5.14 RPM Adaptation Review
owner: Agent-B
sprint: Sprint-1
status: completed-initial-review
result: CONDITIONAL_GO
confidence: medium
```

## 2. Objective

在 RC1 已冻结为 `openEuler22 + RPM + DNF` 的前提下，评估 HBase 2.5.14 进入 BIGDATA-1.0 RC1 的 Bigtop RPM 适配路径。

HBase 是 RC1 目标组件之一，但其优先级低于 Hadoop/Hive/Spark/ZooKeeper 主线。该任务用于确认 HBase 是否具备继续进入 RC1 验证的包装基础与风险边界。

本任务不声明 HBase 2.5.14 已经构建成功，只明确适配点、风险和真实验证入口。

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
  hbase: 2.5.14
  hadoop: 3.5.0
  zookeeper: 3.9.5
```

## 4. Current Evidence

### 4.1 Bigtop Has HBase RPM Spec

Bigtop contains HBase RPM spec at:

```text
bigtop-packages/src/rpm/hbase/SPECS/hbase.spec
```

The spec defines HBase as an RPM package and uses version macros:

```spec
Name: %{hbase_pkg_name}
Version: %{hbase_version}
Release: %{hbase_release}
Source0: %{hbase_name}-%{hbase_base_version}.tar.gz
```

### 4.2 RPM Spec Contains RC1-Relevant HBase Subpackages

The HBase RPM spec contains service/subpackage definitions relevant to RC1:

- hbase-master
- hbase-regionserver
- hbase-thrift
- hbase-thrift2
- hbase-rest

For RC1, the minimum blocking capability is:

```text
HBase Master
HBase RegionServer
HBase shell put/get/scan
```

Thrift, Thrift2, and REST are useful but should not block RC1 unless explicitly required by integration tests.

### 4.3 RPM Spec Depends On Hadoop And ZooKeeper

The HBase RPM spec depends on:

```text
hadoop-client
zookeeper
bigtop-utils
```

This means HBase validation depends on successful Hadoop 3.5.0 and ZooKeeper 3.9.5 RPM adaptation.

### 4.4 Current Bigtop BOM Version Gap

Observed Bigtop BOM during Sprint-1 review differs from RC1 target.

Required RC1 version:

```yaml
required_rc1:
  hbase: 2.5.14
```

The exact Bigtop observed HBase version must be verified in the adaptation branch before real build.

## 5. Required Adaptation Work

### 5.1 BOM Update

Update HBase version in Bigtop BOM to:

```groovy
version { base = '2.5.14'; pkg = base; release = 1 }
```

Required validation:

- Source tarball name matches Bigtop expectation: `hbase-2.5.14.tar.gz`
- Download path resolves correctly
- Signature/checksum verification is archived

### 5.2 RPM Spec Compatibility

Validate whether existing HBase RPM spec works for HBase 2.5.14.

Validation scope:

- `%{hbase_version}` expansion
- source tarball naming
- install script compatibility
- service wrapper compatibility
- package file list changes
- HBase shell layout
- HBase master / regionserver package layout
- HBase thrift/rest package layout

### 5.3 Hadoop 3.5.0 Compatibility

HBase 2.5.14 must be validated against Hadoop 3.5.0.

Required checks:

- Hadoop client dependency
- HDFS root directory initialization
- HBase WAL / store files on HDFS
- HBase startup with Hadoop 3.5.0 client jars
- classpath conflicts

### 5.4 ZooKeeper 3.9.5 Compatibility

HBase 2.5.14 must be validated against ZooKeeper 3.9.5.

Required checks:

- HBase Master connects to ZooKeeper quorum
- RegionServer registers through ZooKeeper
- HBase shell table creation
- failover behavior if Master HA is later enabled

### 5.5 JDK8 Compatibility

HBase 2.5.14 under JDK8 must be proven by build and runtime smoke tests.

Initial candidate build command:

```bash
BIGTOP_JDK=8 ./gradlew hbase-rpm
```

The exact Bigtop task name must be confirmed in real build.

## 6. Exit Criteria

TASK-206R can only move from CONDITIONAL_GO to PASS when all conditions are met:

```yaml
source_download: PASS
signature_or_checksum: PASS
bom_update: PASS
patch_apply: PASS
rpm_build: PASS
dnf_repo_metadata: PASS
rpm_install: PASS
hbase_master_start: PASS
hbase_regionserver_start: PASS
hbase_shell_create_table: PASS
hbase_shell_put: PASS
hbase_shell_get: PASS
hbase_shell_scan: PASS
hdfs_dependency: PASS
zookeeper_dependency: PASS
```

## 7. Risks

### R-HBASE-RPM-001: HBase 2.5.14 Packaging Drift

```yaml
severity: High
risk: HBase 2.5.14 may have packaging layout differences compared with the version currently represented in Bigtop.
mitigation: Run RPM build and classify missing/unpackaged files.
```

### R-HBASE-RPM-002: Hadoop 3.5.0 Compatibility

```yaml
severity: High
risk: HBase 2.5.14 may require Hadoop client compatibility tuning with Hadoop 3.5.0.
mitigation: Validate HBase startup and read/write on HDFS after Hadoop RPM validation.
```

### R-HBASE-RPM-003: ZooKeeper 3.9.5 Compatibility

```yaml
severity: High
risk: HBase 2.5.14 may require ZooKeeper client/server compatibility validation against ZooKeeper 3.9.5.
mitigation: Validate HBase Master and RegionServer registration through ZooKeeper.
```

### R-HBASE-RPM-004: RC1 Critical Path Pressure

```yaml
severity: Medium
risk: HBase can consume significant validation time and may delay Hadoop/Hive/Spark RC1 path.
mitigation: Keep HBase as RC1 target, but do not allow HBase to block Hadoop/Hive/Spark core readiness unless explicitly promoted to RC1 blocker.
```

## 8. Recommendation

```yaml
result: CONDITIONAL_GO
strategy: proceed_with_hbase_2_5_14_rpm_adaptation
primary_path:
  os: openEuler22
  package: rpm
  manager: dnf
rc1_blocking_tests:
  - hbase_master_start
  - hbase_regionserver_start
  - hbase_shell_put_get_scan
non_blocking_for_rc1:
  - hbase_thrift
  - hbase_thrift2
  - hbase_rest
critical_path_dependency:
  - hadoop_3_5_0_rpm_validation
  - zookeeper_3_9_5_rpm_validation
next_action:
  - update Bigtop BOM to HBase 2.5.14 in adaptation branch
  - verify source download and checksum
  - run HBase RPM build under JDK8
  - install HBase RPMs from DNF repository
  - validate Master/RegionServer startup
  - validate put/get/scan
```

## 9. Build Evidence Placeholder

Real build evidence must later be added under:

```text
validation/bigtop/hbase-2.5.14-rpm-build-log.md
validation/bigtop/hbase-2.5.14-rpm-package-list.txt
validation/bigtop/hbase-2.5.14-dnf-install.md
validation/hbase/master.md
validation/hbase/regionserver.md
validation/hbase/put-get-scan.md
```

## 10. Decision

HBase 2.5.14 remains the RC1 NoSQL target, but should be managed as a conditional RC1 path behind Hadoop and ZooKeeper validation.

The RC1 HBase packaging path is:

```yaml
hbase: 2.5.14
os: openEuler22
package: rpm
manager: dnf
runtime: JDK8
```

This task remains `CONDITIONAL_GO` until real RPM build, install, Master/RegionServer startup, HBase shell put/get/scan, HDFS dependency, and ZooKeeper dependency evidence is produced.
