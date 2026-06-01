# BIGDATA Roadmap v1.0

## 1. 目标

本文档定义 BIGDATA 的长期路线图，用于明确 BIGDATA-1.0、BIGDATA-2.0、BIGDATA-3.0 的阶段定位，避免将长期平台能力错误放入 BIGDATA-1.0 RC1。

## 2. 总体愿景

BIGDATA 的最终目标是演进为 Hybrid Data Platform，支持：

- 传统数仓
- 实时数仓
- 数据湖 / Lakehouse
- 物理机
- 虚拟机
- 容器与 Kubernetes
- 组件自由组合
- 统一生命周期管理
- 统一验证与交付

## 3. 路线总览

| 版本 | 定位 | 核心目标 |
|---|---|---|
| BIGDATA-1.0 | Reference Distribution | 证明传统数仓技术路线成立 |
| BIGDATA-2.0 | Composable Platform | 从发行版升级为可组合平台 |
| BIGDATA-3.0 | Hybrid Data Platform | 支持多运行时、Lakehouse、Streaming、Kubernetes |

## 4. BIGDATA-1.0

### 4.1 定位

```yaml
name: BIGDATA-1.0
type: Reference Distribution
```

### 4.2 核心目标

证明以下技术路线成立：

```text
Ubuntu 22.04 + JDK 8
Bigtop Package Repository
Hadoop + Hive + Spark
HDFS HA + YARN HA
Validation Report
```

### 4.3 必须交付

- Hadoop / HDFS / YARN
- Hive / Metastore / HiveServer2
- Spark / Spark SQL
- Bigtop 构建与包仓库
- apt Repository
- Release Snapshot
- Validation Report
- Runbook

### 4.4 条件交付

- Ambari 作为 Backend Plugin
- HBase
- Ambari Metrics

### 4.5 不做事项

- 完整 Platform Core 实现
- Native Backend 完整实现
- Kubernetes
- Lakehouse
- Streaming
- Multi Runtime
- 复杂 Upgrade / Rollback

## 5. BIGDATA-2.0

### 5.1 定位

```yaml
name: BIGDATA-2.0
type: Composable Platform
```

### 5.2 核心目标

从 Reference Distribution 演进为可组合平台。

### 5.3 新增能力

- Stack Model 工程化
- Service Pack 工程化
- Compatibility Matrix
- Backend Adapter Contract
- Ambari Adapter
- Native Adapter Skeleton
- Deployment Plan
- Lifecycle Plan
- Release Manifest

### 5.4 典型交付

```text
Composable Stack
Composable Service Pack
Backend Adapter Contract
Release Manifest
```

## 6. BIGDATA-3.0

### 6.1 定位

```yaml
name: BIGDATA-3.0
type: Hybrid Data Platform
```

### 6.2 核心目标

支持多运行环境和现代数据湖平台能力。

### 6.3 新增能力

- Bare Metal / VM / Container / Kubernetes
- Kubernetes Adapter
- Lakehouse：Iceberg / Hudi / Delta
- Streaming：Kafka / Flink
- Object Storage
- Unified Control Plane
- Observability Platform

## 7. RC1 范围冻结

BIGDATA-1.0.0-RC1 只聚焦：

```text
Bigtop -> Repository -> Hadoop -> Hive -> Spark -> HA -> Validation Report
```

不允许将 BIGDATA-2.0 / 3.0 的平台能力放入 RC1 必须范围。

## 8. Backlog 原则

所有不属于 BIGDATA-1.0 RC1 的能力，统一进入 `project/BACKLOG.md`。

优先级规则：

- 不影响 RC1 主线的能力进入 Backlog
- 无验证证据的能力不得进入 Release Scope
- 长期平台能力不得阻塞 Reference Distribution

## 9. 关联文档

- `project/BACKLOG.md`
- `project/ISSUE_TREE.md`
- `project/MILESTONES.md`
- `project/FEATURE_MAP.md`
