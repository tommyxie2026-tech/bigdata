# P1-016 Phase 1 版本冻结评审检查表

## 1. 检查表目标

本文档用于执行 P1-016：在 Bigtop 构建、Ambari 管理适配、JDK 兼容性和 3M3W1G 集群验证完成后，对 Phase 1 候选版本进行冻结评审。

## 2. 评审输入

| 输入 | 状态 | 备注 |
|---|---|---|
| P1-012 Bigtop 构建验证结果 | TODO |  |
| P1-013 Ambari 管理适配结果 | TODO |  |
| P1-014 JDK 兼容性评估结果 | TODO |  |
| P1-015 3M3W1G 集群与 HA 验证结果 | TODO |  |
| Smoke Test 结果 | TODO |  |
| 缺陷清单 | TODO |  |
| 回退版本验证结果 | TODO |  |

## 3. 候选版本冻结评审

| 组件 | 主候选 | 回退版本 | 构建 | Ambari 管理 | JDK 8 | 集群验证 | 冻结结论 |
|---|---:|---:|---|---|---|---|---|
| Ambari | 3.0.0 | 2.7.9 | TODO | TODO | TODO | TODO | TODO |
| Ambari Metrics | 3.0.0 | TBD | TODO | TODO | TODO | TODO | TODO |
| Bigtop | 3.5.0 | 3.4.0 | TODO | N/A | TODO | TODO | TODO |
| Hadoop | 3.5.0 | 3.4.3 / 3.3.6 | TODO | TODO | TODO | TODO | TODO |
| ZooKeeper | 3.9.5 | 3.8.6 | TODO | TODO | TODO | TODO | TODO |
| Hive | 4.2.0 | 4.1.x / 3.x | TODO | TODO | TODO | TODO | TODO |
| Hive Standalone Metastore | 4.2.0 | 3.0.0 | TODO | TODO | TODO | TODO | TODO |
| Tez | 0.10.5 | 0.10.4 / 0.10.3 | TODO | TODO | TODO | TODO | TODO |
| Spark | 3.5.8 | 3.4.x | TODO | TODO | TODO | TODO | TODO |
| HBase | 2.5.14 | 2.5.13 | TODO | TODO | TODO | TODO | TODO |

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
| Ambari 3.0.0 | TODO |  |  |
| Hadoop 3.5.0 | TODO |  |  |
| ZooKeeper 3.9.5 | TODO |  |  |
| Hive 4.2.0 | TODO |  |  |
| Spark 3.5.8 | TODO |  |  |
| Spark 4.1.x | TODO |  |  |
| HBase 2.5.14 | TODO |  |  |
| HBase 2.6.5 | TODO |  |  |

## 5. 缺陷评审

| 缺陷级别 | 数量 | 是否允许冻结 | 备注 |
|---|---:|---|---|
| Blocker | TODO | 否 |  |
| Critical | TODO | 否 |  |
| Major | TODO | 视情况 |  |
| Minor | TODO | 是 |  |

冻结条件：

- Blocker 缺陷必须为 0
- Critical 缺陷必须为 0
- Major 缺陷必须有规避方案或明确不影响 Phase 1 验收
- Minor 缺陷可以进入后续修复计划

## 6. 回退策略评审

| 组件 | 主候选失败条件 | 回退版本 | 回退验证状态 | 是否接受回退 |
|---|---|---:|---|---|
| Ambari | 3.0.0 不可管理 P0 组件 | 2.7.9 | TODO | TODO |
| Bigtop | 3.5.0 不可构建 P0 组件 | 3.4.0 | TODO | TODO |
| Hadoop | 3.5.0 构建/运行/管理失败 | 3.4.3 / 3.3.6 | TODO | TODO |
| ZooKeeper | 3.9.5 兼容性失败 | 3.8.6 | TODO | TODO |
| Hive | 4.2.0 兼容性失败 | 4.1.x / 3.x | TODO | TODO |
| Metastore | 4.2.0 与 Spark 不兼容 | 3.0.0 | TODO | TODO |
| Tez | 0.10.5 与 Hive 不兼容 | 0.10.4 / 0.10.3 | TODO | TODO |
| Spark | 3.5.8 不兼容 | 3.4.x | TODO | TODO |
| HBase | 2.5.14 不兼容 | 2.5.13 | TODO | TODO |

## 7. Phase 1 版本冻结输出

最终输出应包括：

| 输出项 | 结果 |
|---|---|
| 是否冻结 Phase 1 版本矩阵 | TODO |
| 冻结版本矩阵提交位置 | TODO |
| 是否需要新增 ADR | TODO |
| 是否可以进入工程模板阶段 | TODO |
| 是否可以关闭 P1-001 | TODO |

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
