# BIGDATA-1.0 Program Board v1.0

## 1. 目标

本文档定义 BIGDATA-1.0 的 Program Board，用于将架构、验证、工程实施统一映射到 Milestone、Epic、Issue、Agent 和交付物。

从本阶段开始，所有工作必须满足：

```text
Work Item -> Issue -> Owner -> Deliverable -> Evidence -> Exit Criteria
```

## 2. Program

```yaml
program: BIGDATA-1.0
releaseTarget: BIGDATA-1.0.0
phase: Engineering Operating System / Validation Execution
status: Active
```

## 3. Program 范围

BIGDATA-1.0 目标：

- 支持传统数仓基础能力
- 支持 Ubuntu 22.04 + JDK 8
- 支持 3 Master + 3 Worker + 1 Gateway 验证拓扑
- 验证 Bigtop 构建与包仓库体系
- 验证 Ambari 作为候选 Backend Plugin 的可行性
- 完成 Hadoop / Hive / Spark / HBase 核心能力验证
- 形成 BIGDATA-1.0.0 Release Candidate

## 4. Program 分组

| Program | 名称 | 状态 | 说明 |
|---|---|---|---|
| P0 | Engineering Operating System | Active | 执行面、规则、项目治理 |
| P1 | Foundation Layer | Done | Capability、Environment、Stack、Service Pack 等设计 |
| P2 | Platform Core | Design Done | Core Engine 抽象设计，非当前关键路径 |
| P3 | Packaging & Distribution | Active | Bigtop、Package、Repository、Bundle |
| P4 | Backend Integration | Active | Ambari Viability、Backend Adapter |
| P5 | Validation Framework | Active | Smoke Test、HA、Compatibility |
| P6 | Release Engineering | Planned | Freeze、Release Manifest、Bundle、Release Notes |

## 5. 当前关键路径

```text
M1 Technology Feasibility
  -> M2 Build & Repository
  -> M3 Platform Validation
  -> M4 HA Validation
  -> M5 Release Candidate
```

## 6. 当前优先级

当前只推进 M1：

```text
Ambari Viability Review
Bigtop Validation
```

M1 未完成前，不启动大规模组件验证和 Release 工程。

## 7. Agent Board

| Agent | 角色 | 负责范围 | 当前状态 |
|---|---|---|---|
| Agent-A | Management Backend Architect | Ambari、Backend Adapter | Active |
| Agent-B | Build & Packaging Architect | Bigtop、Repository、Bundle | Active |
| Agent-C | Storage & SQL Architect | Hadoop、Hive | Waiting |
| Agent-D | Compute & NoSQL Architect | Spark、HBase | Waiting |
| Agent-E | Platform Architect | Platform Core、Blueprint、Lifecycle | Low Priority |
| Agent-F | Release Manager | Release Freeze、Release Report | Waiting |

## 8. Program Gate

### Gate-1

目标：判断 Ambari 与 Bigtop 是否继续保留在 BIGDATA-1.0 主线。

输出：

```yaml
ambari:
  decision: GO | CONDITIONAL_GO | NO_GO
bigtop:
  decision: GO | CONDITIONAL_GO | NO_GO
```

## 9. 执行原则

- No Evidence = No Progress
- No Exit Criteria = No Done
- No Owner = No Issue
- No Dependency = No Schedule
- No Validation = No Freeze

## 10. 关联文档

- `project/MILESTONES.md`
- `project/ISSUE_TREE.md`
- `project/RISK_REGISTER.md`
- `project/DECISION_LOG.md`
- `project/AGENT_CONTRACT.md`
