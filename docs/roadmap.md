# Bigdata Platform 阶段路线图与任务拆分

## 1. 文档目标

本文档用于定义 Bigdata Platform 从设计规划到工程落地的阶段路线图、阶段目标、任务清单、交付物、验收标准和可并行 Agent 拆分方式。

平台最终目标是建设一套同时支持传统数仓和实时数据湖的大数据平台，能够在物理机、虚拟机和远期容器平台上运行，并支持大数据组件自定义扩展、灵活组合和标准化交付。

## 2. 总体阶段划分

```text
Phase 0: 平台规划与设计收敛
Phase 1: 传统数仓物理机底座
Phase 2: 标准化部署与运维体系
Phase 3: 实时数据湖能力扩展
Phase 4: 虚拟机多环境交付
Phase 5: 容器平台与云原生演进
Phase 6: 组件市场化与组合交付体系
```

## 3. Phase 0：平台规划与设计收敛

### 3.1 阶段目标

明确平台定位、目标场景、非目标、组件边界、部署形态、管理面选择、版本策略和阶段路线图。

### 3.2 主要任务

- 定义平台总览文档
- 定义总体架构文档
- 定义 Ambari 管理面设计
- 定义 Bigtop 集成设计
- 定义版本矩阵设计
- 定义部署模型设计
- 定义运维模型设计
- 定义阶段路线图
- 定义并行 Agent 分工方式

### 3.3 交付物

| 交付物 | 说明 |
|---|---|
| `docs/platform-overview.md` | 平台总览与定位 |
| `docs/technical-design.md` | 总体技术设计 |
| `docs/ambari-management-plane.md` | Ambari 管理面设计 |
| `docs/ambari-bigtop-integration.md` | Ambari + Bigtop 集成设计 |
| `docs/roadmap.md` | 阶段路线图与任务拆分 |
| `docs/deployment-design.md` | 部署设计，后续补充 |
| `docs/operations-design.md` | 运维设计，后续补充 |

### 3.4 验收标准

- 平台定位清晰
- 第一阶段范围明确
- 后续阶段边界清楚
- 组件主线与暂缓项明确
- 文档结构稳定
- 后续工程任务可以被拆分执行

### 3.5 可并行 Agent

| Agent | 职责 |
|---|---|
| Architecture Agent | 总体架构、平台边界、模块关系 |
| Deployment Agent | 物理机、虚拟机、容器部署模型设计 |
| Component Agent | 组件矩阵、版本兼容性、组件组合策略 |
| Operations Agent | 运维模型、告警、巡检、故障恢复 |
| Delivery Agent | 交付流程、目录结构、验收标准 |

## 4. Phase 1：传统数仓物理机底座

### 4.1 阶段目标

在物理机环境中完成传统数仓底座设计，形成以 Ambari 管理 Hadoop 生态组件的第一版平台方案。

### 4.2 核心组件范围

- Ambari
- HDFS
- YARN
- Hive
- Spark
- ZooKeeper
- Bigtop 参考构建体系

### 4.3 主要任务

- 明确物理机部署拓扑
- 明确节点角色划分
- 明确 HDFS / YARN / Hive / Spark / ZooKeeper 组件职责
- 定义最小集群规格
- 定义生产推荐集群规格
- 定义 Ambari 安装流程
- 定义 Ambari Blueprint 使用方式
- 定义核心配置模板
- 定义 Service Check 与 Smoke Test 验证标准
- 定义安装、重启、故障恢复 Runbook

### 4.4 交付物

| 交付物 | 说明 |
|---|---|
| `docs/deployment-design.md` | 物理机部署模型 |
| `docs/component-matrix.md` | 第一阶段组件矩阵 |
| `ambari/blueprints/` | Ambari Blueprint 模板 |
| `ambari/configs/` | HDFS/YARN/Hive/Spark 配置模板 |
| `ambari/runbooks/` | 安装、重启、恢复手册 |
| `bigtop/version-matrix.md` | 组件版本矩阵 |

### 4.5 验收标准

- 能清楚描述最小部署拓扑
- 能清楚描述生产部署拓扑
- 每个核心组件职责明确
- 配置项有默认值和说明
- 运维流程有标准 runbook
- 验证流程可重复执行

### 4.6 可并行 Agent

| Agent | 可并行任务 |
|---|---|
| Ambari Agent | Ambari 安装流程、Blueprint、管理面文档 |
| Hadoop Agent | HDFS / YARN / ZooKeeper 组件设计 |
| Warehouse Agent | Hive / Spark 数仓能力设计 |
| Config Agent | 配置模板、参数说明、环境差异 |
| Runbook Agent | 安装、重启、扩容、恢复手册 |
| Test Agent | Service Check、Smoke Test、验收清单 |

## 5. Phase 2：标准化部署与运维体系

### 5.1 阶段目标

将第一阶段的设计沉淀成标准化交付体系，降低不同环境部署和运维成本。

### 5.2 主要任务

- 标准化安装流程
- 标准化配置变更流程
- 标准化服务启停流程
- 标准化巡检流程
- 标准化故障恢复流程
- 标准化版本记录与变更记录
- 建立部署验收清单
- 建立容量规划模板
- 建立监控告警设计

### 5.3 交付物

| 交付物 | 说明 |
|---|---|
| `docs/operations-design.md` | 运维体系设计 |
| `docs/observability-design.md` | 监控告警设计 |
| `docs/capacity-planning.md` | 容量规划模板 |
| `docs/release-process.md` | 版本发布流程 |
| `ambari/runbooks/` | 标准运维手册 |
| `bigtop/tests/` | 验证脚本 |

### 5.4 验收标准

- 安装、升级、重启、恢复流程文档化
- 关键指标和告警项定义清楚
- 有标准交付验收清单
- 有容量规划方法
- 有版本发布记录模板

### 5.5 可并行 Agent

| Agent | 可并行任务 |
|---|---|
| Ops Agent | 运维流程与故障恢复 |
| Observability Agent | 监控指标、告警规则、Dashboard 设计 |
| Release Agent | 发布流程、版本记录、变更管理 |
| Capacity Agent | 节点规格、存储容量、资源规划 |
| QA Agent | 验收清单、测试脚本、验证流程 |

## 6. Phase 3：实时数据湖能力扩展

### 6.1 阶段目标

在传统数仓底座之上扩展实时接入、流式计算、湖仓表格式和交互式查询能力，形成实时数据湖方案。

### 6.2 核心组件范围

- Kafka
- Flink
- CDC Connector
- Iceberg 或 Hudi
- Hive Metastore
- Trino 或 Spark SQL
- Object Storage / HDFS

### 6.3 主要任务

- 定义实时数据湖总体架构
- 定义 CDC 接入链路
- 定义 Kafka Topic 规划
- 定义 Flink 作业部署模型
- 定义 Iceberg / Hudi 表格式选型
- 定义湖仓分层模型
- 定义实时与离线任务协同方式
- 定义元数据管理方式
- 定义实时数据质量与延迟指标

### 6.4 交付物

| 交付物 | 说明 |
|---|---|
| `docs/realtime-lakehouse-design.md` | 实时数据湖设计 |
| `docs/cdc-design.md` | CDC 接入设计 |
| `docs/kafka-design.md` | Kafka Topic 与集群设计 |
| `docs/flink-design.md` | Flink 计算设计 |
| `docs/lakehouse-table-format.md` | Iceberg / Hudi 表格式设计 |

### 6.5 验收标准

- 实时链路架构清晰
- CDC 到湖仓链路可描述
- 流批一体边界明确
- 表格式选型有依据
- 延迟、吞吐、数据质量指标明确

### 6.6 可并行 Agent

| Agent | 可并行任务 |
|---|---|
| CDC Agent | 数据源、变更捕获、同步链路 |
| Kafka Agent | Topic 规划、分区、副本、保留策略 |
| Flink Agent | 任务模型、Checkpoint、状态后端、部署模式 |
| Lakehouse Agent | Iceberg/Hudi 选型、表设计、元数据管理 |
| Query Agent | Trino/Spark SQL 查询服务设计 |
| Quality Agent | 实时质量、延迟、补偿和一致性设计 |

## 7. Phase 4：虚拟机多环境交付

### 7.1 阶段目标

支持在虚拟机环境中进行多环境部署，提升环境复制、隔离、弹性和交付效率。

### 7.2 主要任务

- 定义 VM 部署模型
- 定义 dev/test/staging/prod 环境差异
- 定义镜像模板
- 定义网络与存储规划
- 定义自动化初始化流程
- 定义环境参数化配置
- 定义多环境交付验收标准

### 7.3 交付物

| 交付物 | 说明 |
|---|---|
| `docs/vm-deployment-design.md` | 虚拟机部署设计 |
| `docs/environment-model.md` | 多环境模型 |
| `docs/infrastructure-requirements.md` | 基础设施要求 |
| `scripts/bootstrap/` | 初始化脚本，后续阶段补充 |

### 7.4 可并行 Agent

| Agent | 可并行任务 |
|---|---|
| Infra Agent | VM 规格、网络、磁盘、OS 基线 |
| Env Agent | 多环境参数模型 |
| Automation Agent | 初始化脚本、部署流程 |
| Security Agent | 主机安全、访问控制、账号规范 |

## 8. Phase 5：容器平台与云原生演进

### 8.1 阶段目标

在保留传统 Hadoop 部署能力的同时，支持容器平台上的云原生数据组件运行与管理。

### 8.2 核心方向

- Kubernetes
- Helm
- Operator
- Spark on Kubernetes
- Flink Kubernetes Operator
- Kafka Operator
- Trino on Kubernetes
- Lakehouse on Object Storage

### 8.3 主要任务

- 定义容器平台边界
- 定义哪些组件继续由 Ambari 管理
- 定义哪些组件迁移到 Kubernetes 管理
- 定义混合架构
- 定义云原生部署规范
- 定义存储、网络、安全和监控集成方案

### 8.4 交付物

| 交付物 | 说明 |
|---|---|
| `docs/cloud-native-architecture.md` | 云原生架构设计 |
| `docs/kubernetes-deployment-design.md` | K8s 部署设计 |
| `docs/hybrid-management-plane.md` | Ambari + Kubernetes 混合管理面设计 |

### 8.5 可并行 Agent

| Agent | 可并行任务 |
|---|---|
| K8s Agent | Kubernetes 部署模型 |
| Operator Agent | Spark/Flink/Kafka Operator 选型 |
| Storage Agent | Object Storage、PVC、数据持久化 |
| Network Agent | Service、Ingress、DNS、访问路径 |
| Security Agent | RBAC、Secret、认证授权 |

## 9. Phase 6：组件市场化与组合交付体系

### 9.1 阶段目标

形成组件可插拔、能力可组合、交付可编排的平台体系，让不同场景可以按需选择组件组合。

### 9.2 主要任务

- 定义组件元数据模型
- 定义组件依赖关系
- 定义组件版本兼容规则
- 定义交付 Profile
- 定义组合式部署模板
- 定义平台能力目录
- 定义扩展组件接入规范

### 9.3 示例 Profile

```text
warehouse-basic:
  HDFS + YARN + Hive + Spark + ZooKeeper

realtime-ingestion:
  Kafka + Flink + CDC Connector

lakehouse-realtime:
  Kafka + Flink + Iceberg + Hive Metastore + Trino

governance-secure:
  Kerberos + Ranger + Knox + Atlas
```

### 9.4 可并行 Agent

| Agent | 可并行任务 |
|---|---|
| Component Registry Agent | 组件元数据与依赖模型 |
| Profile Agent | 交付 Profile 与组合模板 |
| Compatibility Agent | 版本兼容规则 |
| Extension Agent | 第三方组件扩展规范 |
| Product Agent | 能力目录与产品化表达 |

## 10. 并行 Agent 执行模型

### 10.1 Agent 输入

每个 Agent 执行任务前应获得：

- 平台总览
- 当前阶段目标
- 组件边界
- 交付物清单
- 验收标准
- 与其他 Agent 的依赖关系

### 10.2 Agent 输出

每个 Agent 输出应包括：

- 设计文档
- 决策记录
- 任务清单
- 风险清单
- 验收标准
- 后续工程建议

### 10.3 Agent 协同方式

```text
Architecture Agent
    |
    +--> Component Agent
    +--> Deployment Agent
    +--> Operations Agent
    +--> QA Agent
    +--> Security Agent
```

Architecture Agent 负责收敛顶层架构与边界，其他 Agent 并行补齐专项设计。最终由 Review Agent 汇总冲突、统一术语、合并路线图。

## 11. 当前优先级建议

当前应回到 Phase 0 和 Phase 1 的设计收敛，不继续深入 Service Script 或自定义 Stack 实现。

优先补齐：

1. `docs/platform-overview.md`
2. `docs/roadmap.md`
3. `docs/deployment-design.md`
4. `docs/component-matrix.md`
5. `docs/operations-design.md`
6. `docs/realtime-lakehouse-design.md` 的初版边界说明

待以上设计稳定后，再进入工程模板阶段。
