# Sprint-1 RC1 Package Format Decision

## 1. Metadata

```yaml
type: sprint-decision
sprint: Sprint-1
status: accepted
owner: Chief Architect
scope: BIGDATA-1.0-RC1
```

## 2. Decision

BIGDATA-1.0 RC1 主线操作系统和包格式正式确定为：

```yaml
RC1:
  os: openEuler22
  package:
    type: rpm
    manager: dnf
```

Ubuntu22 + DEB/APT 不再作为 RC1 主线，降级为后续兼容评估线。

## 3. Decision Context

Sprint-1 发现以下事实：

1. Ambari BIGTOP stack repository definition includes `openeuler22`.
2. Bigtop repository contains openEuler22 provisioner configuration.
3. openEuler22 is RPM-oriented.
4. Previous RC1 planning used DEB/APT, which is better aligned with Ubuntu22 but less aligned with the current Ambari BIGTOP evidence path.

因此，为降低 Ambari + Bigtop 主线集成风险，RC1 采用 openEuler22 + RPM + DNF。

## 4. Updated RC1 Baseline

```yaml
rc1_baseline:
  os:
    primary: openEuler22
    compatibility:
      - Ubuntu22

  package:
    primary:
      type: rpm
      manager: dnf
    compatibility:
      - type: deb
        manager: apt

  runtime:
    primary: JDK8
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

## 5. Impact

### 5.1 Packaging Track

M2 Packaging Ready must validate RPM and DNF repository flow first.

Required outputs change from:

```text
DEB package
APT repository
```

to:

```text
RPM package
DNF repository
```

### 5.2 Bigtop Adaptation Track

Bigtop adaptation must focus on RPM packaging for openEuler22.

Required review areas:

- RPM spec compatibility
- DNF repository metadata
- openEuler22 build toolchain
- Hadoop/Hive/Spark/HBase RPM package installability
- Ambari BIGTOP stack repo configuration compatibility

### 5.3 Ambari Track

Ambari validation should prioritize openEuler22 host support.

Required review areas:

- Ambari Server install on openEuler22
- Ambari Agent install on openEuler22
- Agent registration
- Repository import using DNF/YUM style repository
- BIGTOP stack adaptation from 3.2.0 to 3.5.0 if required

### 5.4 Ubuntu22 Compatibility Track

Ubuntu22 remains valuable but is no longer RC1 blocking.

It should be evaluated after RC1 mainline is proven or in a parallel compatibility sprint.

## 6. Risks

### R-PKG-001: Previous DEB/APT Work Must Be Reclassified

```yaml
severity: Medium
status: accepted
impact: Previous planning documents mention DEB/APT.
mitigation: Treat those references as compatibility-track unless explicitly updated.
```

### R-PKG-002: RPM Adaptation For Required Component Versions

```yaml
severity: Critical
status: active
impact: Required versions may need RPM spec and patch refresh.
mitigation: Component-by-component Bigtop adaptation review.
```

### R-PKG-003: Ambari BIGTOP Stack Version Gap

```yaml
severity: High
status: active
impact: Ambari source references BIGTOP 3.2.0 stack while RC1 targets Bigtop 3.5.0.
mitigation: Validate custom stack/repo adaptation path.
```

## 7. Superseded Assumptions

The following assumptions are superseded for RC1 mainline:

```yaml
superseded:
  os: Ubuntu22
  package:
    type: deb
    manager: apt
```

They remain valid only as compatibility-track items.

## 8. Updated Next Actions

### TASK-202R-Hadoop

Review Hadoop 3.5.0 Bigtop RPM adaptation on openEuler22.

### TASK-203R-Hive

Review Hive 4.2.0 and Hive Standalone Metastore 4.2.0 RPM adaptation.

### TASK-204R-Spark

Review Spark 3.5.8 RPM adaptation.

### TASK-205R-ZooKeeper

Review ZooKeeper 3.9.5 RPM adaptation.

### TASK-206R-HBase

Review HBase 2.5.14 RPM adaptation.

## 9. Decision Summary

```yaml
decision: ACCEPTED
rc1_primary_os: openEuler22
rc1_primary_package_type: rpm
rc1_primary_package_manager: dnf
ubuntu22_deb_apt: compatibility_track
```

This decision is now the baseline for Sprint-1 and M2 Packaging Ready.
