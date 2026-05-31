# Bigdata Platform Stack 设计

## 1. 文档目标

本文档定义 Bigdata Platform 的 Stack 抽象、版本体系、组件边界、演进路径和与 Service Pack、Repository、Blueprint、Lifecycle 的关系。

Stack 是 Bigdata Platform 的核心产品抽象，用于描述一组可被统一构建、安装、管理、验证和升级的大数据组件集合。

## 2. Stack 定义

Stack 用于表达一个平台版本中的组件集合、组件版本、依赖关系、管理方式和交付 Profile。

```text
Stack = Platform Version + Component Set + Version Matrix + Service Packs + Repository + Blueprints + Lifecycle Rules
```

Stack 不是简单的组件列表，而是平台交付的最小产品单元。

## 3. Stack 命名规范

建议采用：

```text
BIGDATA-<major>.<minor>
```

示例：

| Stack | 定位 |
|---|---|
| BIGDATA-1.0 | Phase 1 传统数仓物理机 HA 底座 |
| BIGDATA-1.1 | Phase 1 增强版，补充安全、运维、更多 Profile |
| BIGDATA-2.0 | 实时数据湖扩展，加入 Kafka / Flink / Iceberg / Trino |
| BIGDATA-3.0 | 云原生与混合管理面，加入 Kubernetes / Operator |

## 4. BIGDATA-1.0 范围

BIGDATA-1.0 对应 Phase 1：传统数仓物理机 HA 底座。

### 4.1 基础环境

| 项目 | 值 |
|---|---|
| OS | Ubuntu 22.04 |
| 默认 JDK | JDK 8 |
| JDK 兼容评估 | JDK 17 |
| 管理面 | Ambari 3.0.0 候选，2.7.9 回退 |
| 构建体系 | Bigtop 3.5.0 候选，3.4.0 回退 |
| 验证规模 | 3 Master + 3 Worker + 1 Gateway |

### 4.2 组件集合

| 组件 | 候选版本 | 角色 |
|---|---:|---|
| Ambari | 3.0.0 | 管理面 |
| Ambari Metrics | 3.0.0 | 指标采集与展示 |
| Bigtop | 3.5.0 | 构建与包仓库体系 |
| Hadoop | 3.5.0 | HDFS / YARN 底座 |
| ZooKeeper | 3.9.5 | 分布式协调 |
| Hive | 4.2.0 | SQL 与数仓服务 |
| Hive Standalone Metastore | 4.2.0 | 元数据服务 |
| Tez | 0.10.5 | Hive 执行引擎候选 |
| Spark | 3.5.8 | 批处理与离线 SQL 补充 |
| HBase | 2.5.14 | 宽表存储 |

所有版本当前状态均为：

```text
已确认候选，不冻结，待验证
```

## 5. BIGDATA-1.0 Profile

### 5.1 warehouse-ha-foundation

生产级传统数仓 HA 底座。

```text
Ambari
Bigtop Repo
ZooKeeper 3 节点
HDFS HA
YARN HA
Hive Metastore 多实例
HiveServer2 多实例
Spark on YARN
HBase Master / RegionServer
Gateway Client
```

### 5.2 warehouse-basic

轻量验证环境。

```text
Ambari
ZooKeeper
HDFS
YARN
Hive
Spark
HBase，可选
```

### 5.3 warehouse-client-gateway

面向客户端接入的 Gateway Profile。

```text
Hadoop Client
Hive Client
Spark Client
HBase Client
运维入口
```

## 6. Stack 与 Service Pack 的关系

Stack 负责声明组件集合，Service Pack 负责声明单个组件如何安装、配置、启动、检查和运维。

```text
BIGDATA-1.0
  ├── service-pack/hdfs
  ├── service-pack/yarn
  ├── service-pack/zookeeper
  ├── service-pack/hive
  ├── service-pack/spark
  └── service-pack/hbase
```

新增组件时，原则上应新增 Service Pack，而不是修改平台核心逻辑。

## 7. Stack 与 Repository 的关系

Stack 的版本矩阵必须对应明确的包仓库。

```text
BIGDATA-1.0
  -> Bigtop Build
  -> Platform apt Repository
  -> Ambari Repository Config
  -> Cluster Install
```

Repository 需要支持：

- 主候选版本
- 回退版本
- 仓库快照
- 离线交付
- 客户环境镜像

## 8. Stack 与 Blueprint 的关系

Blueprint 是 Stack 在具体拓扑下的部署表达。

```text
Stack = 组件和版本集合
Blueprint = 组件在节点上的角色分布
```

示例：

| Blueprint | 说明 |
|---|---|
| single-node | 单机验证 |
| 3m3w1g-ha | Phase 1 标准 HA 验证拓扑 |
| production-ha | 生产推荐拓扑 |
| gateway-only | 仅客户端节点 |

## 9. Stack 与 Lifecycle 的关系

Stack 中每个 Service Pack 必须支持统一生命周期模型：

```text
Install
Configure
Start
Stop
Restart
Service Check
Upgrade
Rollback
Remove
```

BIGDATA-1.0 第一阶段重点覆盖：

- Install
- Configure
- Start
- Stop
- Restart
- Service Check

Upgrade / Rollback 先进入设计保留，待版本冻结后逐步实现。

## 10. Stack 演进路径

### 10.1 BIGDATA-1.0

传统数仓物理机 HA 底座。

```text
HDFS + YARN + Hive + Spark + HBase + ZooKeeper
```

### 10.2 BIGDATA-2.0

实时数据湖扩展。

```text
Kafka + Flink + Iceberg + Trino + S3 Compatible Object Storage
```

### 10.3 BIGDATA-3.0

云原生与混合管理面。

```text
Ambari + Kubernetes + Operator
Spark on Kubernetes
Flink Kubernetes Operator
Kafka Operator
Trino on Kubernetes
```

## 11. Stack 冻结规则

一个 Stack 版本冻结需要满足：

- 版本矩阵冻结
- Repository 可用
- Blueprint 可用
- Service Check 通过
- Smoke Test 通过
- HA 验证通过
- Runbook 可执行
- Blocker / Critical 缺陷清零

## 12. 当前不做事项

BIGDATA-1.0 当前不做：

- 完整自研控制台
- 完整自定义 Ambari Stack 生产实现
- Kubernetes Operator 实现
- 实时数据湖组件落地
- Kerberos 默认启用
- Ranger / Knox / Atlas 默认启用

## 13. 后续文档

Stack 设计之后需要继续补：

- `docs/service-pack-design.md`
- `docs/repository-design.md`
- `docs/blueprint-design.md`
- `docs/lifecycle-design.md`
