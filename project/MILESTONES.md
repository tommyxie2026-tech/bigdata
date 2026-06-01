# BIGDATA-1.0 Milestones v1.0

## 1. 目标

本文档定义 BIGDATA-1.0 从规划到 RC1 的里程碑、入口条件、交付物、退出条件和 Gate 决策。

PMO Audit #1 后，RC1 范围被收缩到最小可落地路径：

```text
Bigtop -> Repository -> Hadoop -> Hive -> Spark -> Validation -> RC1
```

HBase、Ambari Metrics、复杂 Upgrade/Rollback、Kubernetes、Streaming、Lakehouse 不进入 RC1 必须路径。

## 2. RC1 范围冻结

### 2.1 RC1 必须交付

| Feature | 内容 |
|---|---|
| F2 Distributed Storage | HDFS 基础能力与 HDFS HA |
| F3 Resource Scheduling | YARN 基础能力与 YARN HA |
| F4 SQL Warehouse | Hive 基础 SQL、Metastore、HiveServer2 |
| F5 Batch Compute | Spark 基础作业与 Spark SQL |
| F7 Packaging & Delivery | Bigtop 构建、DEB、apt Repository、Release Snapshot |
| F9 Validation & Release Evidence | Validation Report、Gate 决策证据 |

### 2.2 RC1 条件交付

| Feature | 条件 |
|---|---|
| F1 Cluster Lifecycle Management | Ambari 可行则作为主线；否则降级为验证路径 |
| F6 Low Latency NoSQL Storage | HBase 可验证则进入 RC1；否则进入 RC1+1 |
| F8 Operations & Observability | Ambari Metrics 可行则进入 RC1；否则后续增强 |

### 2.3 RC1 明确不做

- Kubernetes
- Streaming / Lakehouse
- Native Backend 完整实现
- 复杂 Upgrade / Rollback
- 完整自研 Platform Core 实现
- 完整 Observability 平台

## 3. Milestone 总览

| Milestone | 名称 | 状态 | 目标 |
|---|---|---|---|
| M0 | EOS Freeze | Active | 冻结执行治理基线 |
| M1 | Technology Feasibility | Active | 判断 Ambari/Bigtop 路线是否继续 |
| M2 | Packaging Ready | Blocked | 产出 DEB 与 apt Repository |
| M3 | Core Feature Ready | Blocked | Hadoop/Hive/Spark 核心能力通过 |
| M4 | HA Ready | Blocked | HDFS HA 与 YARN HA 通过 |
| M5 | RC1 | Blocked | 形成 BIGDATA-1.0.0-RC1 |

## 4. M0 EOS Freeze

### 4.1 目标

确保项目具备执行条件。

### 4.2 必须交付

- `project/PROGRAM_BOARD.md`
- `project/FEATURE_MAP.md`
- `project/MILESTONES.md`
- `project/ISSUE_TREE.md`
- `project/DEFINITION_OF_DONE.md`

### 4.3 退出条件

```text
Gate-0 PASS
```

判定标准：

- Program Board 存在
- Feature Map 存在
- Milestones 存在
- Issue Tree 存在
- Definition of Done 存在
- M1 首批 Issue 可创建

## 5. M1 Technology Feasibility

### 5.1 目标

判断 BIGDATA-1.0 的两条关键技术路线是否继续投入：

- Ambari 作为候选 Backend Plugin
- Bigtop 作为构建与包仓库体系

### 5.2 入口条件

- M0 Gate-0 PASS
- `docs/validation/technology-validation-matrix.md` 已存在
- `docs/validation/ambari-viability-review.md` 已存在

### 5.3 必须交付

| Track | 交付物 |
|---|---|
| Ambari | `validation/ambari/report.md` |
| Bigtop | `validation/bigtop/report.md` |

### 5.4 退出条件

```yaml
ambari:
  decision: GO | CONDITIONAL_GO | NO_GO
bigtop:
  decision: GO | CONDITIONAL_GO | NO_GO
```

### 5.5 Gate-1 决策

| Ambari | Bigtop | 决策 |
|---|---|---|
| GO | GO | 进入 M2 |
| CONDITIONAL_GO | GO | 带风险进入 M2 |
| NO_GO | GO | 重构 Backend 路线，但可继续 Packaging |
| GO | NO_GO | 重构 Packaging 路线 |
| NO_GO | NO_GO | BIGDATA-1.0 主路线重审 |

## 6. M2 Packaging Ready

### 6.1 目标

形成可被安装系统消费的包和仓库。

### 6.2 入口条件

- M1 Bigtop 决策为 GO 或 CONDITIONAL_GO

### 6.3 必须交付

- Hadoop DEB 包或等价交付物
- Hive DEB 包或等价交付物
- Spark DEB 包或等价交付物
- apt Repository
- Repository Snapshot
- Package List
- Build Evidence

### 6.4 退出条件

```text
Repository Ready
```

最低要求：

- apt update 通过
- 目标包可查询
- 目标包可安装
- 仓库快照可追溯

## 7. M3 Core Feature Ready

### 7.1 目标

验证 RC1 核心功能：Hadoop、Hive、Spark。

### 7.2 入口条件

- M2 Repository Ready

### 7.3 必须交付

| Feature | 验证 |
|---|---|
| F2 HDFS | mkdir / put / cat / rm |
| F3 YARN | application submit |
| F4 Hive | create database / create table / insert / select / join |
| F5 Spark | spark-submit / Spark SQL / Hive Metastore access |

### 7.4 退出条件

```text
Core Feature Ready
```

最低要求：

- HDFS PASS
- YARN PASS
- Hive 基础 SQL PASS
- Spark 基础作业 PASS

## 8. M4 HA Ready

### 8.1 目标

验证 RC1 必须高可用能力。

### 8.2 入口条件

- M3 Core Feature Ready

### 8.3 必须交付

- HDFS NameNode HA 验证
- YARN ResourceManager HA 验证
- HA Validation Report

### 8.4 退出条件

```text
HA Ready
```

最低要求：

- HDFS HA PASS
- YARN HA PASS

## 9. M5 Release Candidate

### 9.1 目标

形成 BIGDATA-1.0.0-RC1。

### 9.2 入口条件

- M4 HA Ready

### 9.3 必须交付

- Release Manifest
- Release Snapshot
- Validation Report
- Known Issues
- Release Notes
- RC1 Decision Record

### 9.4 退出条件

```text
BIGDATA-1.0.0-RC1 Ready
```

最低要求：

- Blocker = 0
- Critical = 0
- RC1 必须 Feature 均有验证证据
- 可选 Feature 明确状态

## 10. Milestone 执行纪律

- 未通过 M1，不启动大规模组件验证。
- 未通过 M2，不启动核心功能验证。
- 未通过 M3，不启动 HA 验证。
- 未通过 M4，不启动 RC1 冻结。
- 任何 Milestone 未满足 DoD，不得标记完成。

## 11. 关联文档

- `project/PROGRAM_BOARD.md`
- `project/FEATURE_MAP.md`
- `project/ISSUE_TREE.md`
- `project/DEFINITION_OF_DONE.md`
- `docs/validation/validation-framework-design.md`
- `docs/validation/technology-validation-matrix.md`
