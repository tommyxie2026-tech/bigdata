# PATCH-001 RC1 BOM Version Patch

## 1. Metadata

```yaml
patch: PATCH-001
name: RC1 BOM Version Patch
phase: M2-Prep
task: TASK-303
status: draft-ready
owner: Agent-B
component: bigtop.bom
```

## 2. Objective

将 Bigtop 适配分支中的 `bigtop.bom` 调整为 BIGDATA-1.0 RC1 要求版本。

该 patch 只负责版本基线调整，不负责 RPM spec 修复、patch refresh、依赖修正或真实构建通过。

## 3. Source Of Truth

RC1 目标版本以项目要求为准：

```yaml
rc1_required_versions:
  hadoop: 3.5.0
  zookeeper: 3.9.5
  hive: 4.2.0
  hive_standalone_metastore: 4.2.0
  tez: 0.10.5
  spark: 3.5.8
  hbase: 2.5.14
```

Bigtop 当前 BOM 中已有版本只用于差距识别，不得作为自动降级依据。

## 4. Expected BOM Changes

### 4.1 Hadoop

Target:

```groovy
'hadoop' {
  name    = 'hadoop'
  version { base = '3.5.0'; pkg = base; release = 1 }
}
```

### 4.2 ZooKeeper

Target:

```groovy
'zookeeper' {
  name    = 'zookeeper'
  version { base = '3.9.5'; pkg = base; release = 1 }
}
```

### 4.3 Hive

Target:

```groovy
'hive' {
  name    = 'hive'
  version { base = '4.2.0'; pkg = base; release = 1 }
}
```

### 4.4 Tez

Target:

```groovy
'tez' {
  name    = 'tez'
  version { base = '0.10.5'; pkg = base; release = 1 }
}
```

Tez 0.10.5 is already aligned with the RC1 target if the observed BOM still uses 0.10.5.

### 4.5 Spark

Target:

```groovy
'spark' {
  name    = 'spark'
  version { base = '3.5.8'; pkg = base; release = 1 }
}
```

### 4.6 HBase

Target:

```groovy
'hbase' {
  name    = 'hbase'
  version { base = '2.5.14'; pkg = base; release = 1 }
}
```

## 5. Explicit Non-Goals

PATCH-001 does not include:

- RPM spec changes
- dependency package name fixes
- patch refresh
- source checksum update beyond BOM-required fields
- Ambari stack repo changes
- DNF repository script changes
- runtime configuration changes

Those are handled by later patches:

```text
PATCH-002 openEuler22 Toolchain Preflight Patch
PATCH-003 ZooKeeper 3.9.5 RPM Patch
PATCH-004 Hadoop 3.5.0 RPM Patch
PATCH-005 Hive 4.2.0 RPM Patch
PATCH-006 Spark 3.5.8 RPM Patch
PATCH-007 HBase 2.5.14 RPM Patch
PATCH-008 DNF Repository Script Patch
```

## 6. Validation Commands

After editing `bigtop.bom`, record:

```bash
git diff -- bigtop.bom

grep -n "hadoop\|zookeeper\|hive\|tez\|spark\|hbase" bigtop.bom
```

Archive output to:

```text
validation/bigtop/patch-001-rc1-bom-version-diff.md
```

## 7. Build Smoke Trigger

After PATCH-001 is applied, the first build command should target ZooKeeper because it is the smallest HA prerequisite among the required RC1 components.

Initial build order:

```text
1. ZooKeeper 3.9.5
2. Hadoop 3.5.0
3. Hive 4.2.0
4. Spark 3.5.8
5. HBase 2.5.14
```

## 8. Failure Handling Rule

If a component fails to build after PATCH-001:

```yaml
allowed_response:
  - record_failure_log
  - classify_failure
  - create_component_patch
  - update_risk_register

forbidden_response:
  - silently_downgrade_version
  - remove_component_from_rc1_without_gate_review
  - skip_evidence_archive
```

## 9. Evidence Required

PATCH-001 is complete only when:

```yaml
bigtop_bom_modified: PASS
target_versions_visible: PASS
git_diff_archived: PASS
no_rpm_spec_changes_in_patch_001: PASS
working_tree_status_recorded: PASS
```

Required evidence files:

```text
validation/bigtop/patch-001-rc1-bom-version-diff.md
validation/bigtop/patch-001-rc1-bom-version-status.md
```

## 10. Risks

### R-PATCH-001-001: BOM Version Is Necessary But Not Sufficient

```yaml
severity: High
risk: Updating BOM versions may trigger source download, patch, packaging, and dependency failures.
mitigation: Treat PATCH-001 as the start of adaptation, not proof of compatibility.
```

### R-PATCH-001-002: Source Naming Drift

```yaml
severity: High
risk: Required component source tarball names may differ from Bigtop expectations.
mitigation: Validate each component source download separately.
```

### R-PATCH-001-003: Hidden Transitive Version Conflicts

```yaml
severity: Critical
risk: Hadoop/Hive/Spark/HBase may compile individually but fail together due to dependency/classpath conflicts.
mitigation: Keep integration smoke tests as RC1 blocking evidence.
```

## 11. Decision

PATCH-001 is approved as the first engineering patch on the Bigtop RC1 adaptation branch.

It establishes the required RC1 version baseline but does not mark any component as build-ready or runtime-ready.
