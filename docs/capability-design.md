# Bigdata Platform Capability 设计

## 1. 文档目标

本文档定义 Bigdata Platform 的 Capability 抽象、能力分类、能力到组件的映射、能力组合、能力 Profile 和与 Stack、Service Pack、Dependency Graph、Deployment Intent 的关系。

Capability 是 Foundation Layer 的第一层声明式模型，用于表达用户真正需要的平台能力，而不是直接暴露底层组件。

## 2. 背景

用户通常不会直接表达：

```text
我要 Hive + Metastore + Tez + HDFS + YARN
```

而会表达：

```text
我要传统数仓
我要离线批处理
我要低延迟宽表存储
我要实时数据湖
```

因此平台需要把用户能力诉求抽象成 Capability，再由 Platform Core 推导底层 Stack、Service Pack、依赖图和部署计划。

## 3. Capability 定义

Capability 表示平台对外提供的一类能力。

```text
Capability = User Intent + Component Mapping + Dependency Mapping + Validation Rules
```

Capability 不是组件，也不是 Service Pack。

它是用户视角的能力抽象。

## 4. Capability 与组件的关系

```text
Capability
  -> Stack
  -> Service Pack
  -> Component / Runtime
  -> Role
```

示例：

```text
SQL Warehouse
  -> Hive
  -> Hive Metastore
  -> HiveServer2
  -> Tez Runtime
  -> HDFS
  -> YARN
```

## 5. BIGDATA-1.0 Capability 清单

BIGDATA-1.0 面向传统数仓物理机 HA 底座。

| Capability | 说明 | 主要组件 |
|---|---|---|
| Coordination | 分布式协调能力 | ZooKeeper |
| Distributed Storage | 分布式文件存储 | HDFS |
| Resource Scheduling | 资源调度能力 | YARN |
| SQL Warehouse | 数仓 SQL 能力 | Hive、Metastore、HiveServer2、Tez |
| Batch Compute | 离线批处理能力 | Spark、YARN、HDFS |
| Low Latency Storage | 低延迟宽表存储 | HBase、HDFS、ZooKeeper |
| Client Gateway | 客户端访问入口 | Hadoop Client、Hive Client、Spark Client、HBase Client |
| Monitoring Basic | 基础监控能力 | Ambari Metrics |

## 6. BIGDATA-2.0 Capability 规划

BIGDATA-2.0 面向实时数据湖。

| Capability | 说明 | 候选组件 |
|---|---|---|
| Streaming Ingestion | 实时数据接入 | Kafka / Pulsar |
| Real-Time Compute | 实时计算 | Flink |
| Lakehouse Table Format | 数据湖表格式 | Iceberg / Hudi / Delta |
| Interactive Query | 交互式查询 | Trino / Presto |
| Object Storage | 对象存储兼容能力 | S3 Compatible Storage |
| Stream SQL | 流式 SQL | Flink SQL |
| Data Governance | 数据治理 | Ranger / Atlas |

## 7. Capability Profile

Capability 可以组合成 Profile。

### 7.1 warehouse-ha-foundation

传统数仓 HA 底座。

```yaml
profile: warehouse-ha-foundation
capabilities:
  - coordination
  - distributed-storage
  - resource-scheduling
  - sql-warehouse
  - batch-compute
  - low-latency-storage
  - client-gateway
  - monitoring-basic
```

### 7.2 warehouse-basic

轻量数仓验证环境。

```yaml
profile: warehouse-basic
capabilities:
  - coordination
  - distributed-storage
  - resource-scheduling
  - sql-warehouse
  - batch-compute
```

### 7.3 lakehouse-realtime-foundation

未来实时数据湖底座。

```yaml
profile: lakehouse-realtime-foundation
capabilities:
  - distributed-storage
  - object-storage
  - streaming-ingestion
  - real-time-compute
  - lakehouse-table-format
  - interactive-query
```

## 8. Capability 到 Service Pack 的映射

| Capability | Required Service Packs | Runtime / Optional |
|---|---|---|
| Coordination | zookeeper |  |
| Distributed Storage | hdfs |  |
| Resource Scheduling | yarn |  |
| SQL Warehouse | hive, hdfs, yarn | tez |
| Batch Compute | spark, yarn, hdfs | hive-metastore-client |
| Low Latency Storage | hbase, hdfs, zookeeper | hbase-client |
| Client Gateway | hadoop-client, hive-client, spark-client, hbase-client |  |
| Monitoring Basic | ambari-metrics |  |

## 9. Capability 依赖

Capability 之间也存在依赖。

示例：

```text
SQL Warehouse
  depends_on Distributed Storage
  depends_on Resource Scheduling
  optional Runtime Tez
```

```text
Low Latency Storage
  depends_on Distributed Storage
  depends_on Coordination
```

```text
Batch Compute
  depends_on Resource Scheduling
  depends_on Distributed Storage
  optional SQL Warehouse Metadata
```

## 10. Capability 解析流程

```text
1. User selects Capability Profile
2. Capability Engine expands capabilities
3. Stack Engine selects supported components
4. Service Pack Engine loads required service packs
5. Dependency Graph Engine calculates dependency graph
6. Deployment Intent Engine maps roles to topology
7. Lifecycle Engine generates execution plan
8. Backend Adapter executes through Ambari / Kubernetes
```

## 11. Capability Engine 职责

Capability Engine 是 Platform Core 的一部分。

职责：

- 加载 Capability 定义
- 解析 Capability Profile
- 展开 Capability 依赖
- 映射到 Stack 组件
- 映射到 Service Pack
- 输出 Capability Runtime Model

## 12. Capability Runtime Model

示例：

```yaml
capabilityRuntime:
  profile: warehouse-ha-foundation
  capabilities:
    sql-warehouse:
      services:
        - hive
        - hdfs
        - yarn
      runtimes:
        - tez
    batch-compute:
      services:
        - spark
        - yarn
        - hdfs
    low-latency-storage:
      services:
        - hbase
        - hdfs
        - zookeeper
```

## 13. Capability 与 Deployment Intent 的关系

Capability 表达“需要什么能力”。

Deployment Intent 表达“如何部署这些能力”。

示例：

```yaml
capabilities:
  - sql-warehouse
  - batch-compute
  - low-latency-storage

deployment:
  profile: 3m3w1g-ha
  target: bare-metal
```

Platform Core 根据两者生成 Deployment Blueprint。

## 14. Capability 与 Release 的关系

Release Manifest 必须记录 Capability Profile。

示例：

```yaml
release: BIGDATA-1.0.0
capabilityProfile: warehouse-ha-foundation
capabilities:
  - coordination
  - distributed-storage
  - resource-scheduling
  - sql-warehouse
  - batch-compute
  - low-latency-storage
```

这样客户和交付团队可以理解该 Release 提供哪些能力，而不是只看到组件列表。

## 15. Capability 验收

每个 Capability 必须有验收标准。

| Capability | 验收方式 |
|---|---|
| Distributed Storage | HDFS 文件读写 Smoke Test |
| Resource Scheduling | YARN 任务提交 Smoke Test |
| SQL Warehouse | Hive SQL 建库建表查询 |
| Batch Compute | Spark Job / Spark SQL |
| Low Latency Storage | HBase put/get/scan |
| Coordination | ZooKeeper 集群状态检查 |
| Client Gateway | Gateway 客户端访问验证 |

## 16. 当前不做事项

BIGDATA-1.0 当前不做：

- Capability UI
- 自动推荐组件组合
- 多组件替代决策，例如 Hive vs Trino
- 完整实时数据湖 Capability 落地
- AI/ML 平台能力抽象

当前目标是定义基础 Capability Model。

## 17. 后续文档

建议继续补：

- `docs/environment-design.md`
- `docs/deployment-intent-design.md`
- `docs/deployment-blueprint-design.md`
- `docs/lifecycle-design.md`
