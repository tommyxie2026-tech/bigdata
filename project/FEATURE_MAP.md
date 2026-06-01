# BIGDATA-1.0 Feature Map v1.0

## 1. 目标

本文档定义 BIGDATA-1.0 的 Feature Map，用于将用户价值、平台能力、底层组件、Epic、Issue 和验证证据建立映射关系。

Feature Map 的目标是避免 Issue Tree 只围绕组件和技术活动展开，而忽略平台最终交付的能力。

```text
User Value
  -> Feature
  -> Capability
  -> Component
  -> Epic
  -> Issue
  -> Evidence
```

## 2. Feature Map 原则

- Feature 面向用户价值，不直接等同于组件。
- Component 是 Feature 的实现手段。
- Validation 是证明 Feature 成立的证据。
- Issue 必须能追溯到 Feature。
- Release 必须说明交付了哪些 Feature。

## 3. BIGDATA-1.0 Feature 清单

| Feature ID | Feature | 用户价值 | 核心组件 | 状态 |
|---|---|---|---|---|
| F1 | Cluster Lifecycle Management | 集群安装、配置、启停、基础运维 | Ambari / Backend Adapter | Candidate |
| F2 | Distributed Storage | 分布式文件存储与数据可靠性 | HDFS / ZooKeeper | Candidate |
| F3 | Resource Scheduling | 统一资源调度与任务运行 | YARN | Candidate |
| F4 | SQL Warehouse | 数仓 SQL、元数据、离线查询 | Hive / Metastore / Tez | Candidate |
| F5 | Batch Compute | 批处理与 Spark SQL | Spark / YARN / HDFS | Candidate |
| F6 | Low Latency NoSQL Storage | 宽表、KV、低延迟读写 | HBase / HDFS / ZooKeeper | Candidate |
| F7 | Packaging & Delivery | 可构建、可发布、可离线交付 | Bigtop / apt Repository / Bundle | Candidate |
| F8 | Operations & Observability | 指标、告警、基础运维可视化 | Ambari Metrics / Alerts | Candidate |
| F9 | Validation & Release Evidence | 可审计验证与版本冻结 | Validation Framework / Reports | Candidate |

## 4. F1 Cluster Lifecycle Management

### 4.1 用户价值

用户可以安装、配置、启动、停止和检查 BIGDATA-1.0 集群。

### 4.2 目标能力

- 集群安装
- 主机注册
- Repository 导入
- 服务配置
- 服务启停
- Service Check
- 基础告警

### 4.3 实现候选

| 层级 | 候选 |
|---|---|
| Backend Plugin | Ambari 3.0.0 |
| Fallback | Ambari 2.7.9 / Native Adapter |
| Future | Kubernetes Adapter |

### 4.4 关联 Epic

- EPIC-101 Ambari Viability Review
- EPIC-402 Backend Adapter Contract
- EPIC-403 Deployment Blueprint Rendering

### 4.5 关联 Issue

- ISSUE-101 Ambari Community Review
- ISSUE-102 Ambari Ubuntu22 Validation
- ISSUE-103 Ambari JDK8 Validation
- ISSUE-104 Ambari Hadoop3.5 Compatibility
- ISSUE-105 Ambari Blueprint Validation

### 4.6 Exit Criteria

```text
Ambari 或替代 Backend 能完成最小集群安装、配置、启动和 Service Check。
```

## 5. F2 Distributed Storage

### 5.1 用户价值

提供分布式文件存储能力，支持传统数仓和计算引擎的数据底座。

### 5.2 核心组件

- HDFS
- ZooKeeper
- JournalNode
- NameNode HA
- DataNode

### 5.3 关联 Epic

- EPIC-301 Hadoop Validation
- EPIC-401 HDFS HA Validation

### 5.4 关联 Issue

- ISSUE-301 HDFS Install Validation
- ISSUE-302 HDFS Smoke Test
- ISSUE-303 HDFS HA Failover
- ISSUE-304 HDFS DataNode Validation

### 5.5 Exit Criteria

```text
HDFS 可读写，NameNode HA 可切换，DataNode 正常提供存储能力。
```

## 6. F3 Resource Scheduling

### 6.1 用户价值

提供资源调度与任务运行能力，支撑 Hive、Spark 等计算负载。

### 6.2 核心组件

- YARN ResourceManager
- YARN NodeManager
- YARN HA

### 6.3 关联 Epic

- EPIC-301 Hadoop Validation
- EPIC-402 YARN HA Validation

### 6.4 关联 Issue

- ISSUE-311 YARN Install Validation
- ISSUE-312 YARN Application Submit
- ISSUE-313 ResourceManager HA Failover
- ISSUE-314 NodeManager Validation

### 6.5 Exit Criteria

```text
YARN 可提交任务，ResourceManager HA 可切换，NodeManager 正常提供计算资源。
```

## 7. F4 SQL Warehouse

### 7.1 用户价值

提供传统数仓 SQL 能力，支持建库、建表、插入、查询和元数据管理。

### 7.2 核心组件

- Hive Metastore
- HiveServer2
- Tez Runtime
- HDFS
- YARN

### 7.3 关联 Epic

- EPIC-302 Hive Validation

### 7.4 关联 Issue

- ISSUE-321 Hive Metastore Validation
- ISSUE-322 HiveServer2 Validation
- ISSUE-323 Hive DDL Validation
- ISSUE-324 Hive DML Validation
- ISSUE-325 Hive Join Query Validation
- ISSUE-326 Tez Runtime Validation

### 7.5 Exit Criteria

```text
Hive 可完成 create database、create table、insert、select、join，Metastore 可被 Hive 和 Spark 访问。
```

## 8. F5 Batch Compute

### 8.1 用户价值

提供批处理计算能力和 Spark SQL 能力。

### 8.2 核心组件

- Spark
- Spark SQL
- Spark History Server
- YARN
- HDFS
- Hive Metastore Client

### 8.3 关联 Epic

- EPIC-303 Spark Validation

### 8.4 关联 Issue

- ISSUE-331 Spark Install Validation
- ISSUE-332 Spark Submit Validation
- ISSUE-333 Spark on YARN Validation
- ISSUE-334 Spark SQL Validation
- ISSUE-335 Spark Hive Metastore Compatibility

### 8.5 Exit Criteria

```text
Spark 可提交作业，Spark on YARN 可运行，Spark SQL 可访问 Hive Metastore。
```

## 9. F6 Low Latency NoSQL Storage

### 9.1 用户价值

提供宽表存储和低延迟读写能力。

### 9.2 核心组件

- HBase Master
- HBase RegionServer
- HDFS
- ZooKeeper

### 9.3 关联 Epic

- EPIC-304 HBase Validation
- EPIC-404 HBase HA Validation

### 9.4 关联 Issue

- ISSUE-341 HBase Install Validation
- ISSUE-342 HBase Master Validation
- ISSUE-343 HBase RegionServer Validation
- ISSUE-344 HBase Put/Get/Scan Validation
- ISSUE-345 HBase Master Failover

### 9.5 Exit Criteria

```text
HBase 可建表，支持 put/get/scan，Master Failover 有明确验证结果。
```

## 10. F7 Packaging & Delivery

### 10.1 用户价值

提供可构建、可安装、可回溯、可离线交付的包和仓库能力。

### 10.2 核心组件

- Bigtop
- DEB Package
- apt Repository
- Repository Snapshot
- Release Bundle

### 10.3 关联 Epic

- EPIC-102 Bigtop Validation
- EPIC-201 Build Lab
- EPIC-202 Repository Lab
- EPIC-501 Release Bundle

### 10.4 关联 Issue

- ISSUE-201 Bigtop Build Environment
- ISSUE-202 Bigtop Hadoop Build
- ISSUE-203 Bigtop Hive Build
- ISSUE-204 Bigtop Spark Build
- ISSUE-205 Bigtop HBase Build
- ISSUE-206 Apt Repository Validation
- ISSUE-207 Repository Snapshot Validation

### 10.5 Exit Criteria

```text
候选组件可构建为 DEB 包，apt 仓库可用，仓库快照可追溯。
```

## 11. F8 Operations & Observability

### 11.1 用户价值

提供基础运维可视化、指标和告警能力。

### 11.2 核心组件

- Ambari Metrics
- Service Alerts
- Dashboard

### 11.3 关联 Epic

- EPIC-101 Ambari Viability Review
- EPIC-801 Observability Validation

### 11.4 关联 Issue

- ISSUE-801 Ambari Metrics Install Validation
- ISSUE-802 Host Metrics Validation
- ISSUE-803 Service Alert Validation

### 11.5 Exit Criteria

```text
基础主机指标、服务状态和关键告警可见。
```

## 12. F9 Validation & Release Evidence

### 12.1 用户价值

提供可审计、可复现、可评审的验证证据体系，支撑版本冻结。

### 12.2 核心资产

- Validation Framework
- Technology Validation Matrix
- Component Reports
- HA Reports
- Release Report

### 12.3 关联 Epic

- EPIC-901 Validation Evidence
- EPIC-502 Version Freeze

### 12.4 关联 Issue

- ISSUE-901 Validation Report Template
- ISSUE-902 Evidence Directory Layout
- ISSUE-903 Gate-1 Review Report
- ISSUE-904 Release Candidate Validation Report

### 12.5 Exit Criteria

```text
所有 Gate 决策均有证据，Release Candidate 有完整 Validation Report。
```

## 13. Feature 到 Milestone 映射

| Feature | M1 | M2 | M3 | M4 | M5 |
|---|---|---|---|---|---|
| F1 Lifecycle Management | 验证 Ambari 可行性 | 安装路径 | 组件启停 | HA 操作 | RC 支撑 |
| F2 Distributed Storage | 风险评估 | 包与仓库 | HDFS 验证 | HDFS HA | 冻结 |
| F3 Resource Scheduling | 风险评估 | 包与仓库 | YARN 验证 | YARN HA | 冻结 |
| F4 SQL Warehouse | 风险评估 | 包与仓库 | Hive 验证 | 可选 HA | 冻结 |
| F5 Batch Compute | 风险评估 | 包与仓库 | Spark 验证 | N/A | 冻结 |
| F6 NoSQL Storage | 风险评估 | 包与仓库 | HBase 验证 | HBase HA | 冻结 |
| F7 Packaging & Delivery | Bigtop 可行性 | Repository Ready | 支撑安装 | 支撑 HA | Bundle |
| F8 Observability | Ambari Metrics 可行性 | 安装 | 指标 | 告警 | 冻结 |
| F9 Validation Evidence | Gate-1 | Repo Evidence | Component Evidence | HA Evidence | Release Report |

## 14. Feature 到 Agent 映射

| Feature | Responsible Agent | Accountable |
|---|---|---|
| F1 | Agent-A | Chief Architect |
| F2 | Agent-C | Chief Architect |
| F3 | Agent-C | Chief Architect |
| F4 | Agent-C | Chief Architect |
| F5 | Agent-D | Chief Architect |
| F6 | Agent-D | Chief Architect |
| F7 | Agent-B | Chief Architect |
| F8 | Agent-A | Chief Architect |
| F9 | Agent-F | Chief Architect |

## 15. Release Feature Gate

BIGDATA-1.0.0-RC1 至少需要：

| Feature | RC1 要求 |
|---|---|
| F1 | 至少支持安装、配置、启停、Service Check |
| F2 | HDFS 可用，HA 通过 |
| F3 | YARN 可用，HA 通过 |
| F4 | Hive 基础 SQL 通过 |
| F5 | Spark 基础作业和 Spark SQL 通过 |
| F6 | HBase put/get/scan 通过 |
| F7 | apt Repository 与 Release Snapshot 可用 |
| F8 | 基础指标可见，告警可后续增强 |
| F9 | Validation Report 完整 |

## 16. 后续动作

Feature Map 冻结后，Issue Tree 必须按 Feature 进行追踪，避免只按组件拆分。

下一步建议：

- 创建 `project/MILESTONES.md`
- 创建 `project/ISSUE_TREE.md`
- 创建首批 M1 GitHub Issues
