# BIGDATA-1.0 Validation Workspace

## 1. 目标

本目录用于保存 BIGDATA-1.0 RC1 的全部验证证据。

从工程实施阶段开始，所有 Gate、Milestone、Issue 的完成结论必须能够追溯到本目录下的证据文件。

核心原则：

```text
No Evidence = No Progress
```

## 2. 目录结构

```text
validation/
├── ambari/     # Ambari 可行性与 Backend Plugin 验证
├── bigtop/     # Bigtop 构建、包、仓库验证
├── hadoop/     # HDFS / YARN 基础能力验证
├── hive/       # Hive / Metastore / HiveServer2 验证
├── spark/      # Spark / Spark SQL 验证
├── ha/         # HDFS HA / YARN HA 验证
└── reports/    # Gate Review 与 RC1 Validation Report
```

## 3. Evidence 状态

每份验证证据必须给出：

```yaml
result: PASS | FAIL | PARTIAL | BLOCKED
owner:
evidence:
remainingRisk:
```

## 4. 当前优先级

M1 阶段优先产出：

- `validation/ambari/report.md`
- `validation/bigtop/report.md`

## 5. 关联文档

- `project/DEFINITION_OF_DONE.md`
- `project/MILESTONES.md`
- `docs/validation/technology-validation-matrix.md`
- `docs/validation/ambari-viability-review.md`
