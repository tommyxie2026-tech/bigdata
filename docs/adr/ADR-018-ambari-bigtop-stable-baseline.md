# ADR-018 — Ambari / Bigtop Upstream Stable Baseline

## Status

Accepted for validation baseline.

## Date

2026-09-30

## Context

BIGDATA-1.0 RC1 原计划使用：

```yaml
ambari: 3.0.0
bigtop: 3.5.0
```

在进入 M2 Packaging 前重新核对 Apache 官方稳定版本。

截至 2026-09-30：

```yaml
apache_ambari_stable: 3.0.0
apache_bigtop_stable: 3.6.0
```

Apache Ambari 3.0.0 仍是当前 3.x 稳定主线，并明确支持 openEuler 22.03，同时引入 Bigtop 作为默认组件 packaging/stack 体系。

Apache Bigtop 3.6.0 已成为 stable release，并包含 openEuler 22.03 相关修复。

## Decision

BIGDATA-1.0 RC1 的上游稳定基线调整为：

```yaml
management_plane:
  apache_ambari: 3.0.0

packaging:
  apache_bigtop: 3.6.0

platform:
  os: openEuler 22.x
  package_format: RPM
  package_manager: DNF
```

Bigtop 3.5.0 从主构建基线降为兼容/回退参考，不再作为新 M2 工作的默认起点。

## Important Distinction

Bigtop 版本升级不等于 BIGDATA 自定义组件矩阵自动通过。

Bigtop 3.6.0 upstream BOM 的关键版本为：

| Component | Bigtop 3.6.0 upstream BOM |
|---|---:|
| ZooKeeper | 3.8.4 |
| Hadoop | 3.4.3 |
| HBase | 2.6.5 |
| Hive | 4.0.1 |
| Tez | 0.10.5 |
| Spark | 3.5.8 |

当前 BIGDATA 项目目标版本仍包含：

| Component | Existing BIGDATA target |
|---|---:|
| ZooKeeper | 3.9.5 |
| Hadoop | 3.5.0 |
| HBase | 2.5.14 |
| Hive | 4.2.0 |
| Tez | 0.10.5 |
| Spark | 3.5.8 |

因此从 Bigtop 3.6.0 开始实施时，必须先执行 BOM delta review。

## Validation Strategy

M2-Prep 顺序调整为：

```text
Bigtop 3.6.0 upstream baseline
  -> record exact upstream commit/tag
  -> compare upstream BOM with BIGDATA target BOM
  -> classify each delta
  -> minimize custom patches
  -> create RC1 adaptation branch
  -> build Wave 1
```

版本差异分为：

```text
UPSTREAM_MATCH
UPSTREAM_NEWER
PROJECT_NEWER
PROJECT_DIFFERENT
```

原则：

1. 若 upstream 已满足项目需求，优先使用 upstream BOM。
2. 若项目版本更新，只在有明确业务/技术理由时继续自定义。
3. 若 upstream 版本更新，不应无理由降级。
4. 所有 BOM 偏离必须有兼容性与维护成本说明。
5. 自定义版本不得以“最新”为唯一理由进入 RC1。

## Immediate Impact

### Ambari

```yaml
version: 3.0.0
action: keep
status: current-stable
```

### Bigtop

```yaml
old_baseline: 3.5.0
new_baseline: 3.6.0
action: upgrade-before-M2
status: current-stable
```

### M2 Wave 1

在 ZooKeeper 构建前增加：

```text
Bigtop 3.6.0 BOM Delta Review
```

尤其需要重新决定 ZooKeeper 是：

```text
use upstream 3.8.4
or
keep project target 3.9.5 with explicit adaptation evidence
```

## Exit Criteria

本 ADR 落地完成需满足：

```yaml
ambari_baseline_3_0_0: PASS
bigtop_baseline_3_6_0: PASS
openeuler_rpm_dnf_baseline: PASS
bigtop_3_6_bom_delta_review: PASS
adaptation_branch_based_on_3_6_0: PASS
```

## References

- Apache Ambari official 3.0.0 documentation and release notes
- Apache Software Foundation Ambari downloads
- Apache Bigtop stable downloads
- Apache Bigtop 3.6.0 release notes
- Apache Bigtop branch-3.6 `bigtop.bom`
