# Bigdata 技术设计文档

## 1. 文档目标

本文档用于沉淀 `bigdata` 仓库中的大数据技术体系、组件选型、部署架构、工程规范与后续演进计划，便于研发、测试、部署和运维协同。

## 2. 背景与范围

当前仓库定位为大数据生态项目的资料、方案与实践沉淀，已在 README 中引用 Apache Bigtop 相关内容。本文档后续可围绕以下方向持续完善：

- Hadoop / HDFS / YARN 基础平台
- Hive / Spark / Flink 等计算与 SQL 引擎
- Kafka / CDC / 数据同步链路
- Iceberg / Hudi / Delta Lake 等湖仓表格式
- 调度、监控、权限、安全与运维体系
- 云原生大数据平台与 Kubernetes 集成

## 3. 总体架构

```text
Data Sources
    |
    v
Ingestion Layer
    - CDC
    - Batch Import
    - Stream Collection
    |
    v
Storage Layer
    - HDFS / Object Storage
    - Lakehouse Table Format
    |
    v
Compute Layer
    - Spark
    - Flink
    - Hive / Trino
    |
    v
Serving Layer
    - BI / Dashboard
    - API Service
    - ML / AI Workloads
```

## 4. 核心模块

### 4.1 数据接入

说明批处理、实时流、CDC、日志采集等数据接入方式，并定义接入规范、幂等机制、失败重试与数据质量校验策略。

### 4.2 数据存储

说明数据湖、数据仓库、湖仓一体架构中的分层模型，例如 ODS、DWD、DWS、ADS，并定义分区、压缩、文件大小、元数据管理等规范。

### 4.3 数据计算

说明离线计算、实时计算、交互式分析的技术选型与使用边界，包括 Spark、Flink、Hive、Trino 等组件的适用场景。

### 4.4 调度与治理

说明任务调度、依赖编排、血缘追踪、权限控制、数据质量、审计日志与成本治理策略。

### 4.5 部署与运维

说明本地环境、测试环境、生产环境的部署方式，后续可补充 Kubernetes、Helm、Bigtop、Ansible 或 Terraform 等工程化方案。

## 5. 管理面设计

本项目第一阶段以 Apache Ambari 作为 Hadoop 生态集群管理面，负责集群安装、服务配置、组件启停、健康检查、监控告警和自动化运维入口。

详见：[Apache Ambari 管理面设计](ambari-management-plane.md)

## 6. 目录规划

建议仓库后续按如下结构组织：

```text
bigdata/
├── README.md
├── docs/
│   ├── technical-design.md
│   ├── ambari-management-plane.md
│   ├── architecture.md
│   ├── deployment.md
│   └── operations.md
├── apache-bigtop/
├── ambari/
│   ├── blueprints/
│   ├── configs/
│   ├── scripts/
│   └── runbooks/
├── examples/
├── scripts/
└── tests/
```

## 7. 提交规范

建议采用以下提交信息格式：

```text
docs: add bigdata technical design document
feat: add deployment scripts for xxx
fix: correct xxx configuration
chore: update repository structure
```

## 8. 后续待办

- [ ] 补充当前大数据平台的目标场景与边界
- [ ] 明确核心组件版本与兼容性矩阵
- [ ] 补充部署架构图与网络拓扑
- [ ] 补充数据链路、任务调度与监控方案
- [ ] 补充本地开发、测试与 CI 流程
- [ ] 补充 Ambari Blueprint 示例
- [ ] 补充 Ambari REST API 自动化脚本
- [ ] 补充 Ambari 与 Apache Bigtop 集成说明
