# 实时数据湖设计

## 1. 文档目标

本文档用于定义 Bigdata Platform 实时数据湖能力的设计边界、核心组件、数据链路、部署形态、治理要求和阶段计划。

实时数据湖不是第一阶段主线实现内容，而是平台第三阶段的重要扩展方向。本文档先完成设计规划，避免后续组件接入时缺少统一架构边界。

## 2. 设计定位

实时数据湖用于支持从业务数据库、日志系统、消息队列等数据源持续接入数据，通过流式计算写入湖仓表格式，并提供近实时分析能力。

典型目标：

- 支持 CDC 实时入湖
- 支持流式清洗与宽表加工
- 支持 Iceberg / Hudi 等湖仓表格式
- 支持 Hive Metastore 统一元数据
- 支持 Trino / Spark SQL 近实时查询
- 支持实时链路监控、延迟观测与质量校验

## 3. 总体架构

```text
Business DB / Logs / Events
        |
        v
CDC Connector / Log Collector
        |
        v
Kafka
        |
        v
Flink / Spark Streaming
        |
        v
Iceberg / Hudi Table
        |
        v
Hive Metastore
        |
        v
Trino / Spark SQL / BI / API
```

## 4. 核心组件

| 组件 | 作用 | 阶段 |
|---|---|---|
| Kafka | 实时数据缓冲、解耦、削峰 | Phase 3 |
| CDC Connector | 捕获数据库变更 | Phase 3 |
| Flink | 实时计算、状态处理、Exactly-once 语义 | Phase 3 |
| Spark Structured Streaming | 可选流式处理能力 | Phase 3+ |
| Iceberg | 湖仓表格式，支持快照、Schema 演进、流批统一 | Phase 3 |
| Hudi | 可选湖仓表格式，偏实时 upsert 场景 | Phase 3 |
| Hive Metastore | 统一元数据管理 | Phase 1/3 |
| Trino | 交互式查询 | Phase 3 |
| Object Storage / HDFS | 数据湖存储 | Phase 3 |

## 5. 数据链路设计

### 5.1 CDC 入湖链路

```text
MySQL / PostgreSQL
        |
        v
CDC Connector
        |
        v
Kafka Topic
        |
        v
Flink Job
        |
        v
Iceberg / Hudi ODS Table
        |
        v
DWD / DWS / ADS
```

### 5.2 日志入湖链路

```text
Application Logs
        |
        v
Log Collector
        |
        v
Kafka Topic
        |
        v
Flink / Spark Streaming
        |
        v
Lakehouse Table
```

## 6. 湖仓分层模型

| 层级 | 说明 | 数据特点 |
|---|---|---|
| ODS | 原始入湖层 | 保留源端结构，尽量少加工 |
| DWD | 明细事实层 | 清洗、标准化、去重 |
| DWS | 汇总服务层 | 面向主题域聚合 |
| ADS | 应用数据层 | 面向报表、API、业务应用 |

实时数据湖应与传统数仓分层保持一致，但需要额外关注延迟、一致性、乱序、重复和补偿机制。

## 7. 表格式选型

### 7.1 Iceberg

适合：

- 流批统一
- 多引擎查询
- Schema 演进
- 分区演进
- 时间旅行
- 大规模数据湖管理

### 7.2 Hudi

适合：

- 高频 upsert
- CDC 实时写入
- 增量拉取
- 近实时表更新

### 7.3 第一选择建议

第三阶段建议优先以 Iceberg 作为默认设计对象，同时保留 Hudi 作为可选 Profile。

## 8. 元数据设计

实时数据湖阶段应复用 Hive Metastore 或兼容 Catalog，作为 Spark、Flink、Trino 之间的元数据桥梁。

后续需要明确：

- Catalog 类型
- 表命名规范
- 库层级规划
- Schema 变更策略
- 分区策略
- 快照保留策略

## 9. 一致性与质量设计

实时数据湖需要关注：

- Exactly-once 或端到端幂等
- Kafka offset 管理
- Flink Checkpoint
- Savepoint 恢复
- 主键与去重策略
- 延迟数据处理
- 乱序数据处理
- 数据补偿机制
- 源端 DDL 变更处理

## 10. 监控指标

| 维度 | 指标 |
|---|---|
| Kafka | Topic Lag、吞吐、分区状态、副本状态 |
| Flink | Checkpoint 成功率、延迟、Backpressure、重启次数 |
| CDC | 捕获延迟、错误事件、DDL 变更 |
| Lakehouse | 小文件数量、快照数量、提交失败数 |
| Query | 查询延迟、失败率、并发数 |
| Data Quality | 空值、重复、延迟、行数波动 |

## 11. 与传统数仓的关系

实时数据湖不是替代传统数仓，而是补充：

| 能力 | 传统数仓 | 实时数据湖 |
|---|---|---|
| 接入方式 | 批量导入 | CDC / 流式接入 |
| 计算方式 | 批处理 | 流处理 + 批处理 |
| 数据延迟 | 小时级 / 天级 | 秒级 / 分钟级 |
| 表格式 | Hive 表 | Iceberg / Hudi |
| 查询方式 | Hive / Spark SQL | Trino / Spark SQL |
| 管理重点 | 稳定、容量、批任务 | 延迟、一致性、状态、质量 |

## 12. 部署形态

### 12.1 物理机 / 虚拟机阶段

- Kafka、Flink 可独立部署
- HDFS 或对象存储作为湖仓底座
- Hive Metastore 复用第一阶段能力

### 12.2 容器平台阶段

- Flink Kubernetes Operator
- Kafka Operator
- Trino on Kubernetes
- Lakehouse on Object Storage
- Prometheus + Grafana 观测

## 13. 第三阶段交付物

| 文档 | 说明 |
|---|---|
| `docs/realtime-lakehouse-design.md` | 实时数据湖总体设计 |
| `docs/cdc-design.md` | CDC 接入设计 |
| `docs/kafka-design.md` | Kafka 设计 |
| `docs/flink-design.md` | Flink 设计 |
| `docs/lakehouse-table-format.md` | 表格式设计 |
| `docs/query-engine-design.md` | 查询引擎设计 |

## 14. 后续待办

- [ ] 明确默认表格式 Iceberg / Hudi 选择
- [ ] 补充 CDC 设计文档
- [ ] 补充 Kafka Topic 规划
- [ ] 补充 Flink 作业模型
- [ ] 补充 Trino 查询服务设计
- [ ] 补充实时数据质量设计
