# Bigdata Platform Release 设计

## 1. 文档目标

本文档定义 Bigdata Platform 的 Release 抽象、版本号规范、组成结构、状态流转、验收标准、升级策略、回滚策略和与 Stack、Service Pack、Artifact Repository、Blueprint、Lifecycle 的关系。

Release 是平台最终对外交付的版本单元，也是私有化交付、升级、回滚和客户验收的核心依据。

## 2. Release 定义

Release 是经过验证、冻结并可交付的 Bigdata Platform 版本。

```text
Release = Frozen Stack + Artifact Snapshot + Blueprint Set + Config Set + Runbooks + Checks + Validation Report
```

Release 不是单个软件包，也不是单个安装脚本，而是一组经过一致性验证的交付资产。

## 3. Release 与其他抽象的关系

```text
Stack
  -> Service Pack
  -> Artifact Repository
  -> Blueprint
  -> Lifecycle
  -> Release
  -> Management Backend
```

其中：

- Stack 定义组件集合和版本矩阵
- Service Pack 定义组件如何被管理
- Artifact Repository 管理所有制品
- Blueprint 定义部署拓扑
- Lifecycle 定义安装、启停、升级、回滚动作
- Release 定义最终可交付版本
- Management Backend 执行部署和管理，例如 Ambari

## 4. Release 命名规范

建议采用语义化版本：

```text
BIGDATA-<major>.<minor>.<patch>
```

示例：

| Release | 说明 |
|---|---|
| BIGDATA-1.0.0 | 第一个传统数仓 HA 底座正式发布版 |
| BIGDATA-1.0.1 | 1.0 补丁版本，修复缺陷，不改变主能力 |
| BIGDATA-1.1.0 | 1.x 增强版本，增加安全、运维、Profile 能力 |
| BIGDATA-2.0.0 | 实时数据湖主线版本 |
| BIGDATA-3.0.0 | 云原生与混合管理面版本 |

## 5. Release 版本语义

| 字段 | 说明 | 示例 |
|---|---|---|
| major | 架构或能力大版本变化 | 1 -> 2 表示从传统数仓扩展到实时数据湖 |
| minor | 兼容性增强或新增能力 | 1.0 -> 1.1 增加安全治理能力 |
| patch | 缺陷修复、配置修正、包修复 | 1.0.0 -> 1.0.1 |

## 6. Release 状态模型

```text
draft
  -> candidate
  -> validated
  -> frozen
  -> released
  -> deprecated
```

| 状态 | 说明 |
|---|---|
| draft | 草案状态，设计和制品尚未完整 |
| candidate | 候选状态，进入验证流程 |
| validated | 验证通过，但尚未冻结 |
| frozen | 已冻结，可作为发布基线 |
| released | 已正式发布，可对外交付 |
| deprecated | 已废弃，不建议新部署 |

异常状态：

```text
rejected
```

用于标记验证失败且不进入发布的版本。

## 7. BIGDATA-1.0.0 Release 范围

BIGDATA-1.0.0 对应传统数仓物理机 HA 底座。

### 7.1 基础环境

| 项目 | 值 |
|---|---|
| OS | Ubuntu 22.04 |
| 默认 JDK | JDK 8 |
| JDK 兼容评估 | JDK 17 |
| 管理后端 | Ambari |
| 构建体系 | Bigtop |
| 验证拓扑 | 3 Master + 3 Worker + 1 Gateway |

### 7.2 组件候选

| 组件 | 候选版本 | 状态 |
|---|---:|---|
| Ambari | 3.0.0 | 候选，不冻结 |
| Ambari Metrics | 3.0.0 | 候选，不冻结 |
| Bigtop | 3.5.0 | 候选，不冻结 |
| Hadoop | 3.5.0 | 候选，不冻结 |
| ZooKeeper | 3.9.5 | 候选，不冻结 |
| Hive | 4.2.0 | 候选，不冻结 |
| Hive Standalone Metastore | 4.2.0 | 候选，不冻结 |
| Tez | 0.10.5 | 候选，不冻结 |
| Spark | 3.5.8 | 候选，不冻结 |
| HBase | 2.5.14 | 候选，不冻结 |

## 8. Release 组成

BIGDATA Release 应包含：

```text
release/
├── manifest.yaml
├── stack/
├── packages/
├── service-packs/
├── blueprints/
├── configs/
├── runbooks/
├── checks/
├── validation/
├── docs/
└── README.md
```

### 8.1 manifest.yaml

Release 的核心元数据。

示例：

```yaml
release: BIGDATA-1.0.0
status: candidate
stack: BIGDATA-1.0
os: Ubuntu 22.04
jdk: 8
managementBackend: ambari
artifactSnapshot: BIGDATA-1.0-candidate-20260601
profiles:
  - warehouse-ha-foundation
  - warehouse-basic
  - gateway-only
```

## 9. Release Bundle

Release Bundle 是可交付包。

```text
BIGDATA-1.0.0-offline-bundle.tar.gz
```

Bundle 应包含：

- Package Repository 快照
- Stack 元数据
- Service Pack
- Blueprint
- Config
- Runbook
- Smoke Test
- Validation Report
- README

## 10. 在线交付与离线交付

### 10.1 在线交付

```text
Release Manifest
  -> Platform Repository
  -> Ambari Repository Config
  -> Ambari Blueprint
  -> Cluster Install
```

### 10.2 离线交付

```text
Release Bundle
  -> Customer Repository
  -> Ambari Repository Config
  -> Ambari Blueprint
  -> Cluster Install
```

在线交付和离线交付必须基于同一 Release Manifest。

## 11. Release 验证流程

```text
Release Draft
  -> Candidate Matrix
  -> Bigtop Build Validation
  -> Artifact Snapshot
  -> Ambari Adaptation Validation
  -> 3M3W1G Cluster Validation
  -> Smoke Test
  -> HA Validation
  -> Version Freeze Review
  -> Release Freeze
```

## 12. Release 验收标准

BIGDATA-1.0.0 发布必须满足：

- 版本矩阵冻结
- Bigtop 构建验证通过
- apt 仓库发布验证通过
- Ambari 管理适配验证通过
- 3M3W1G 集群验证通过
- Service Check 通过
- Smoke Test 通过
- HA 验证通过
- Runbook 可执行
- Blocker / Critical 缺陷清零
- Release Manifest 完整
- 回退策略明确

## 13. Release 升级策略

### 13.1 Patch 升级

```text
BIGDATA-1.0.0 -> BIGDATA-1.0.1
```

适用：

- 缺陷修复
- 配置修正
- 小版本组件修复
- Runbook 修订

### 13.2 Minor 升级

```text
BIGDATA-1.0.x -> BIGDATA-1.1.0
```

适用：

- 新增 Profile
- 增强安全能力
- 增强运维能力
- 增加可选组件

### 13.3 Major 升级

```text
BIGDATA-1.x -> BIGDATA-2.0.0
```

适用：

- 引入实时数据湖
- 引入 Kafka / Flink / Iceberg / Trino
- 引入对象存储
- 管理模型变化

## 14. Release 回滚策略

Release 回滚必须支持多层回滚。

### 14.1 Release 回滚

```text
BIGDATA-1.0.1 -> BIGDATA-1.0.0
```

### 14.2 Artifact Snapshot 回滚

```text
candidate snapshot -> previous validated snapshot
```

### 14.3 Config 回滚

```text
config version N -> config version N-1
```

### 14.4 Blueprint 回滚

```text
blueprint version N -> blueprint version N-1
```

### 14.5 Package 回滚

```text
package version N -> package version N-1
```

## 15. Release 风险控制

Release 发布前必须确认：

- 是否存在未解决 Blocker 缺陷
- 是否存在未解决 Critical 缺陷
- 是否存在不兼容升级
- 是否存在无法回滚项
- 是否存在客户化配置覆盖风险
- 是否存在离线交付缺失项

## 16. Release 与客户交付

客户交付应基于 Release，而不是临时脚本。

交付对象：

- Release Bundle
- Installation Guide
- Runbook
- Smoke Test
- Acceptance Report Template
- Known Issues
- Rollback Guide

## 17. Release 与 Agent 工作流

| Agent | 职责 |
|---|---|
| Release Agent | Release Manifest、状态管理、发布清单 |
| Package Agent | Package Repository 快照 |
| Stack Agent | Stack 冻结 |
| Blueprint Agent | Blueprint 冻结 |
| QA Agent | 验证报告 |
| Review Agent | Release Review 与冻结结论 |

## 18. BIGDATA-1.0.0 当前状态

当前 BIGDATA-1.0.0 处于：

```text
draft / candidate preparation
```

已完成：

- Stack 设计
- Service Pack 设计
- Artifact Repository 设计
- 候选版本矩阵
- 验证计划
- 验证检查表

待完成：

- Bigtop 构建验证
- Ambari 管理适配验证
- JDK 兼容性验证
- 3M3W1G 集群验证
- 版本冻结评审
- Release Manifest
- Release Bundle 设计

## 19. 当前不做事项

当前阶段不做：

- 自动发布流水线
- 完整制品仓库服务
- 完整升级执行器
- 完整回滚执行器
- UI 发布管理

当前目标是先定义 Release 抽象和交付规范。

## 20. 后续文档

建议继续补：

- `docs/blueprint-design.md`
- `docs/lifecycle-design.md`
- `docs/management-backend-design.md`
- `docs/release-manifest-design.md`
