# TASK-204R Spark 3.5.8 RPM Adaptation Review

## 1. Metadata

```yaml
task: TASK-204R
name: Spark 3.5.8 RPM Adaptation Review
owner: Agent-B
sprint: Sprint-1
status: completed-initial-review
result: CONDITIONAL_GO
confidence: medium
```

## 2. Objective

在 RC1 已冻结为 `openEuler22 + RPM + DNF` 的前提下，评估 Spark 3.5.8 进入 BIGDATA-1.0 RC1 的 Bigtop RPM 适配路径。

本任务不声明 Spark 3.5.8 已经构建成功，只明确适配点、风险和真实验证入口。

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
  hive: 4.2.0
  hive_metastore: 4.2.0
  spark: 3.5.8
```

## 4. Current Evidence

### 4.1 Bigtop Has Spark RPM Spec

Bigtop contains Spark RPM spec at:

```text
bigtop-packages/src/rpm/spark/SPECS/spark.spec
```

The spec defines Spark as an RPM package and uses version macros:

```spec
Name: %{spark_pkg_name}
Version: %{spark_version}
Release: %{spark_release}
Source0: %{spark_name}-%{spark_base_version}.tar.gz
```

### 4.2 RPM Spec Contains RC1-Relevant Spark Subpackages

The Spark RPM spec contains multiple RC1-relevant subpackages and services:

- spark-core
- spark-master
- spark-worker
- spark-python
- spark-history-server
- spark-thriftserver
- spark-datanucleus
- spark-yarn-shuffle
- spark-sparkr

For RC1, the minimum required capability is:

```text
spark-submit
Spark on YARN
Spark SQL
Hive Metastore access
Spark History Server
```

### 4.3 openEuler Conditional Logic Exists

The Spark RPM spec includes an `openEuler` conditional around SparkR dependency handling.

This is a positive signal that openEuler-specific RPM adaptation has already been considered in the upstream packaging.

### 4.4 Current Bigtop BOM Version Gap

Observed Bigtop BOM during Sprint-1 review:

```yaml
observed_bom:
  spark: 3.5.6
```

Required RC1 version:

```yaml
required_rc1:
  spark: 3.5.8
```

The version gap is small, but still requires build validation.

## 5. Required Adaptation Work

### 5.1 BOM Update

Update Spark version in Bigtop BOM from current observed value to:

```groovy
version { base = '3.5.8'; pkg = base; release = 1 }
```

Required validation:

- Source tarball name matches Bigtop expectation: `spark-3.5.8.tgz`
- Download path resolves correctly
- Signature/checksum verification is archived

### 5.2 RPM Spec Compatibility

Validate whether existing Spark RPM spec works for Spark 3.5.8.

Validation scope:

- `%{spark_version}` expansion
- source tarball naming
- install script compatibility
- service wrapper compatibility
- package file list changes
- Spark thriftserver layout
- Spark history server layout
- Spark yarn-shuffle package layout
- Spark datanucleus library layout

### 5.3 Hadoop 3.5.0 Compatibility

Spark 3.5.8 must be validated against Hadoop 3.5.0.

Required checks:

- Hadoop client RPM dependency
- Spark on YARN application submission
- shuffle service compatibility
- HDFS read/write from Spark
- classpath isolation

### 5.4 Hive Metastore 4.2.0 Compatibility

Spark SQL must access Hive Metastore 4.2.0.

Required checks:

- Spark SQL `enableHiveSupport`
- Metastore Thrift access
- table discovery
- create table / insert / select interoperability with Hive
- dependency conflicts between Spark bundled Hive client and Hive 4.2.0 metastore

### 5.5 JDK8 Compatibility

Spark 3.5.8 under JDK8 must be proven by build and runtime smoke tests.

Initial candidate build command:

```bash
BIGTOP_JDK=8 ./gradlew spark-rpm
```

The exact Bigtop task name must be confirmed in real build.

## 6. Exit Criteria

TASK-204R can only move from CONDITIONAL_GO to PASS when all conditions are met:

```yaml
source_download: PASS
signature_or_checksum: PASS
bom_update: PASS
patch_apply: PASS
rpm_build: PASS
dnf_repo_metadata: PASS
rpm_install: PASS
spark_submit_local: PASS
spark_on_yarn: PASS
spark_sql: PASS
spark_history_server: PASS
spark_hive_metastore_access: PASS
```

## 7. Risks

### R-SPARK-RPM-001: Spark 3.5.8 Packaging Drift

```yaml
severity: Medium
risk: Spark 3.5.8 may change artifact layout or dependencies compared with Bigtop observed Spark 3.5.6.
mitigation: Run RPM build and classify file layout changes.
```

### R-SPARK-RPM-002: Spark SQL Metastore Compatibility

```yaml
severity: Critical
risk: Spark SQL may not work cleanly with Hive Metastore 4.2.0 because of Hive client dependency and classpath conflicts.
mitigation: Add explicit Spark SQL Metastore smoke test as RC1 blocking test.
```

### R-SPARK-RPM-003: Hadoop 3.5.0 Compatibility

```yaml
severity: High
risk: Spark on YARN and Hadoop client dependencies must align with Hadoop 3.5.0 RPMs.
mitigation: Run Spark on YARN after Hadoop RPM install validation.
```

### R-SPARK-RPM-004: openEuler Runtime Dependency Differences

```yaml
severity: Medium
risk: init scripts, service wrappers, R/SparkR, Python and system package dependencies may differ on openEuler22.
mitigation: Keep SparkR non-blocking for RC1 and validate Spark core/Spark SQL first.
```

## 8. Recommendation

```yaml
result: CONDITIONAL_GO
strategy: proceed_with_spark_3_5_8_rpm_adaptation
primary_path:
  os: openEuler22
  package: rpm
  manager: dnf
rc1_blocking_tests:
  - spark_submit_local
  - spark_on_yarn
  - spark_sql
  - spark_hive_metastore_access
non_blocking_for_rc1:
  - spark_r
  - external_streaming_libraries
next_action:
  - update Bigtop BOM to Spark 3.5.8 in adaptation branch
  - verify Spark 3.5.8 source download and checksum
  - run Spark RPM build under JDK8
  - install Spark RPMs from DNF repository
  - validate Spark on YARN
  - validate Spark SQL access to Hive Metastore 4.2.0
```

## 9. Build Evidence Placeholder

Real build evidence must later be added under:

```text
validation/bigtop/spark-3.5.8-rpm-build-log.md
validation/bigtop/spark-3.5.8-rpm-package-list.txt
validation/bigtop/spark-3.5.8-dnf-install.md
validation/spark/spark-submit.md
validation/spark/spark-sql.md
validation/spark/hive-metastore.md
```

## 10. Decision

Spark 3.5.8 remains the required RC1 Batch Compute target.

The RC1 Spark packaging path is:

```yaml
spark: 3.5.8
os: openEuler22
package: rpm
manager: dnf
runtime: JDK8
```

This task remains `CONDITIONAL_GO` until real RPM build, install, Spark submit, Spark on YARN, Spark SQL, and Hive Metastore access evidence is produced.
