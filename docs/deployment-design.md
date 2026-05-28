# Bigdata Platform 部署设计

## 1. 文档目标

本文档用于定义 Bigdata Platform 在不同基础设施形态下的部署模型、节点角色、网络与存储要求、环境分层和演进路径。

平台目标是同时支持传统数仓与实时数据湖，并具备从物理机到虚拟机、再到容器平台的演进能力。

## 2. 部署形态分层

| 阶段 | 部署形态 | 主要目标 | 管理方式 |
|---|---|---|---|
| Phase 1 | 物理机 | 传统数仓底座、HA 生产拓扑、私有化交付 | Ambari |
| Phase 4 | 虚拟机 | 多环境复制、资源隔离、交付标准化 | Ambari + 自动化初始化 |
| Phase 5 | 容器平台 | 云原生实时数据湖与弹性计算 | Kubernetes / Operator + Ambari 协同 |

第一阶段优先支持物理机部署，并要求完成 HA 生产拓扑设计与验证目标。

## 3. 第一阶段：物理机部署模型

### 3.1 最小验证集群

用于开发、演示、方案验证。

```text
1 Master + 2 Worker
```

| 节点 | 角色 | 组件 |
|---|---|---|
| master-01 | 管理与主控 | Ambari Server、NameNode、ResourceManager、Hive Metastore、HiveServer2、Spark History Server、HBase Master、ZooKeeper |
| worker-01 | 数据与计算 | DataNode、NodeManager、HBase RegionServer |
| worker-02 | 数据与计算 | DataNode、NodeManager、HBase RegionServer |

### 3.2 第一阶段 HA 生产推荐集群

用于第一阶段生产化设计基线。

```text
3 Master + N Worker + M Gateway
```

| 节点类型 | 数量 | 主要职责 |
|---|---:|---|
| Master | 3 | Ambari、ZooKeeper、NameNode HA、ResourceManager HA、Hive Metastore、HiveServer2、HBase Master |
| Worker | N | HDFS DataNode、YARN NodeManager、HBase RegionServer、计算执行 |
| Gateway | M | 客户端接入、作业提交、SQL 访问、运维入口 |

### 3.3 HA 角色分布建议

| 组件 | Master | Worker | Gateway |
|---|---|---|---|
| Ambari Server | 是，主实例 | 否 | 否 |
| Ambari Agent | 是 | 是 | 是 |
| ZooKeeper | 是，3 节点 | 否 | 否 |
| HDFS NameNode | 是，Active/Standby | 否 | 否 |
| HDFS JournalNode | 是，3 节点 | 否 | 否 |
| HDFS DataNode | 否 | 是 | 否 |
| YARN ResourceManager | 是，Active/Standby | 否 | 否 |
| YARN NodeManager | 否 | 是 | 否 |
| Hive Metastore | 是，多实例 | 否 | 可选 |
| HiveServer2 | 是/网关，多实例 | 否 | 是 |
| Spark History Server | 是 | 否 | 可选 |
| HBase Master | 是，Active/Standby | 否 | 否 |
| HBase RegionServer | 否 | 是 | 否 |
| Client 工具 | 可选 | 可选 | 是 |

## 4. 网络设计

### 4.1 网络分区

建议逻辑上区分：

- 管理网络：Ambari、SSH、监控、运维访问
- 数据网络：HDFS 数据传输、Shuffle、HBase Region 访问、服务间通信
- 访问网络：SQL、BI、API、任务提交入口

第一阶段可以共用物理网络，但文档和配置上应保留分区设计。

### 4.2 基础要求

- 节点间主机名可解析
- 节点间时间同步
- 节点间必要端口互通
- 管理节点可访问所有 Agent 节点
- Gateway 节点可访问集群服务入口
- Master 节点之间网络稳定，满足 HA 组件心跳和选主需求

## 5. 存储设计

### 5.1 HDFS 存储

Worker 节点承载 HDFS DataNode。生产环境建议：

- 独立数据盘挂载 HDFS 数据目录
- 系统盘与数据盘分离
- 多数据盘使用独立挂载目录
- 定期检查磁盘容量与坏盘风险

示例：

```text
/data1/hdfs/data
/data2/hdfs/data
/data3/hdfs/data
```

### 5.2 HBase 存储

HBase 基于 HDFS 存储数据，但需要额外关注：

- RegionServer 数据访问延迟
- HDFS 与 HBase Region 分布
- HBase WAL 写入性能
- ZooKeeper 稳定性
- Region 热点与 split 策略

### 5.3 元数据存储

NameNode、Hive Metastore、Ambari Server、HBase Master 等元数据服务应独立规划磁盘与备份策略。

### 5.4 实时数据湖存储演进

实时数据湖阶段需要同时支持：

- HDFS
- S3 兼容对象存储
- 湖仓表格式数据目录
- Checkpoint / Savepoint 存储

## 6. 环境模型

建议至少定义以下环境：

| 环境 | 用途 | 特点 |
|---|---|---|
| dev | 开发验证 | 小规模、低成本、频繁变更 |
| test | 集成测试 | 模拟生产拓扑，验证部署与升级 |
| staging | 预生产 | 接近生产配置，验证发布流程 |
| prod | 生产 | 高可用、稳定、严格变更控制 |

## 7. 部署交付流程

```text
基础设施准备
  -> OS 初始化
  -> 网络与主机名配置
  -> 时间同步
  -> Bigtop 构建组件包
  -> 发布内部 yum/apt 仓库
  -> Ambari Server / Agent 安装
  -> Repository 配置
  -> Blueprint / Install Wizard
  -> 服务安装与启动
  -> HA 配置与验证
  -> Service Check
  -> Smoke Test
  -> 运维验收
```

## 8. 与 Ambari 的关系

第一阶段由 Ambari 承担传统大数据管理面职责：

- 主机注册
- 组件安装
- 配置分发
- 服务启停
- HA 配置管理
- 服务检查
- 告警与状态展示

Ambari 不是短期过渡工具，而是传统 Hadoop / 物理机 / 虚拟机部署形态下的长期管理面。

## 9. 与 Bigtop 的关系

Bigtop 作为真实构建体系，用于提供组件包、版本矩阵和仓库来源。Ambari 通过 Repository 配置消费这些包。

第一阶段 Bigtop 需要覆盖：

- Hadoop
- Hive
- Spark
- HBase
- ZooKeeper 相关依赖

## 10. 后续演进

### 10.1 虚拟机部署

虚拟机阶段重点是标准化镜像、环境复制、多环境隔离和自动化初始化。

### 10.2 容器平台部署

容器阶段重点是将 Spark、Flink、Kafka、Trino 等组件逐步迁移到 Kubernetes / Operator 模式。

### 10.3 混合部署

远期可能形成：

```text
Ambari 管理传统 Hadoop 底座
Kubernetes 管理实时计算与云原生服务
统一文档与交付体系管理平台能力
```

## 11. 后续待办

- [ ] 补充物理机规格推荐
- [ ] 补充端口清单
- [ ] 补充磁盘容量规划模板
- [ ] 补充 HA 部署拓扑细节
- [ ] 补充 HBase 部署与运维设计
- [ ] 补充虚拟机部署设计
- [ ] 补充容器平台部署设计
