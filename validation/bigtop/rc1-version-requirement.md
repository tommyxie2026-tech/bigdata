# Sprint-1 RC1 Version Requirement Decision

## 1. Metadata

```yaml
type: sprint-decision
sprint: Sprint-1
status: accepted
owner: Chief Architect
scope: BIGDATA-1.0-RC1
```

## 2. Decision

BIGDATA-1.0 RC1 的组件版本以项目目标要求为准，而不是以 Bigtop 当前 BOM 中已有版本为准。

Bigtop 当前 BOM 只用于识别适配差距，不用于自动降级 RC1 目标版本。

## 3. Required RC1 Version Targets

```yaml
os:
  primary: openEuler22
  compatibility:
    - Ubuntu22

runtime:
  jdk: JDK8
  compatibility:
    - JDK17 evaluation

bigtop:
  candidate: 3.5.0

components:
  hadoop: 3.5.0
  zookeeper: 3.9.5
  hive: 4.2.0
  hive_standalone_metastore: 4.2.0
  tez: 0.10.5
  spark: 3.5.8
  hbase: 2.5.14
```

## 4. Evidence From Current Bigtop BOM

Current Bigtop mainline BOM evidence observed during Sprint-1:

```yaml
bigtop_mainline_visible_bom:
  hadoop: 3.4.3
  hive: 4.0.1
  spark: 3.5.6
  hbase: 2.6.5
  tez: 0.10.5
```

This creates a version gap between project-required RC1 target versions and currently visible Bigtop BOM versions.

## 5. Interpretation

The version gap means:

```text
Bigtop adaptation is required.
```

It does not mean:

```text
RC1 target versions should be downgraded.
```

## 6. Updated Sprint-1 Strategy

Previous TASK-202 recommendation suggested using Hadoop 3.4.3 as RC1 primary candidate because it appears in current Bigtop BOM.

This decision supersedes that recommendation.

Updated rule:

```yaml
if_required_version_not_in_bigtop_bom:
  action: adapt_bigtop_bom_and_packaging
  not_action: downgrade_rc1_version
```

## 7. New Validation Focus

Sprint-1 version validation changes from:

```text
Which version should RC1 use?
```

to:

```text
What changes are required for Bigtop 3.5.0 to build the required RC1 versions?
```

## 8. Required Follow-up Tasks

### TASK-202R Hadoop 3.5.0 Bigtop Adaptation Review

Validate:

- BOM change from Hadoop 3.4.3 to Hadoop 3.5.0
- Source tarball path
- Patch compatibility
- DEB packaging compatibility
- JDK8 build compatibility
- Runtime smoke test impact

### TASK-203R Hive 4.2.0 Bigtop Adaptation Review

Validate:

- BOM change from Hive 4.0.1 to Hive 4.2.0
- Hive Standalone Metastore 4.2.0 packaging impact
- Tez 0.10.5 compatibility
- JDK8 compatibility
- Spark SQL metastore compatibility

### TASK-204R Spark 3.5.8 Bigtop Adaptation Review

Validate:

- BOM change from Spark 3.5.6 to Spark 3.5.8
- Spark on YARN impact
- Hive Metastore client compatibility

### TASK-205R ZooKeeper 3.9.5 Adaptation Review

Validate:

- BOM change from ZooKeeper 3.8.x to 3.9.5
- HBase and Hadoop HA compatibility

### TASK-206R HBase 2.5.14 Adaptation Review

Validate:

- HBase version target alignment
- ZooKeeper 3.9.5 compatibility
- HDFS 3.5.0 compatibility

## 9. Risk Update

### R-005 Version Gap

```yaml
severity: Critical
status: accepted
meaning: Bigtop adaptation required
mitigation:
  - keep required versions as RC1 targets
  - create Bigtop adaptation branch or patch set
  - validate each component build independently
```

### R-006 Bigtop Adaptation Scope

```yaml
severity: Critical
status: new
meaning: RC1 now depends on custom Bigtop adaptation work
mitigation:
  - perform component-by-component adaptation review
  - prioritize Hadoop/Hive/Spark before HBase
  - do not freeze until build evidence exists
```

## 10. Decision Summary

```yaml
decision: ACCEPTED
rc1_versions: project_required_versions
bigtop_current_bom: evidence_only
build_strategy: adapt_bigtop_to_required_versions
```

BIGDATA-1.0 RC1 will keep the project-required version targets and treat Bigtop BOM differences as engineering adaptation work.
