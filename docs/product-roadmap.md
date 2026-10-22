# Bigdata Platform 产品路线图

> 当前状态更新：2026-10-22（Asia/Tokyo），证据主干 `0f84fa2c60852e73fa8994007076c1e36f844c96`。当前实现是 openEuler 22.03 LTS SP4 / RPM 仓库；下文产品分层不等于各层已经交付。本轮组件包与指定恢复测试已交付，完整数据平台能力尚未完成。
>
> 阶段编号口径：本文沿用四层**产品视角**；[工程路线图](roadmap.md) 使用 Phase 0—6。本文 Phase 2“Data Platform”是独立产品能力层，不是工程 Phase 2“部署与运维”；本文 Phase 4 云原生大体对应工程 Phase 5，不能混用完成率。

## 1. 文档目标

本文档用于从产品视角重新规划 Bigdata Platform 的演进路径，明确项目不是单纯的大数据发行版，也不是一开始就建设完整数据平台，而是采用分层演进模式：

```text
Distribution Layer
  -> Data Platform Layer
  -> Lakehouse Layer
  -> Cloud Native Layer
```

## 2. 产品定位

Bigdata Platform 的长期目标是一套可私有化交付、可扩展、可运维、可演进的大数据平台。

它包含两类能力：

| 层次 | 说明 |
|---|---|
| Distribution 能力 | 构建包、版本矩阵、安装集群、管理组件、运维集群 |
| Platform 能力 | 数据开发、任务调度、权限治理、元数据管理、数据服务、湖仓管理 |

第一阶段先完成 Distribution Layer，确保底座可部署、可管理、可验证。后续再建设 Platform Layer，避免一开始范围失控。

## 3. 总体产品分层

```text
┌──────────────────────────────────────┐
│        Cloud Native Layer             │
│  Kubernetes / Operator / Object Store │
└──────────────────────────────────────┘
                  ↑
┌──────────────────────────────────────┐
│        Lakehouse Layer                │
│  Kafka / Flink / Iceberg / Trino      │
└──────────────────────────────────────┘
                  ↑
┌──────────────────────────────────────┐
│        Data Platform Layer            │
│  Dev / Scheduler / Governance / API   │
└──────────────────────────────────────┘
                  ↑
┌──────────────────────────────────────┐
│        Distribution Layer             │
│  Bigtop / Ambari / Hadoop Ecosystem   │
└──────────────────────────────────────┘
```

## 4. Phase 1：Distribution Layer

### 4.1 阶段目标

建设可私有化交付的传统大数据发行与部署底座。

核心目标：

- 组件版本矩阵
- Bigtop 构建体系
- openEuler RPM / DNF 包仓库（当前实现）
- Ambari 管理面
- 3M3W1G HA 集群验证
- Runbook
- Smoke Test
- 版本冻结机制

### 4.2 核心组件

```text
Ambari
Bigtop
Hadoop / HDFS / YARN
ZooKeeper
Hive
Hive Standalone Metastore
Tez
Spark
HBase
```

### 4.3 交付物

| 交付物 | 说明 |
|---|---|
| Version Matrix | 候选版本、回退版本、升级路径 |
| Bigtop Repo | openEuler 22.03 LTS SP4 RPM 仓库及校验和/元数据 |
| Ambari Blueprint | 3M3W1G HA 拓扑 |
| Runbook | 安装、重启、恢复、巡检 |
| Smoke Test | HDFS/YARN/Hive/Spark/HBase 验证 |
| Freeze Report | 版本冻结评审报告 |

### 4.4 非目标

Phase 1 不做：

- 自研统一控制台
- 数据开发平台
- 调度系统
- Ranger / Atlas / Knox 生产化
- 实时数据湖落地
- Kubernetes Operator 实现

## 5. Phase 2：Data Platform Layer

### 5.1 阶段目标

在 Distribution Layer 稳定后，建设面向数据团队的数据平台能力。

核心目标：

- 数据开发工作台
- 任务调度与编排
- 数据源管理
- 元数据目录
- 权限模型
- 数据质量
- 数据服务 API
- 多租户资源管理

### 5.2 能力模块

| 模块 | 说明 |
|---|---|
| Data Studio | SQL、Spark、Hive 作业开发入口 |
| Scheduler | 周期任务、依赖编排、补数、重跑 |
| Metadata Catalog | 表、字段、血缘、生命周期 |
| Access Control | 用户、角色、资源权限 |
| Data Quality | 规则、校验、告警 |
| Data Service | API 发布、查询服务、服务治理 |
| Tenant Management | 租户、队列、配额、资源隔离 |

### 5.3 关键决策

Phase 2 需要确认：

- 是否自研调度，还是集成 DolphinScheduler / Airflow
- 是否自研元数据，还是集成 Atlas / DataHub
- 权限是否基于 Ranger
- 是否需要统一 Web Console
- 是否需要多租户与计量计费

## 6. Phase 3：Lakehouse Layer

### 6.1 阶段目标

扩展实时数据湖与湖仓一体能力。

核心目标：

```text
CDC -> Kafka -> Flink -> Iceberg -> S3/HDFS -> Trino/Spark SQL
```

### 6.2 核心组件

- Kafka
- Flink
- CDC Connector
- Iceberg
- Hudi，作为可选 Profile
- Trino
- S3 Compatible Object Storage
- Hive Metastore / Catalog
- Paimon，已交付的可选扩展 Profile

### 6.3 能力模块

| 模块 | 说明 |
|---|---|
| Realtime Ingestion | CDC、日志、消息接入 |
| Stream Processing | Flink 作业、状态、Checkpoint |
| Lakehouse Table | Iceberg / Hudi / Paimon 表管理 |
| Query Engine | Trino / Spark SQL 查询 |
| Data Freshness | 延迟、Lag、时效性监控 |
| Data Quality | 实时质量、补偿、重放 |

## 7. Phase 4：Cloud Native Layer

### 7.1 阶段目标

将部分计算和服务能力迁移到 Kubernetes / Operator 模式，形成云原生大数据平台能力。

### 7.2 云原生边界

| 组件 | 管理方式 |
|---|---|
| HDFS / YARN | Ambari 继续管理，传统底座 |
| Spark | Spark on Kubernetes，逐步演进 |
| Flink | Flink Kubernetes Operator |
| Kafka | Kafka Operator |
| Trino | Kubernetes 部署 |
| Iceberg / Hudi / Paimon | Object Storage + Catalog |
| Prometheus / Grafana | 云原生观测 |

### 7.3 混合管理模式

```text
Ambari 管传统 Hadoop 底座
Kubernetes 管云原生计算与查询服务
统一平台层做资源、任务、数据、权限和服务抽象
```

## 8. 产品能力地图

| 能力 | Phase 1 | Phase 2 | Phase 3 | Phase 4 |
|---|---|---|---|---|
| 组件构建 | 是 | 增强 | 增强 | 增强 |
| 集群安装 | 是 | 是 | 是 | 是 |
| 集群运维 | 是 | 是 | 是 | 是 |
| 数据开发 | 否 | 是 | 是 | 是 |
| 调度编排 | 否 | 是 | 是 | 是 |
| 元数据治理 | 设计保留 | 是 | 是 | 是 |
| 权限治理 | 设计保留 | 是 | 是 | 是 |
| 实时接入 | 否 | 设计 | 是 | 是 |
| 湖仓表格式 | 否 | 设计 | 是 | 是 |
| 容器平台 | 否 | 否 | 设计 | 是 |

## 9. 当前产品能力交付状态

| 产品层 | 当前实物成果 | 尚未完成的非测试工作 |
|---|---|---|
| Distribution | Ambari/核心生态 RPM 与仓库、CI 与发布证据；Metrics Collector/Monitor 3.0.0 已发布 | 七节点管理适配、监控告警联动与运维自动化需补齐；代理正式部署/接入待目标 |
| Data Platform | 已发布 Hue SQL UI；产品模块及选型问题已有设计 | 调度/编排、数据源管理、统一元数据/血缘、权限、多租户、质量与数据服务仍需选型/开发；Hue 不代表完整 Data Studio 或统一控制台 |
| Lakehouse | Kafka/Flink/三种表格式/Trino 包；双 CDC 湖仓直连与远端恢复专项通过 | Kafka 中转链业务作业、共享 Catalog/查询服务集成、生产对象存储适配、数据新鲜度/质量/重放能力仍需实现 |
| Cloud Native | 传统管理面与 K8s 的边界已设计 | Operators、环境/资源模型、持久化/网络配置与混合管理仍为后续实施 |

因此，**排除部署和测试后，仍不能说已经完成全部计划迭代**。本轮交付闭环与长期产品路线需分开评价；可选能力按明确业务需求立项，不要求一次性实现全部候选组件。

## 10. 下一轮实施建议

- 先按 [工程路线图当前优先级](roadmap.md#10-当前优先级与进入下一阶段的条件) 完成代理接入、Ambari 管理适配、真实业务链和安全观测。
- 平台层保留独立选型任务：调度（例如 DolphinScheduler/Airflow）、元数据治理（例如 Atlas/DataHub）、权限（例如 Ranger）、统一控制台和多租户边界；这些名称是候选，不是已锁定版本或已完成服务。
- 分别定义每个模块的输入、可执行产物和验收条件后再进入开发。不会因为某个模块出现在路线图中就声称已实现，也不会为新增测试重复编译既有 RPM。

## 11. 核心原则

```text
先发行版底座，再平台能力；
先可部署可验证，再产品化控制台；
先传统数仓稳定，再实时湖仓扩展；
先物理机/虚拟机稳定，再云原生演进。
```
