# Bigdata Platform 产品路线图

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
- DEB / apt 包仓库
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
| Bigtop Repo | Ubuntu 22.04 apt 仓库 |
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

### 6.3 能力模块

| 模块 | 说明 |
|---|---|
| Realtime Ingestion | CDC、日志、消息接入 |
| Stream Processing | Flink 作业、状态、Checkpoint |
| Lakehouse Table | Iceberg / Hudi 表管理 |
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
| Iceberg / Hudi | Object Storage + Catalog |
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

## 9. 当前执行建议

当前应保持 Phase 1 主线，完成 Distribution Layer 验证闭环：

```text
P1-012 Bigtop 构建验证
P1-013 Ambari 管理适配
P1-014 JDK 兼容性评估
P1-015 3M3W1G 集群与 HA 验证
P1-016 版本冻结评审
```

Phase 2 只做产品规划，不进入工程实现。

## 10. 下一步任务建议

建议新增 Phase 2 规划任务：

```text
P2-001 定义 Data Platform Layer 产品能力边界
P2-002 设计统一控制台能力地图
P2-003 评估调度系统选型
P2-004 评估元数据治理选型
P2-005 评估权限治理选型
```

## 11. 核心原则

```text
先发行版底座，再平台能力；
先可部署可验证，再产品化控制台；
先传统数仓稳定，再实时湖仓扩展；
先物理机/虚拟机稳定，再云原生演进。
```
