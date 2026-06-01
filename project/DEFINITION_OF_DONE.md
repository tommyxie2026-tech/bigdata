# BIGDATA-1.0 Definition of Done

## 1. 目标

本文档定义 BIGDATA-1.0 的完成标准，用于统一 Issue、Epic、Milestone、Gate 和 Release 的 Done 判定。

核心原则：

```text
No Evidence = No Progress
No Exit Criteria = No Done
No Validation = No Freeze
```

## 2. Issue Done

一个 Issue 只有同时满足以下条件，才能标记为 Done。

| 条件 | 要求 |
|---|---|
| Owner | 有明确负责人或 Agent |
| Scope | 范围清晰 |
| Deliverable | 交付物已提交 |
| Evidence | 证据已归档 |
| Exit Criteria | 完成标准全部满足 |
| Result | 结论明确：PASS / FAIL / PARTIAL / BLOCKED |
| Review | 必要时完成评审 |

Issue 输出必须包含：

```yaml
result: PASS | FAIL | PARTIAL | BLOCKED
evidence:
  - path-or-link
remainingRisk:
  - item
```

## 3. Epic Done

Epic 完成必须满足：

- 所有 P0 子 Issue 完成
- 所有阻塞问题关闭或有明确决策
- 有 Epic Summary
- 有 Validation Report 或 Review Report
- 有 GO / NO_GO / CONDITIONAL_GO 结论

示例：

```yaml
epic: EPIC-102 Bigtop Validation
result: GO
summary: validation/bigtop/report.md
```

## 4. Milestone Done

Milestone 完成必须满足：

- 所有关联 Epic 达到 Done
- Milestone Gate Review 完成
- 关键风险更新到 `project/RISK_REGISTER.md`
- 关键决策更新到 `project/DECISION_LOG.md`
- 下一 Milestone 的入口条件明确

## 5. Gate Done

Gate 是阶段性技术决策点。

Gate 完成必须输出明确决策：

```yaml
decision: GO | NO_GO | CONDITIONAL_GO
reason:
  - item
evidence:
  - item
followUp:
  - item
```

## 6. Release Candidate Done

BIGDATA-1.0.0-RC1 完成必须满足：

- 版本矩阵冻结
- Repository 可用
- Blueprint / Runbook 可用
- Validation Report 完整
- Hadoop / Hive / Spark / HBase 核心验证完成
- HDFS HA / YARN HA 完成
- Blocker / Critical 缺陷清零
- Release Manifest 生成

## 7. 不允许 Done 的情况

以下情况不得标记 Done：

- 只有口头结论，没有证据
- 只有文档，没有验证
- 只有验证过程，没有结果
- 失败项没有风险记录
- 依赖未完成但未说明 Blocked
- Exit Criteria 未覆盖核心目标

## 8. 证据要求

证据可以包括：

- 构建日志
- 安装日志
- 命令输出
- 包列表
- 仓库快照
- Smoke Test 结果
- HA 验证记录
- Review Report
- 决策记录

建议路径：

```text
validation/<domain>/
```

## 9. 状态定义

| 状态 | 说明 |
|---|---|
| PASS | 完全通过 |
| FAIL | 验证失败 |
| PARTIAL | 部分通过，有明确限制 |
| BLOCKED | 被依赖或外部条件阻塞 |
| UNKNOWN | 尚未验证，不得作为完成状态 |
