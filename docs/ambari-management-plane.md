# Apache Ambari 管理面设计

## 1. 文档目标

本文档用于说明 `bigdata` 项目中基于 Apache Ambari 构建大数据集群管理面的设计思路、管理对象、核心能力、目录规划和后续演进方向。

在本项目中，Ambari 被定位为 Hadoop 生态集群的统一管理面，负责集群安装、服务配置、组件启停、健康检查、监控告警和自动化运维入口。

## 2. 管理面定位

Ambari 位于基础设施与 Hadoop 生态组件之上，承担控制面和管理面的职责。

```text
┌────────────────────────────────────────────┐
│              Apache Ambari 管理面           │
│                                            │
│  Web UI / REST API / 配置管理 / 监控 / 告警  │
└────────────────────────────────────────────┘
                    |
                    v
┌────────────────────────────────────────────┐
│              Hadoop 生态组件层              │
│                                            │
│  HDFS / YARN / Hive / HBase / Spark / Kafka │
└────────────────────────────────────────────┘
                    |
                    v
┌────────────────────────────────────────────┐
│              基础设施与主机资源             │
│                                            │
│  VM / Bare Metal / Linux Hosts / Network    │
└────────────────────────────────────────────┘
```

Ambari 负责“管集群”，Hadoop 生态组件负责“跑数据”。

## 3. 适用场景

Ambari 适合用于传统 Hadoop 生态集群的集中化管理，尤其适用于以下场景：

- 多节点 Hadoop 集群安装与初始化
- HDFS、YARN、Hive、HBase、ZooKeeper、Spark 等组件统一管理
- 服务配置集中化与变更管理
- 服务启停、重启、健康检查与维护模式
- 主机、服务和组件状态监控
- 告警规则配置与事件追踪
- 通过 REST API 接入自动化脚本和 CI 流程

## 4. 管理对象模型

Ambari 管理面中的核心对象可以抽象为：

```text
Cluster
  ├── Host
  ├── Service
  │   ├── Component
  │   └── Configuration
  ├── Alert
  ├── Stack
  ├── Blueprint
  └── User / Role
```

### 4.1 Cluster

表示一个完整的大数据集群，是 Ambari 的最高级管理对象。

### 4.2 Host

表示集群中的物理机或虚拟机节点。Ambari Agent 部署在各个 Host 上，用于接收 Ambari Server 的操作指令并上报状态。

### 4.3 Service

表示一个大数据服务，例如 HDFS、YARN、Hive、HBase、ZooKeeper、Spark、Kafka 等。

### 4.4 Component

表示服务中的具体角色，例如：

- HDFS: NameNode、DataNode、SecondaryNameNode
- YARN: ResourceManager、NodeManager、Timeline Server
- Hive: HiveServer2、Hive Metastore
- ZooKeeper: ZooKeeper Server
- Spark: Spark History Server

### 4.5 Configuration

表示服务配置集合，例如 `hdfs-site.xml`、`core-site.xml`、`yarn-site.xml`、`hive-site.xml` 等。

### 4.6 Alert

表示服务、组件、主机、端口、进程、资源指标等维度的告警规则与告警事件。

### 4.7 Blueprint

表示集群安装模板，可用于声明式定义集群拓扑、服务组件分布和基础配置。

## 5. 核心能力设计

### 5.1 集群初始化

通过 Ambari Web UI 或 Blueprint 完成集群初始化，包括：

- 主机注册
- Agent 安装
- 服务选择
- 角色分配
- 参数配置
- 服务安装
- 服务启动
- 服务检查

### 5.2 服务生命周期管理

Ambari 统一管理服务生命周期：

```text
Install -> Start -> Stop -> Restart -> Service Check -> Maintenance Mode
```

服务操作需要考虑依赖顺序，例如：

```text
ZooKeeper -> HDFS -> YARN -> Hive / HBase / Spark
```

### 5.3 配置管理

Ambari 负责集中管理组件配置，并在配置变更后标记需要重启的服务。

配置管理应覆盖：

- HDFS 存储配置
- YARN 资源调度配置
- Hive Metastore 与 HiveServer2 配置
- HBase RegionServer 与 Master 配置
- Spark History Server 配置
- ZooKeeper 集群配置
- Kerberos 与安全相关配置

### 5.4 监控与告警

Ambari 管理面应提供以下可观测能力：

- 集群整体健康状态
- 主机 CPU、内存、磁盘、网络状态
- 服务与组件运行状态
- HDFS 容量与块状态
- YARN 队列与资源使用情况
- 告警规则与告警历史
- 服务检查结果

### 5.5 自动化运维

通过 Ambari REST API，可以将管理动作接入脚本、CI 或外部平台。

典型自动化场景：

- 自动创建集群
- 自动安装服务
- 自动修改配置
- 自动重启受影响服务
- 自动获取集群健康状态
- 自动生成巡检报告
- 自动执行服务检查

## 6. 与 bigdata 仓库的关系

`bigdata` 仓库负责沉淀大数据平台的技术资产，Ambari 负责提供 Hadoop 生态集群管理面。

```text
bigdata/
├── docs/
│   ├── technical-design.md
│   ├── ambari-management-plane.md
│   ├── deployment.md
│   └── operations.md
├── apache-bigtop/
├── ambari/
│   ├── blueprints/
│   ├── configs/
│   ├── scripts/
│   └── runbooks/
├── examples/
└── tests/
```

建议职责划分：

| 目录 | 说明 |
|---|---|
| `docs/` | 架构设计、部署设计、运维手册 |
| `ambari/blueprints/` | Ambari Blueprint 集群模板 |
| `ambari/configs/` | Hadoop 组件配置模板 |
| `ambari/scripts/` | Ambari REST API 自动化脚本 |
| `ambari/runbooks/` | 运维流程、扩容、重启、故障恢复手册 |
| `apache-bigtop/` | Bigtop 相关打包、测试与部署资源 |

## 7. Ambari 与 Kubernetes 的边界

Ambari 和 Kubernetes 都可以承担管理能力，但管理对象不同。

| 维度 | Apache Ambari | Kubernetes |
|---|---|---|
| 管理对象 | Hadoop 生态服务 | 容器、Pod、Service、Operator |
| 部署形态 | VM / 裸金属为主 | 容器为主 |
| 强项 | Hadoop 组件安装、配置、监控、告警 | 云原生调度、弹性伸缩、声明式编排 |
| 适合组件 | HDFS、YARN、Hive、HBase、ZooKeeper | Spark Operator、Flink Operator、Trino、Kafka Operator |
| 操作方式 | Web UI + REST API | YAML + API + Controller |

建议第一阶段使用 Ambari 管理传统 Hadoop 集群，后续根据需要引入 Kubernetes 管理云原生计算和服务。

## 8. 演进路线

### 第一阶段：Ambari 基础管理面

- 建立 Ambari Server / Agent 管理模型
- 完成 HDFS、YARN、Hive、ZooKeeper 等基础服务管理
- 沉淀 Blueprint 与配置模板
- 补充服务启停、巡检、故障恢复 runbook

### 第二阶段：自动化与工程化

- 使用 Ambari REST API 编写自动化脚本
- 接入 GitHub 管理配置和脚本版本
- 建立配置变更、服务重启、健康检查标准流程
- 输出标准化部署手册

### 第三阶段：平台化增强

- 补充 Kafka、Spark、Flink、HBase 等组件管理
- 引入监控指标统一展示
- 引入权限、安全、Kerberos 配置规范
- 与 CI/CD、运维平台或内部控制台集成

### 第四阶段：云原生融合

- 传统 Hadoop 集群继续由 Ambari 管理
- 云原生计算任务逐步接入 Kubernetes
- 形成 Ambari + Kubernetes 的混合管理架构

## 9. 后续待办

- [ ] 新增 Ambari Blueprint 示例
- [ ] 新增 HDFS / YARN / Hive 配置模板
- [ ] 新增 Ambari REST API 操作脚本
- [ ] 新增集群安装 runbook
- [ ] 新增服务重启与故障恢复 runbook
- [ ] 新增 Ambari 与 Bigtop 集成说明
