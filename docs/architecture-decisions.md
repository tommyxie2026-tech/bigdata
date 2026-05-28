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

## 3. 核心架构影响

### 3.1 第一阶段从“基础 Hadoop”升级为“HA 传统数仓底座”

第一阶段不再只是最小验证集群，而是需要完成传统数仓物理机底座的 HA 生产拓扑设计，并至少形成可验证的 HA 目标方案。

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

后续必须补充：

- 目标 OS
- 目标 JDK
- 组件版本矩阵
- 构建流程
- 包仓库发布流程
- Ambari Repository 对接方式

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

## 4. 仍待确认的问题

以下问题尚未确认，需要进入下一轮评审：

| 编号 | 问题 | 影响 |
|---|---|---|
| OPEN-001 | 第一阶段目标 OS 是 Rocky 8/9、CentOS 7、Ubuntu、openEuler 还是多 OS？ | Bigtop 构建与部署脚本 |
| OPEN-002 | 第一阶段目标 JDK 是 8、11 还是双版本？ | Hadoop/Hive/Spark/Ambari 兼容性 |
| OPEN-003 | Ambari 使用社区版本、发行版版本，还是自行维护构建？ | 安装流程、Stack 兼容性 |
| OPEN-004 | HBase 是否进入第一阶段 HA 验证范围，还是只进入设计范围？ | 部署拓扑、运维复杂度 |
| OPEN-005 | 第一阶段 HA 验证环境规模是多少？ | 资源规划与验收 |
| OPEN-006 | 是否第一阶段引入 Kerberos？ | 安全复杂度 |
| OPEN-007 | 私有化交付的目标形态是脚本+文档，还是包仓库+自动化部署？ | 交付边界 |

## 5. 后续修订要求

根据本决策记录，需要同步修订：

- `platform-overview.md`
- `roadmap.md`
- `component-matrix.md`
- `deployment-design.md`
- `ambari-management-plane.md`
- `ambari-bigtop-integration.md`
- `realtime-lakehouse-design.md`
- `design-review.md`

## 6. 执行原则

后续所有 Agent 和工程任务必须遵循本决策记录。若需要变更上述决策，应新增 ADR 记录并经过 Review Agent 收敛。
