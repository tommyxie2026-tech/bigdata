# Bigdata Platform Core 设计

## 1. 文档目标

本文档定义 Bigdata Platform 的 Platform Core 抽象、核心引擎、输入输出模型、执行流程和与 Stack、Service Pack、Artifact Repository、Release、Management Backend 的关系。

Platform Core 是平台的主体能力，负责解释平台声明、计算部署模型、编排生命周期动作，并调用具体 Management Backend 执行。

## 2. 背景

Architecture Review #1 指出当前架构存在一个核心缺口：已有 Stack、Service Pack、Artifact Repository、Release 等抽象，但缺少负责解释和驱动这些抽象的主体。

如果没有 Platform Core，则无法明确：

- 谁解析 Stack
- 谁解析 Service Pack
- 谁计算依赖关系
- 谁生成 Deployment Blueprint
- 谁驱动 Lifecycle
- 谁管理 Release
- 谁调用 Ambari 或 Kubernetes 执行部署

因此需要新增 Platform Core 作为平台核心层。

## 3. Platform Core 定义

Platform Core 是 Bigdata Platform 的控制核心。

```text
Platform Core = Engines + Model Resolver + Validation + Orchestration + Backend Adapter Manager
```

Platform Core 不直接等于 Ambari，不直接等于 Kubernetes，也不直接等于脚本集合。

它负责把平台声明转换为可执行计划。

## 4. 总体架构

```text
BIGDATA Platform
│
├── Platform Core
│   ├── Stack Engine
│   ├── Service Pack Engine
│   ├── Environment Engine
│   ├── Dependency Graph Engine
│   ├── Deployment Blueprint Engine
│   ├── Lifecycle Engine
│   ├── Release Engine
│   └── Backend Adapter Manager
│
├── Artifact Layer
│   ├── Binary Repository
│   ├── Config Repository
│   ├── Blueprint Repository
│   └── Release Repository
│
└── Backend Adapters
    ├── Ambari Adapter
    ├── Kubernetes Adapter
    └── Future Adapter
```

## 5. 核心输入

Platform Core 的输入包括：

| 输入 | 说明 |
|---|---|
| Stack | 平台组件集合和版本矩阵 |
| Environment Profile | OS、JDK、部署目标等环境约束 |
| Service Pack | 组件角色、配置、依赖、检查和生命周期定义 |
| Artifact Snapshot | 包、配置、Blueprint、Runbook 等制品快照 |
| Deployment Profile | single-node、3m3w1g-ha、production-ha 等部署形态 |
| Release Manifest | Release 元数据和交付边界 |

## 6. 核心输出

Platform Core 的输出包括：

| 输出 | 说明 |
|---|---|
| Resolved Stack Runtime | 已解析的 Stack 运行时模型 |
| Resolved Service Model | 已解析的服务、角色和配置模型 |
| Dependency Graph | 组件依赖图 |
| Deployment Blueprint | 平台级部署蓝图 |
| Backend Specific Plan | Ambari Blueprint、Kubernetes CRD 等后端执行计划 |
| Lifecycle Execution Plan | 安装、启动、停止、升级、回滚计划 |
| Release Validation Result | Release 验证结果 |

## 7. Stack Engine

Stack Engine 负责解析 Stack。

职责：

- 读取 Stack 定义
- 解析版本矩阵
- 解析组件集合
- 加载 Environment Profile
- 校验版本兼容性
- 输出 Resolved Stack Runtime

示例输入：

```yaml
stack: BIGDATA-1.0
components:
  hadoop: 3.5.0
  hive: 4.2.0
  spark: 3.5.8
  hbase: 2.5.14
environment:
  os: ubuntu22
  jdk: jdk8
```

示例输出：

```yaml
resolvedStack:
  name: BIGDATA-1.0
  status: candidate
  environment: ubuntu22-jdk8
  components:
    - hadoop
    - hive
    - spark
    - hbase
```

## 8. Service Pack Engine

Service Pack Engine 负责解析组件接入规范。

职责：

- 加载 service.yaml
- 加载 packages.yaml
- 解析角色模型
- 解析配置模型
- 解析运行时依赖
- 解析检查项
- 输出 Resolved Service Model

Service Pack Engine 需要区分：

| 类型 | 示例 |
|---|---|
| Service | HDFS、YARN、Hive、Spark、HBase、ZooKeeper |
| Runtime | Tez、JDBC Driver、Connector、Client Library |

Tez 不应被等同于完整独立服务，应优先作为 Hive Runtime Dependency 建模。

## 9. Environment Engine

Environment Engine 负责处理环境约束。

职责：

- 解析 OS Profile
- 解析 JDK Profile
- 解析部署目标
- 校验组件对环境的兼容性
- 输出 Environment Runtime

示例：

```yaml
environmentProfile: ubuntu22-jdk8-baremetal
os: ubuntu22
jdk: jdk8
target: bare-metal
packageType: deb
repoType: apt
```

未来可以扩展：

```yaml
environmentProfile: rocky9-jdk17-vm
os: rocky9
jdk: jdk17
target: vm
packageType: rpm
repoType: yum
```

## 10. Dependency Graph Engine

Dependency Graph Engine 负责计算组件依赖图。

职责：

- 解析服务依赖
- 解析运行时依赖
- 解析角色依赖
- 生成安装顺序
- 生成启动顺序
- 生成停止顺序
- 生成升级顺序
- 生成回滚顺序

示例：

```text
ZooKeeper
  -> HDFS
  -> YARN
  -> Hive
  -> Spark
  -> HBase
```

对于 HBase：

```text
HBase
  depends on HDFS
  depends on ZooKeeper
```

自动推导：

```text
Install: ZooKeeper -> HDFS -> HBase
Start:   ZooKeeper -> HDFS -> HBase
Stop:    HBase -> HDFS -> ZooKeeper
Rollback:HBase -> HDFS -> ZooKeeper
```

## 11. Deployment Blueprint Engine

Deployment Blueprint Engine 负责生成平台级部署蓝图。

职责：

- 解析 Deployment Profile
- 解析 Host Group
- 解析 Role Mapping
- 结合 Dependency Graph
- 生成 Deployment Blueprint
- 转换为 Backend Specific Plan

平台级蓝图示例：

```yaml
profile: 3m3w1g-ha
hostGroups:
  master:
    count: 3
  worker:
    count: 3
  gateway:
    count: 1
roleMapping:
  hdfs.NameNode:
    - master-01
    - master-02
  hdfs.DataNode:
    - worker-01
    - worker-02
    - worker-03
```

对于 BIGDATA-1.0：

```text
Deployment Blueprint -> Ambari Blueprint
```

未来 BIGDATA-3.0：

```text
Deployment Blueprint -> Kubernetes CRD / Helm Values
```

## 12. Lifecycle Engine

Lifecycle Engine 负责生成生命周期执行计划。

职责：

- Install Plan
- Configure Plan
- Start Plan
- Stop Plan
- Restart Plan
- Service Check Plan
- Upgrade Plan
- Rollback Plan
- Remove Plan

Lifecycle Engine 不直接执行底层动作，而是调用 Backend Adapter。

示例：

```text
Lifecycle Engine
  -> Install Plan
  -> Ambari Adapter
  -> Ambari REST API / Blueprint
```

## 13. Release Engine

Release Engine 负责 Release 的状态管理和冻结。

职责：

- 解析 Release Manifest
- 绑定 Artifact Snapshot
- 绑定 Stack Runtime
- 绑定 Blueprint
- 汇总验证结果
- 判断是否可冻结
- 生成 Release Report

Release Engine 必须保证：

- Stack 已冻结
- Artifact Snapshot 已冻结
- Blueprint 已冻结
- 验证报告已通过
- 回滚策略明确

## 14. Backend Adapter Manager

Backend Adapter Manager 负责选择和调用具体 Management Backend。

统一接口示例：

```go
type Backend interface {
    Install(plan Plan) Result
    Configure(plan Plan) Result
    Start(plan Plan) Result
    Stop(plan Plan) Result
    Restart(plan Plan) Result
    Check(plan Plan) Result
    Upgrade(plan Plan) Result
    Rollback(plan Plan) Result
    Remove(plan Plan) Result
}
```

BIGDATA-1.0 默认：

```text
Ambari Adapter
```

未来支持：

```text
Kubernetes Adapter
Custom Console Adapter
```

## 15. Platform Core 执行流程

```text
1. Load Release Manifest
2. Load Stack
3. Load Environment Profile
4. Load Service Packs
5. Resolve Artifact Snapshot
6. Build Dependency Graph
7. Generate Deployment Blueprint
8. Generate Lifecycle Execution Plan
9. Select Backend Adapter
10. Execute Plan
11. Run Service Check / Smoke Test
12. Collect Validation Result
```

## 16. BIGDATA-1.0 Platform Core 目标

BIGDATA-1.0 不要求实现完整 Platform Core 服务。

第一阶段目标是完成：

- Platform Core 抽象设计
- Stack Engine 文档模型
- Service Pack Engine 文档模型
- Dependency Graph 设计
- Deployment Blueprint 设计
- Ambari Adapter 设计
- Lifecycle Plan 设计

暂不实现：

- 完整 Web Console
- 完整 Core API Server
- 完整自动执行器
- 完整插件系统

## 17. 与现有文档关系

| 文档 | 与 Platform Core 关系 |
|---|---|
| `stack-design.md` | Stack Engine 输入 |
| `service-pack-design.md` | Service Pack Engine 输入 |
| `artifact-repository-design.md` | Artifact Layer 输入 |
| `release-design.md` | Release Engine 输入 |
| `phase1-version-validation-plan.md` | Release 验证输入 |
| `phase1-ha-design.md` | Deployment Blueprint 输入 |

## 18. 后续文档

Platform Core 之后需要补：

- `docs/dependency-graph-design.md`
- `docs/deployment-blueprint-design.md`
- `docs/backend-adapter-design.md`
- `docs/lifecycle-design.md`
