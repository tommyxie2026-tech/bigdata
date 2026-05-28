# Bigdata Platform 并行 Agent 执行计划

## 1. 文档目标

本文档用于定义 Bigdata Platform 设计与工程阶段中如何拆分并行 Agent、如何定义 Agent 输入输出、如何控制协作边界、如何评审合并结果。

平台目标较大，涉及传统数仓、实时数据湖、物理机、虚拟机、容器平台、组件扩展和交付体系，因此需要通过并行 Agent 拆分专项任务，提高设计与工程推进效率。

## 2. Agent 协作原则

### 2.1 架构先行

所有 Agent 必须以平台总览、路线图和组件矩阵为输入，不允许脱离总体架构单独扩展。

### 2.2 文档先行

当前阶段以设计文档为主，不优先生成深度工程实现。

### 2.3 边界清晰

每个 Agent 只负责一个明确领域，避免职责重叠。

### 2.4 输出可评审

每个 Agent 的输出必须包含：

- 设计文档
- 决策说明
- 任务清单
- 风险清单
- 验收标准
- 后续建议

### 2.5 统一收敛

所有 Agent 输出最终由 Architecture / Review Agent 收敛，统一术语、目录、组件边界和阶段归属。

## 3. Agent 角色定义

| Agent | 职责 |
|---|---|
| Architecture Agent | 总体架构、平台边界、阶段路线、最终收敛 |
| Deployment Agent | 物理机、虚拟机、容器平台部署模型 |
| Component Agent | 组件矩阵、版本兼容、组件组合 |
| Ambari Agent | Ambari 管理面、Blueprint、服务生命周期 |
| Bigtop Agent | 构建体系、包仓库、版本矩阵 |
| Warehouse Agent | 传统数仓、Hive、Spark、HDFS、YARN |
| Realtime Lakehouse Agent | Kafka、Flink、CDC、Iceberg/Hudi、Trino |
| Operations Agent | 运维流程、监控告警、巡检、恢复 |
| Security Agent | 认证、授权、审计、Kerberos、Ranger、Knox |
| QA Agent | 验收标准、Service Check、Smoke Test、测试流程 |
| Delivery Agent | 交付 Profile、目录结构、部署包、客户化交付 |
| Review Agent | 冲突检查、术语统一、文档质量评审 |

## 4. Phase 0 并行任务

### 4.1 目标

完成平台设计收敛。

### 4.2 并行 Agent 分工

| Agent | 输入 | 输出 |
|---|---|---|
| Architecture Agent | 平台目标、用户需求 | `platform-overview.md`、`technical-design.md` |
| Deployment Agent | 部署目标 | `deployment-design.md` |
| Component Agent | 组件范围 | `component-matrix.md` |
| Operations Agent | 运维目标 | `operations-design.md` |
| Realtime Lakehouse Agent | 实时数据湖目标 | `realtime-lakehouse-design.md` |
| Delivery Agent | 交付目标 | Profile 与交付流程草案 |
| Review Agent | 所有文档 | 冲突清单与修订建议 |

## 5. Phase 1 并行任务

### 5.1 目标

完成传统数仓物理机底座设计。

### 5.2 Agent 分工

| Agent | 任务 |
|---|---|
| Ambari Agent | Ambari 安装流程、Blueprint、Repository、Service Check |
| Warehouse Agent | HDFS、YARN、Hive、Spark 组件设计 |
| Deployment Agent | 物理机拓扑、网络、磁盘、角色分布 |
| Bigtop Agent | 版本矩阵、构建包、yum/apt 仓库设计 |
| Operations Agent | 安装、重启、恢复、扩容 runbook |
| QA Agent | Smoke Test、验收清单、故障注入验证 |

### 5.3 交付物

- 物理机部署设计
- 第一阶段组件矩阵
- Ambari 管理面设计
- Bigtop 集成设计
- 标准 Runbook
- 验收清单

## 6. Phase 3 并行任务

### 6.1 目标

完成实时数据湖能力设计。

### 6.2 Agent 分工

| Agent | 任务 |
|---|---|
| Realtime Lakehouse Agent | 实时数据湖总体设计 |
| CDC Agent | CDC 接入、源端适配、DDL 处理 |
| Kafka Agent | Topic、分区、副本、保留策略 |
| Flink Agent | 作业模型、Checkpoint、状态后端 |
| Lakehouse Agent | Iceberg/Hudi 选型、Catalog、表设计 |
| Query Agent | Trino / Spark SQL 查询服务设计 |
| Quality Agent | 延迟、质量、补偿、一致性设计 |
| Operations Agent | 实时链路运维与故障恢复 |

## 7. Phase 4/5 并行任务

### 7.1 虚拟机阶段

| Agent | 任务 |
|---|---|
| Infra Agent | VM 规格、镜像、网络、磁盘 |
| Env Agent | dev/test/staging/prod 环境模型 |
| Automation Agent | 初始化与部署自动化 |
| Security Agent | 主机安全、访问控制、密钥管理 |

### 7.2 容器平台阶段

| Agent | 任务 |
|---|---|
| K8s Agent | Kubernetes 运行环境设计 |
| Operator Agent | Spark/Flink/Kafka Operator 选型 |
| Storage Agent | Object Storage、PVC、数据持久化 |
| Network Agent | Service、Ingress、DNS、访问模型 |
| Observability Agent | Prometheus、Grafana、日志链路 |

## 8. Agent 标准输入模板

每个 Agent 开始任务前必须获得：

```text
任务名称：
所属阶段：
目标场景：
输入文档：
范围边界：
不做事项：
依赖 Agent：
输出文档：
验收标准：
```

## 9. Agent 标准输出模板

每个 Agent 输出必须包含：

```text
1. 背景与目标
2. 范围边界
3. 架构设计
4. 关键决策
5. 任务清单
6. 风险与约束
7. 验收标准
8. 后续计划
```

## 10. Review Agent 检查清单

Review Agent 需要检查：

- 是否符合平台总览
- 是否符合阶段路线图
- 是否组件边界一致
- 是否术语一致
- 是否与其他文档冲突
- 是否有过早工程化倾向
- 是否有明确验收标准
- 是否有后续任务拆分

## 11. 当前建议执行顺序

```text
Step 1: Architecture Agent 收敛平台总览
Step 2: Component Agent 收敛组件矩阵
Step 3: Deployment Agent 收敛部署设计
Step 4: Operations Agent 收敛运维设计
Step 5: Realtime Lakehouse Agent 收敛实时数据湖设计
Step 6: Review Agent 统一评审
Step 7: Delivery Agent 形成阶段交付计划
```

## 12. 暂停事项

当前设计阶段暂不继续深入：

- Ambari Service Script 实现
- 完整自定义 Ambari Stack 生产化
- Kubernetes Operator 落地实现
- 大量安装脚本细节
- 复杂 CI/CD 流水线

这些应在设计文档稳定后再进入工程阶段。
