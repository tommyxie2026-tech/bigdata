# TASK-203R Hive 4.2.0 RPM Adaptation Review

## 1. Metadata

```yaml
task: TASK-203R
name: Hive 4.2.0 RPM Adaptation Review
owner: Agent-B
sprint: Sprint-1
status: completed-initial-review
result: CONDITIONAL_GO
confidence: medium
```

## 2. Objective

在 RC1 已冻结为 `openEuler22 + RPM + DNF` 的前提下，评估 Hive 4.2.0 与 Hive Standalone Metastore 4.2.0 进入 BIGDATA-1.0 RC1 的 Bigtop RPM 适配路径。

本任务不声明 Hive 4.2.0 已经构建成功，只明确适配点、风险和真实验证入口。

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
  hive_standalone_metastore: 4.2.0
  tez: 0.10.5
  spark: 3.5.8
```

## 4. Current Evidence

### 4.1 Bigtop Has Hive RPM Spec

Bigtop contains Hive RPM spec at:

```text
bigtop-packages/src/rpm/hive/SPECS/hive.spec
```

The spec defines Hive as an RPM package and uses version macros:

```spec
Name: %{hive_pkg_name}
Version: %{hive_version}
Release: %{hive_release}
Source0: apache-%{hive_name}-%{hive_base_version}-src.tar.gz
```

### 4.2 RPM Spec Already Splits Important Hive Subpackages

The Hive RPM spec defines multiple subpackages relevant to RC1:

- hive-server2
- hive-metastore
- hive-jdbc
- hive-hcatalog
- hive-webhcat
- hive-hbase

This is positive for RC1 because SQL Warehouse requires at least:

```text
Hive Metastore
HiveServer2
Hive JDBC / client access
```

### 4.3 Current Bigtop BOM Version Gap

Observed Bigtop BOM during Sprint-1 review:

```yaml
observed_bom:
  hive: 4.0.1
  tez: 0.10.5
```

Required RC1 versions:

```yaml
required_rc1:
  hive: 4.2.0
  hive_standalone_metastore: 4.2.0
  tez: 0.10.5
```

Tez is already aligned with the RC1 target, but Hive has a version gap.

## 5. Required Adaptation Work

### 5.1 BOM Update

Update Hive version in Bigtop BOM from current observed value to:

```groovy
version { base = '4.2.0'; pkg = base; release = 1 }
```

Required validation:

- Source tarball name matches Bigtop expectation: `apache-hive-4.2.0-src.tar.gz`
- Download path resolves correctly
- Signature/checksum verification is archived

### 5.2 RPM Spec Compatibility

Validate whether existing Hive RPM spec works for Hive 4.2.0.

Validation scope:

- `%{hive_version}` expansion
- `apache-hive-4.2.0-src.tar.gz` source naming
- install script compatibility
- service wrapper compatibility
- package file list changes
- metastore/server2 split behavior
- JDBC artifact layout changes

### 5.3 Standalone Metastore Packaging Decision

RC1 explicitly requires:

```yaml
hive_standalone_metastore: 4.2.0
```

But existing Bigtop Hive RPM spec is oriented around Hive package subpackages, including `hive-metastore`.

Need to decide whether Standalone Metastore is delivered as:

```yaml
option_a:
  package: hive-metastore
  source: hive distribution
  meaning: acceptable for RC1 if functionally equivalent

option_b:
  package: hive-standalone-metastore
  source: standalone metastore artifact
  meaning: explicit packaging required
```

This decision must be made before M2 Packaging Ready.

### 5.4 Tez 0.10.5 Compatibility

Tez 0.10.5 is already visible in the Bigtop BOM and matches RC1.

Still required validation:

- Hive 4.2.0 can use Tez 0.10.5
- Tez jars are discoverable by Hive runtime
- Tez package layout works with openEuler22 RPM install path

### 5.5 Hadoop 3.5.0 Compatibility

Hive 4.2.0 must be validated against Hadoop 3.5.0.

Required checks:

- Hadoop client dependency version
- HDFS warehouse directory operations
- YARN / Tez execution
- Classpath conflicts

### 5.6 Spark SQL Metastore Compatibility

RC1 Spark target is 3.5.8.

Spark SQL must be able to access Hive Metastore 4.2.0 or the selected metastore packaging form.

Required checks:

- Spark Hive client compatibility
- Metastore Thrift protocol compatibility
- Catalog access
- create/read table interoperability

### 5.7 JDK8 Compatibility

Hive 4.2.0 + JDK8 must be proven.

Required validation:

```bash
BIGTOP_JDK=8 ./gradlew hive-rpm
```

The exact Bigtop task name must be confirmed in real build.

## 6. Exit Criteria

TASK-203R can only move from CONDITIONAL_GO to PASS when all conditions are met:

```yaml
source_download: PASS
signature_or_checksum: PASS
bom_update: PASS
patch_apply: PASS
rpm_build: PASS
dnf_repo_metadata: PASS
rpm_install: PASS
metastore_start: PASS
hiveserver2_start: PASS
hive_ddl: PASS
hive_dml: PASS
hive_join: PASS
tez_execution: PASS
spark_sql_metastore_access: PASS
```

## 7. Risks

### R-HIVE-RPM-001: Hive 4.2.0 Packaging Drift

```yaml
severity: High
risk: Hive 4.2.0 distribution layout may differ from existing Bigtop Hive 4.0.1 packaging assumptions.
mitigation: Run RPM build and classify missing/unpackaged files.
```

### R-HIVE-RPM-002: Standalone Metastore Packaging Ambiguity

```yaml
severity: Critical
risk: RC1 requires Hive Standalone Metastore 4.2.0, but Bigtop packaging may only expose hive-metastore subpackage.
mitigation: Decide whether hive-metastore subpackage satisfies RC1, or add explicit standalone metastore package.
```

### R-HIVE-RPM-003: JDK8 Compatibility Risk

```yaml
severity: High
risk: Hive 4.2.0 may introduce build/runtime assumptions that need validation under JDK8.
mitigation: Run BIGTOP_JDK=8 build and runtime smoke tests.
```

### R-HIVE-RPM-004: Spark SQL Metastore Compatibility

```yaml
severity: High
risk: Spark 3.5.8 may not work cleanly with Hive Metastore 4.2.0 without dependency/classpath control.
mitigation: Add explicit Spark SQL metastore compatibility smoke test.
```

### R-HIVE-RPM-005: Tez Runtime Integration

```yaml
severity: Medium
risk: Hive 4.2.0 + Tez 0.10.5 integration may require configuration or packaging changes.
mitigation: Include Tez execution in Hive validation.
```

## 8. Recommendation

```yaml
result: CONDITIONAL_GO
strategy: proceed_with_hive_4_2_0_rpm_adaptation
primary_path:
  os: openEuler22
  package: rpm
  manager: dnf
required_decision:
  - standalone_metastore_packaging_model
next_action:
  - update Bigtop BOM to Hive 4.2.0 in adaptation branch
  - verify Hive 4.2.0 source download and checksum
  - run Hive RPM build under JDK8
  - decide hive-metastore vs explicit standalone metastore package
  - run Hive Metastore / HiveServer2 smoke tests
  - run Spark SQL metastore access test
```

## 9. Build Evidence Placeholder

Real build evidence must later be added under:

```text
validation/bigtop/hive-4.2.0-rpm-build-log.md
validation/bigtop/hive-4.2.0-rpm-package-list.txt
validation/bigtop/hive-4.2.0-dnf-install.md
validation/hive/metastore.md
validation/hive/ddl.md
validation/hive/dml.md
validation/hive/join.md
validation/spark/hive-metastore.md
```

## 10. Decision

Hive 4.2.0 remains the required RC1 SQL Warehouse target.

Hive Standalone Metastore 4.2.0 remains required, but its packaging model is not yet frozen.

The RC1 Hive packaging path is:

```yaml
hive: 4.2.0
hive_standalone_metastore: 4.2.0
os: openEuler22
package: rpm
manager: dnf
runtime: JDK8
```

This task remains `CONDITIONAL_GO` until real RPM build, install, Metastore, HiveServer2, Hive SQL, Tez, and Spark SQL metastore evidence is produced.
