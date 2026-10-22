# Bigdata Platform 阶段路线图与任务拆分

## 1. 文档目标

本文档用于定义 Bigdata Platform 从设计规划到工程落地的阶段路线图、阶段目标、任务清单、交付物、验收标准和可并行 Agent 拆分方式。

平台最终目标是建设一套同时支持传统数仓和实时数据湖的、可部署的私有化大数据平台，能够在物理机、虚拟机和远期容器平台上运行，并支持大数据组件自定义扩展、灵活组合和标准化交付。

## 2. 总体阶段划分

```text
Phase 0: 平台规划与设计收敛
Phase 1: 传统数仓物理机 HA 底座
Phase 2: 标准化部署、构建与运维体系
Phase 3: 实时数据湖能力扩展
Phase 4: 虚拟机多环境交付
Phase 5: 容器平台与云原生演进
Phase 6: 组件市场化与组合交付体系
```

### 2.1 当前实现状态（2026-10-22，Asia/Tokyo）

核验主干：`0f84fa2c60852e73fa8994007076c1e36f844c96`。**本轮组件构建、RPM 发布、CI 改造和指定恢复链路已交付；整个 Phase 0—6 路线图没有全部完成，剩余工作不只是部署和测试。**设计文档、模板、单节点 smoke 与已实现的集成能力应分别记录。

| 范围 | 已实现 / 已有证据 | 尚余部署和验收 | 尚余开发或选型 |
|---|---|---|---|
| 本轮五步组件交付 | 主干 CI 修复、来源/耗时记录、代理 CI、双 CDC 湖仓恢复、Metrics/SDK RPM 发布 | 代理正式部署与实际 CI 接入 | 本轮限定范围内无新增组件打包缺口；代理目标尚未提供 |
| Phase 1—2 发行与管理底座 | 当前版本 RPM、构建/晋级流程、Blueprint/Runbook 和参数模板；Metrics 独立运行验收 | 七节点安装、HA/failover、恢复与版本冻结评审 | 完整 Blueprint、Ambari 服务管理适配、监控告警及运维自动化仍需对照目标补齐；不能因模板存在即判定完成 |
| Phase 3 实时湖仓 | CDC MySQL/PostgreSQL 直达 Paimon、Hudi、Iceberg；HDFS 恢复及 Paimon/HTTPS S3；引擎与格式 RPM 已发布 | 实际集群和实际存储端点的稳定性、容量、故障窗口 | Kafka 中转业务作业、共享 Catalog/Trino 接入、生产对象存储选型/适配、安全和质量/延迟能力仍需实施 |
| Phase 4 虚拟机多环境 | 设计目标已定义 | 多环境部署验证 | 环境规格、镜像/初始化、配置隔离与交付自动化未据本轮完成 |
| Phase 5 云原生 | 混合管理边界已规划 | Kubernetes 部署、升级、恢复验证 | Operator 适配、资源/网络/持久化与平台集成仍为后续开发 |
| Phase 6 组合交付 | Profile 和扩展规范已设计 | 组合交付验收 | 可执行 Profile、组件依赖/兼容校验及交付编排仍需实现 |
| 产品平台层（独立产品视角） | Hue 作为已交付 SQL UI；现有方案文档 | 产品层集成测试 | 调度、数据源管理、治理/权限、多租户、质量和数据服务 API 仍待选型/开发，详见 [产品路线图](product-roadmap.md) |

“尚余开发”描述的是目标能力未闭环，不表示所有相关文件均不存在；设计/模板不能替代可执行适配。Kerberos、Ranger、Prometheus/JMX 也是新增集成工作，不应全部归入“测试”。Knox、Atlas、Delta Lake 等可选项须业务立项后独立交付，不强行扩大本轮范围。

### 2.2 本轮交付证据与边界

- [完整主干组件 CI](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689437161) success；#107/#108/#120 的门禁、复用及来源记录已合并。实际测试与仓库复用分别记录，版本/打包输入未变不重编 RPM。
- #110/#115 代理配置与完整组件冷/热/离线构建已合并，[主干验证](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689622642) PASS；265/47/39 秒分别为该运行的编译耗时，不是所有组件性能承诺。正式服务和 CI 生产镜像地址尚未接入。
- #109/#114/#117/#118/#119 已合并：[本地 Paimon](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554165)、[Paimon/HDFS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554220)、[Paimon/HTTPS S3](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554168)、[Hudi/HDFS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554558)、[Iceberg/HDFS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554289) 双 source 恢复专项 PASS；不代表 schema 演进、所有故障窗口 exactly-once 或 Kafka 中转链全部实现。
- #113/#116/#121/#122/#123 已合并；[原始 Metrics 安装/重启](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39653729447) 和 [主干候选/晋级](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39691186873) PASS，两份 RPM 已发布。Ambari 集群内配置、展示和告警集成单列。
- #106 已合并，S3A SDK 2.35.4 RPM 已发布；客户端验收不等于某生产对象存储已选型/交付。

## 3. Phase 0：平台规划与设计收敛

### 3.1 阶段目标

明确平台定位、目标场景、非目标、组件边界、部署形态、管理面选择、版本策略、阶段路线图和架构决策记录。

### 3.2 主要任务

- 定义平台总览文档
- 定义总体架构文档
- 定义 Ambari 长期管理面设计
- 定义 Bigtop 真实构建体系设计
- 定义版本矩阵设计
- 定义部署模型设计
- 定义运维模型设计
- 定义阶段路线图
- 定义并行 Agent 分工方式
- 定义架构决策记录 ADR

### 3.3 交付物

| 交付物 | 说明 |
|---|---|
| `docs/platform-overview.md` | 平台总览与定位 |
| `docs/technical-design.md` | 总体技术设计 |
| `docs/architecture-decisions.md` | 架构决策记录 |
| `docs/ambari-management-plane.md` | Ambari 管理面设计 |
| `docs/ambari-bigtop-integration.md` | Ambari + Bigtop 集成设计 |
| `docs/roadmap.md` | 阶段路线图与任务拆分 |
| `docs/deployment-design.md` | 部署设计 |
| `docs/operations-design.md` | 运维设计 |
| `docs/component-matrix.md` | 组件矩阵 |

### 3.4 验收标准

- 平台定位清晰：可部署的私有化大数据平台方案
- 第一阶段范围明确：传统数仓物理机 HA 底座
- 第一阶段组件明确：Ambari、Bigtop、ZooKeeper、HDFS、YARN、Hive、Spark、HBase
- Ambari 定位明确：传统大数据长期管理面
- Bigtop 定位明确：真实构建体系
- 实时数据湖主线明确：Iceberg + Flink + S3 兼容对象存储
- Agent + Review 工作流明确

## 4. Phase 1：传统数仓物理机 HA 底座

### 4.1 阶段目标

在物理机环境中完成传统数仓底座设计与验证目标，形成以 Ambari 管理 Hadoop 生态组件、以 Bigtop 构建组件包的第一版私有化平台方案。

### 4.2 核心组件范围

- Ambari
- Bigtop 真实构建体系
- ZooKeeper
- HDFS HA
- YARN HA
- Hive Metastore
- HiveServer2
- Spark
- HBase

### 4.3 主要任务

- 明确物理机 HA 部署拓扑
- 明确 Master / Worker / Gateway 节点角色划分
- 明确 HDFS / YARN / Hive / Spark / HBase / ZooKeeper 组件职责
- 定义最小验证集群规格
- 定义生产 HA 推荐集群规格
- 定义 Ambari 安装流程
- 定义 Ambari Blueprint 使用方式
- 定义 Bigtop 构建流程
- 定义组件包仓库发布流程
- 定义核心配置模板
- 定义 Service Check 与 Smoke Test 验证标准
- 定义安装、重启、故障恢复 Runbook

### 4.4 交付物

| 交付物 | 说明 |
|---|---|
| `docs/deployment-design.md` | 物理机 HA 部署模型 |
| `docs/component-matrix.md` | 第一阶段组件矩阵 |
| `docs/ambari-management-plane.md` | Ambari 长期管理面设计 |
| `docs/ambari-bigtop-integration.md` | Bigtop 真实构建与 Ambari 集成设计 |
| `bigtop/version-matrix.md` | 组件版本矩阵 |
| `ambari/blueprints/` | Ambari Blueprint 模板 |
| `ambari/configs/` | 核心组件配置模板 |
| `ambari/runbooks/` | 安装、重启、恢复手册 |

### 4.5 验收标准

- 能清楚描述最小部署拓扑
- 能清楚描述生产 HA 部署拓扑
- 每个核心组件职责明确
- HBase 已纳入第一阶段设计范围
- Bigtop 构建链路有明确流程
- 配置项有默认值和说明
- 运维流程有标准 runbook
- 验证流程可重复执行

### 4.6 可并行 Agent

| Agent | 可并行任务 |
|---|---|
| Ambari Agent | Ambari 安装流程、Blueprint、管理面文档 |
| Bigtop Agent | 真实构建流程、包仓库、版本矩阵 |
| Hadoop Agent | HDFS / YARN / ZooKeeper 组件设计 |
| Warehouse Agent | Hive / Spark 数仓能力设计 |
| HBase Agent | HBase 组件、部署、运维设计 |
| Config Agent | 配置模板、参数说明、环境差异 |
| Runbook Agent | 安装、重启、扩容、恢复手册 |
| Test Agent | Service Check、Smoke Test、验收清单 |

## 5. Phase 2：标准化部署、构建与运维体系

### 5.1 阶段目标

将第一阶段的设计沉淀成标准化交付体系，降低不同环境部署、构建、升级和运维成本。

### 5.2 主要任务

- 标准化 Bigtop 构建流程
- 标准化包仓库发布流程
- 标准化 Ambari Repository 配置流程
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
| `bigtop/build/` | 真实构建脚本与说明 |
| `bigtop/repo/` | 包仓库发布流程 |
| `ambari/runbooks/` | 标准运维手册 |
| `bigtop/tests/` | 验证脚本 |

### 5.4 可并行 Agent

| Agent | 可并行任务 |
|---|---|
| Build Agent | Bigtop 构建与包仓库 |
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
- Iceberg，主线表格式
- Hudi，可选 Profile
- Paimon，可选扩展 Profile
- Hive Metastore
- Trino 或 Spark SQL
- S3 兼容对象存储
- HDFS，兼容存储底座

### 6.3 主要任务

- 定义实时数据湖总体架构
- 定义 CDC 接入链路
- 定义 Kafka Topic 规划
- 定义 Flink 作业部署模型
- 定义 Iceberg 表格式主线方案
- 定义 Hudi / Paimon 可选 Profile
- 定义 S3 兼容对象存储接入方案
- 定义湖仓分层模型
- 定义实时与离线任务协同方式
- 定义元数据管理方式
- 定义实时数据质量与延迟指标

### 6.4 可并行 Agent

| Agent | 可并行任务 |
|---|---|
| CDC Agent | 数据源、变更捕获、同步链路 |
| Kafka Agent | Topic 规划、分区、副本、保留策略 |
| Flink Agent | 任务模型、Checkpoint、状态后端、部署模式 |
| Lakehouse Agent | Iceberg/Hudi/Paimon 选型、表设计、元数据管理 |
| Storage Agent | S3 兼容对象存储与 HDFS 协同 |
| Query Agent | Trino/Spark SQL 查询服务设计 |
| Quality Agent | 实时质量、延迟、补偿和一致性设计 |

## 7. Phase 4：虚拟机多环境交付

目标：支持在虚拟机环境中进行多环境部署，提升环境复制、隔离、弹性和交付效率。

## 8. Phase 5：容器平台与云原生演进

目标：在保留 Ambari 管理传统 Hadoop 底座的同时，支持 Kubernetes / Operator 管理云原生数据组件。

## 9. Phase 6：组件市场化与组合交付体系

目标：形成组件可插拔、能力可组合、交付可编排的平台体系。

## 10. 当前优先级与进入下一阶段的条件

1. **正式部署依赖代理**：提供 SSH 目标与 HTTPS 域名，配置备份、重启恢复和 CI 接入；复用已通过的部署配置及构建输入。
2. **管理面集成开发**：以已发布 RPM 为输入，补齐 Ambari 七节点 Blueprint、Agent、服务生命周期、Metrics 采集/展示/告警的实际适配，再执行 HA 验收。
3. **业务链与元数据集成**：分别交付 Kafka→Flink→湖仓的可运行作业，以及 Hive Metastore、Spark/Flink/Trino 的共享 Catalog 配置与适配；按支持能力补 Hudi/Iceberg 的 S3 场景。
4. **安全与观测**：先 Kerberos 认证与拒绝路径，再做一个 Ranger 插件和审计；补 Prometheus/JMX 指标、告警和恢复联动。每项有实现、配置及实际验收，不能只加空测试。
5. **后续产品迭代**：调度/治理/数据服务、VM 多环境、Operators、可执行组合 Profile 按范围和需求独立立项；不以本轮包交付完成来关闭这些阶段。

当前组件版本、阶段归属与实施清单分别见 [版本矩阵](version-matrix.md)、[组件矩阵](component-matrix.md)、[组件 CI 补齐计划](component-ci-backlog.md)。[本轮五步执行计划](superpowers/plans/2026-10-22-component-five-step-delivery.md) 仍保留代理正式部署为未完成项。
