# Bigdata Platform 架构决策记录

## 1. 文档目标

本文档记录 Bigdata Platform 在设计评审阶段已经确认的关键架构决策，作为后续文档修订、任务拆分和工程实施的基线。

## 2. 已确认决策

| 编号 | 决策项 | 确认结果 | 影响范围 |
|---|---|---|---|
| ADR-001 | 第一版产品形态 | 可部署的私有化大数据平台方案 | 平台定位、交付方式、验收标准 |
| ADR-002 | 第一阶段范围 | 严格聚焦传统数仓物理机底座 | 组件矩阵、部署设计、路线图 |
| ADR-003 | 第一阶段组件 | Ambari、Bigtop、ZooKeeper、HDFS、YARN、Hive、Spark、HBase | 组件矩阵、版本矩阵、部署拓扑 |
| ADR-004 | 第一阶段 HA 要求 | 第一阶段必须包含 HA 生产拓扑设计与验证目标 | 部署设计、运维设计、验收标准 |
| ADR-005 | Ambari 定位 | Ambari 不只是短期工具，应作为传统大数据平台长期管理面；云原生阶段与 Kubernetes 协同 | 管理面设计、混合架构 |
| ADR-006 | Bigtop 定位 | Bigtop 进入真实构建体系，不只是参考 | 构建体系、版本矩阵、包仓库、交付流程 |
| ADR-007 | 自定义 Ambari Stack | 远期规划，不进入第一阶段主线 | Ambari Stack 设计、工程节奏 |
| ADR-008 | 实时数据湖主线 | Iceberg + Flink 作为主线，Hudi 作为可选 Profile | 实时数据湖设计、组件矩阵 |
| ADR-009 | 对象存储 | 第三阶段引入 S3 兼容对象存储 | 实时数据湖、云原生、存储设计 |
| ADR-010 | Agent 工作流 | 采用 Agent + Review 的并行工作流 | 路线图、任务拆分、评审流程 |
| ADR-011 | 第一阶段目标 OS | Ubuntu 22.04 | Bigtop 构建、Ambari 安装、运维脚本 |
| ADR-012 | 第一阶段 JDK | JDK 8，预留 JDK 17 兼容评估 | 组件版本矩阵、构建兼容性 |
| ADR-013 | Ambari 来源 | 优先使用最新可维护的社区/发行版最新兼容版本 | Ambari 安装、兼容性验证 |
| ADR-014 | HBase 验证范围 | HBase 进入第一阶段真实验证范围 | 部署拓扑、测试、运维 |
| ADR-015 | HA 验证规模 | 3 Master + 3 Worker + 1 Gateway | 资源规划、验收标准 |
| ADR-016 | Kerberos | 第一阶段设计保留，不默认启用 | 安全设计、实施复杂度 |
| ADR-017 | 交付形态 | Bigtop 包仓库 + Ambari Blueprint + Runbook + Smoke Test | 私有化交付、验收闭环 |

## 3. 核心架构影响

### 3.1 第一阶段从“基础 Hadoop”升级为“HA 传统数仓底座”

第一阶段不再只是最小验证集群，而是需要完成传统数仓物理机底座的 HA 生产拓扑设计，并形成可验证的 HA 目标方案。

第一阶段核心组件：

```text
Ambari
Bigtop
ZooKeeper
HDFS
YARN
Hive Metastore
HiveServer2
Spark
HBase
```

### 3.2 Ambari 是传统大数据长期管理面

Ambari 不再只被定义为第一阶段过渡工具，而是传统 Hadoop / 数仓 / 物理机 / 虚拟机部署形态下的长期管理面。

远期容器平台阶段，Ambari 与 Kubernetes / Operator 形成混合管理架构：

```text
Ambari 管理传统 Hadoop 底座
Kubernetes / Operator 管理云原生实时计算与查询组件
```

### 3.3 Bigtop 进入真实构建体系

Bigtop 不再只是参考体系，而是需要承担真实组件构建、包管理、版本矩阵和仓库发布职责。

第一阶段构建基线：

```text
OS: Ubuntu 22.04
JDK: JDK 8
Compatibility Evaluation: JDK 17
Delivery: Bigtop package repository
```

### 3.4 实时数据湖主线明确

实时数据湖阶段主线确定为：

```text
CDC -> Kafka -> Flink -> Iceberg -> S3/HDFS -> Trino/Spark SQL
```

其中：

- Flink 是实时计算主引擎
- Iceberg 是默认湖仓表格式
- Hudi 是可选 Profile
- 第三阶段引入 S3 兼容对象存储

### 3.5 第一阶段验证规模明确

第一阶段 HA 验证环境规模为：

```text
3 Master + 3 Worker + 1 Gateway
```

验证重点包括：

- Ambari 管理面可用
- HDFS HA
- YARN HA
- Hive Metastore / HiveServer2 多实例
- Spark History Server
- HBase Master / RegionServer
- Bigtop 包仓库到 Ambari 安装链路
- Runbook 与 Smoke Test 验收闭环

## 4. 当前仍待后续细化的问题

以下问题不再阻塞总体方向，但需要在 Phase 1 专项设计中细化：

| 编号 | 问题 | 归属文档 |
|---|---|---|
| DETAIL-001 | Ubuntu 22.04 下 Ambari 最新可维护版本选择与安装方式 | `ambari-management-plane.md` |
| DETAIL-002 | JDK 8 与 JDK 17 兼容性矩阵 | `version-matrix.md` |
| DETAIL-003 | HBase HA 验证细节与运维 Runbook | `hbase-design.md` |
| DETAIL-004 | 3M3W1G 的硬件规格、端口、磁盘规划 | `phase1-ha-design.md` |
| DETAIL-005 | Kerberos 后续启用路径 | `security-design.md` |
| DETAIL-006 | Bigtop 包仓库发布与 Ambari Repository 对接细节 | `bigtop-build-design.md` |

## 5. 后续修订要求

根据本决策记录，需要同步修订或新增：

- `platform-overview.md`
- `roadmap.md`
- `component-matrix.md`
- `deployment-design.md`
- `ambari-management-plane.md`
- `ambari-bigtop-integration.md`
- `phase1-ha-design.md`
- `bigtop-build-design.md`
- `hbase-design.md`
- `phase1-acceptance-criteria.md`

## 6. 执行原则

后续所有 Agent 和工程任务必须遵循本决策记录。若需要变更上述决策，应新增 ADR 记录并经过 Review Agent 收敛。
