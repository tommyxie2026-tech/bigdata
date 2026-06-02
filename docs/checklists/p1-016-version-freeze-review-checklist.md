# P1-016 Phase 1 版本冻结评审检查表

## 1. 检查表目标

本文档用于执行 P1-016：在 Bigtop 构建、Ambari 管理适配、JDK 兼容性和 3M3W1G 集群验证完成后，对 Phase 1 候选版本进行冻结评审。

## 2. 评审输入

| 输入 | 状态 | 备注 |
|---|---|---|
| P1-012 Bigtop 构建验证结果 | Incomplete | GitHub Issue #13 仍为 Open；已有检查表与部分 RC1/RPM 证据，但未形成全量 P0 构建结果 |
| P1-013 Ambari 管理适配结果 | Incomplete | GitHub Issue #14 仍为 Open；已有检查表，缺少完整 Ambari 安装、管理和 Service Check 证据 |
| P1-014 JDK 兼容性评估结果 | Incomplete | GitHub Issue #15 仍为 Open；已有检查表，缺少各 P0 组件 JDK 8/JDK 17 结论 |
| P1-015 3M3W1G 集群与 HA 验证结果 | Incomplete | GitHub Issue #16 仍为 Open；已有检查表，缺少完整集群、Smoke Test 和 HA 证据 |
| Smoke Test 结果 | Incomplete | 尚未形成 Phase 1 全量 Smoke Test 汇总 |
| 缺陷清单 | Incomplete | Blocker/Critical 缺陷数量尚未由验证流最终确认 |
| 回退版本验证结果 | Incomplete | 回退版本已列出，但尚未完成验证 |
| OS / 包格式基线一致性 | Incomplete | `docs/version-matrix.md` 仍以 Ubuntu 22.04 / DEB 为主，RC1 决策已转向 openEuler22 / RPM / DNF |

## 3. 候选版本冻结评审

| 组件 | 主候选 | 回退版本 | 构建 | Ambari 管理 | JDK 8 | 集群验证 | 冻结结论 |
|---|---:|---:|---|---|---|---|---|
| Ambari | 3.0.0 | 2.7.9 | Optional / not complete | Incomplete | Incomplete | Incomplete | Continue Validation |
| Ambari Metrics | 3.0.0 | To be selected | Optional / not complete | Incomplete | Incomplete | Incomplete | Continue Validation |
| Bigtop | 3.5.0 | 3.4.0 | Incomplete | N/A | Incomplete | Incomplete | Continue Validation |
| Hadoop | 3.5.0 | 3.4.3 / 3.3.6 | Incomplete | Incomplete | Incomplete | Incomplete | Continue Validation |
| ZooKeeper | 3.9.5 | 3.8.6 | Partial evidence | Incomplete | Incomplete | Incomplete | Continue Validation |
| Hive | 4.2.0 | 4.1.x / 3.x | Incomplete | Incomplete | Incomplete | Incomplete | Continue Validation |
| Hive Standalone Metastore | 4.2.0 | 3.0.0 | Incomplete | Incomplete | Incomplete | Incomplete | Continue Validation |
| Tez | 0.10.5 | 0.10.4 / 0.10.3 | Incomplete | Incomplete | Incomplete | Incomplete | Continue Validation |
| Spark | 3.5.8 | 3.4.x | Incomplete | Incomplete | Incomplete | Incomplete | Continue Validation |
| HBase | 2.5.14 | 2.5.13 | Incomplete | Incomplete | Incomplete | Incomplete | Continue Validation |

冻结结论取值：

```text
Freeze
Fallback
Continue Validation
Reject
```

## 4. JDK 17 升级评估结论

| 组件 | JDK 17 评估结论 | 风险 | 后续建议 |
|---|---|---|---|
| Ambari 3.0.0 | Not complete | Java runtime and service scripts may require compatibility review | Complete P1-014 before freeze |
| Hadoop 3.5.0 | Not complete | Module and dependency compatibility unknown | Complete P1-014 before freeze |
| ZooKeeper 3.9.5 | Not complete | Runtime compatibility unknown | Complete P1-014 before freeze |
| Hive 4.2.0 | Not complete | Reflection, dependency, and Metastore compatibility unknown | Complete P1-014 before freeze |
| Spark 3.5.8 | Not complete | JDK 17 compatibility must be checked with Hadoop and Metastore | Complete P1-014 before freeze |
| Spark 4.1.x | Future evaluation only | Not a Phase 1 default candidate | Keep outside freeze baseline |
| HBase 2.5.14 | Not complete | Hadoop, ZooKeeper, and runtime compatibility unknown | Complete P1-014 before freeze |
| HBase 2.6.5 | Future evaluation only | Not a Phase 1 default candidate | Keep outside freeze baseline |

## 5. 缺陷评审

| 缺陷级别 | 数量 | 是否允许冻结 | 备注 |
|---|---:|---|---|
| Blocker | Unknown | 否 | 必须等待 P1-012 至 P1-015 汇总 |
| Critical | Unknown | 否 | 必须等待 P1-012 至 P1-015 汇总 |
| Major | Unknown | 视情况 | 需提供规避方案或证明不影响 Phase 1 验收 |
| Minor | Unknown | 是 | 可进入后续修复计划 |

冻结条件：

- Blocker 缺陷必须为 0
- Critical 缺陷必须为 0
- Major 缺陷必须有规避方案或明确不影响 Phase 1 验收
- Minor 缺陷可以进入后续修复计划

## 6. 回退策略评审

| 组件 | 主候选失败条件 | 回退版本 | 回退验证状态 | 是否接受回退 |
|---|---|---:|---|---|
| Ambari | 3.0.0 不可管理 P0 组件 | 2.7.9 | Not validated | Not accepted yet |
| Bigtop | 3.5.0 不可构建 P0 组件 | 3.4.0 | Not validated | Not accepted yet |
| Hadoop | 3.5.0 构建/运行/管理失败 | 3.4.3 / 3.3.6 | Not validated | Not accepted yet |
| ZooKeeper | 3.9.5 兼容性失败 | 3.8.6 | Not validated | Not accepted yet |
| Hive | 4.2.0 兼容性失败 | 4.1.x / 3.x | Not selected / not validated | Not accepted yet |
| Metastore | 4.2.0 与 Spark 不兼容 | 3.0.0 | Not validated | Not accepted yet |
| Tez | 0.10.5 与 Hive 不兼容 | 0.10.4 / 0.10.3 | Not validated | Not accepted yet |
| Spark | 3.5.8 不兼容 | 3.4.x | Not validated | Not accepted yet |
| HBase | 2.5.14 不兼容 | 2.5.13 | Not validated | Not accepted yet |

## 7. Phase 1 版本冻结输出

最终输出应包括：

| 输出项 | 结果 |
|---|---|
| 是否冻结 Phase 1 版本矩阵 | No |
| 冻结版本矩阵提交位置 | Not applicable |
| 是否需要新增 ADR | No immediate ADR; wait for validation-driven version/fallback decision |
| 是否可以进入工程模板阶段 | No; continue validation first |
| 是否可以关闭 P1-001 | No; keep candidate matrix open until freeze criteria and OS/package baseline alignment are met |

## 8. 版本冻结报告模板

```text
Phase 1 Version Freeze Report

1. Review Date:
2. Review Owner:
3. Candidate Matrix:
4. Build Validation Result:
5. Ambari Adaptation Result:
6. JDK Compatibility Result:
7. Cluster Validation Result:
8. Defect Summary:
9. Frozen Versions:
10. Fallback Versions:
11. Remaining Risks:
12. Final Decision:
```

## 9. 关联文档

- `docs/version-matrix.md`
- `docs/phase1-version-validation-plan.md`
- `docs/phase1-test-plan.md`
- `docs/phase1-acceptance-criteria.md`
- `docs/checklists/p1-012-bigtop-build-validation-checklist.md`
- `docs/checklists/p1-013-ambari-adaptation-checklist.md`
- `docs/checklists/p1-014-jdk-compatibility-checklist.md`
- `docs/checklists/p1-015-3m3w1g-ha-validation-checklist.md`
- `validation/phase1-version-freeze-review.md`
