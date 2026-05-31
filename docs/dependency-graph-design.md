# Bigdata Platform Dependency Graph 设计

## 1. 文档目标

本文档定义 Bigdata Platform 的 Dependency Graph 抽象、节点模型、边模型、依赖类型、图计算输出和在安装、启动、停止、升级、回滚、Blueprint 生成中的作用。

Dependency Graph 是 Platform Core 的核心调度模型。它决定组件之间的依赖关系，以及平台如何生成可执行计划。

## 2. 背景

Architecture Review #1 指出，现有文档虽然定义了 Stack、Service Pack、Artifact Repository、Release 和 Platform Core，但对组件依赖关系的表达还不够。

在大数据平台中，组件依赖不仅影响安装顺序，也影响：

- 启动顺序
- 停止顺序
- 升级顺序
- 回滚顺序
- 故障影响范围
- Blueprint 生成
- Service Check 编排

因此需要将依赖关系显式建模为 Dependency Graph。

## 3. Dependency Graph 定义

Dependency Graph 是由节点和边组成的有向图。

```text
Dependency Graph = Nodes + Edges + Rules + Execution Plans
```

其中：

- Node 表示 Service、Role、Runtime、Artifact 或 Environment Constraint
- Edge 表示依赖、运行时要求、可选关系、顺序约束
- Rules 表示不同生命周期阶段下的排序规则
- Execution Plans 表示安装、启动、停止、升级和回滚计划

## 4. 节点模型

### 4.1 Service Node

表示一个平台服务。

示例：

```text
ZooKeeper
HDFS
YARN
Hive
Spark
HBase
```

### 4.2 Role Node

表示服务内部角色。

示例：

```text
HDFS.NameNode
HDFS.DataNode
HDFS.JournalNode
YARN.ResourceManager
YARN.NodeManager
Hive.Metastore
Hive.HiveServer2
HBase.Master
HBase.RegionServer
```

### 4.3 Runtime Node

表示运行时依赖，不一定是独立服务。

示例：

```text
Tez
Hive JDBC Driver
Spark Hive Client
HBase Client
```

Tez 在 BIGDATA-1.0 中优先作为 Hive Runtime Dependency 建模，而不是完整独立 Service。

### 4.4 Artifact Node

表示包、配置、蓝图、脚本等制品。

示例：

```text
hadoop deb package
hive-site.xml
3m3w1g-ha blueprint
service-check script
```

### 4.5 Environment Node

表示环境约束。

示例：

```text
ubuntu22
jdk8
apt
bare-metal
```

## 5. 边模型

Dependency Graph 中的边表示依赖或约束关系。

| 边类型 | 说明 |
|---|---|
| depends_on | 强依赖，目标必须先存在 |
| requires | 运行时强要求 |
| optional | 可选依赖 |
| provides | 提供能力 |
| consumes | 消费能力 |
| colocates_with | 建议或要求同节点部署 |
| conflicts_with | 冲突关系 |
| starts_after | 启动顺序约束 |
| stops_before | 停止顺序约束 |
| upgrades_after | 升级顺序约束 |
| rolls_back_before | 回滚顺序约束 |

## 6. BIGDATA-1.0 服务依赖图

### 6.1 服务级依赖

```text
Environment(ubuntu22-jdk8)
  -> ZooKeeper
  -> HDFS
  -> YARN
  -> Hive
  -> Spark
  -> HBase
```

更准确的依赖关系：

```text
ZooKeeper -> HDFS
ZooKeeper -> YARN
ZooKeeper -> HBase
HDFS -> YARN
HDFS -> Hive
HDFS -> Spark
HDFS -> HBase
Hive Metastore -> HiveServer2
Hive Metastore -> Spark SQL
Tez -> Hive
```

### 6.2 HBase 依赖

```text
HBase
  depends_on HDFS
  depends_on ZooKeeper
  requires JDK8
```

### 6.3 Hive 依赖

```text
Hive
  depends_on HDFS
  requires Hive Metastore
  optional Tez
```

### 6.4 Spark 依赖

```text
Spark
  depends_on YARN
  optional Hive Metastore
  consumes HDFS
```

## 7. 角色级依赖图

服务级依赖不足以生成可执行计划，还需要角色级依赖。

### 7.1 HDFS HA

```text
ZooKeeper.Server
  -> HDFS.JournalNode
  -> HDFS.NameNode
  -> HDFS.ZKFC
  -> HDFS.DataNode
```

### 7.2 YARN HA

```text
ZooKeeper.Server
  -> YARN.ResourceManager
  -> YARN.NodeManager
```

### 7.3 Hive

```text
HDFS.NameNode
  -> Hive.Metastore
  -> Hive.HiveServer2
```

### 7.4 HBase

```text
ZooKeeper.Server
HDFS.NameNode
  -> HBase.Master
  -> HBase.RegionServer
```

## 8. 图计算输出

Dependency Graph Engine 需要输出以下计划。

| 输出 | 说明 |
|---|---|
| Install Plan | 安装顺序 |
| Configure Plan | 配置生成和分发顺序 |
| Start Plan | 启动顺序 |
| Stop Plan | 停止顺序 |
| Restart Plan | 重启顺序 |
| Upgrade Plan | 升级顺序 |
| Rollback Plan | 回滚顺序 |
| Impact Analysis | 故障或变更影响范围 |

## 9. 安装顺序规则

安装顺序按照依赖正向拓扑排序。

示例：

```text
1. Environment bootstrap
2. JDK
3. ZooKeeper
4. HDFS
5. YARN
6. Hive Metastore
7. HiveServer2
8. Tez Runtime
9. Spark
10. HBase
11. Gateway Clients
```

说明：

- 强依赖必须先安装
- Runtime 可随依赖服务安装
- Client 可最后安装
- optional 依赖不阻塞主服务安装

## 10. 启动顺序规则

启动顺序也按照依赖正向拓扑排序，但需要考虑角色状态。

示例：

```text
1. ZooKeeper
2. HDFS JournalNode
3. HDFS NameNode
4. HDFS ZKFC
5. HDFS DataNode
6. YARN ResourceManager
7. YARN NodeManager
8. Hive Metastore
9. HiveServer2
10. Spark History Server
11. HBase Master
12. HBase RegionServer
```

## 11. 停止顺序规则

停止顺序通常是启动顺序的反向。

示例：

```text
1. HBase RegionServer
2. HBase Master
3. Spark History Server
4. HiveServer2
5. Hive Metastore
6. YARN NodeManager
7. YARN ResourceManager
8. HDFS DataNode
9. HDFS ZKFC
10. HDFS NameNode
11. HDFS JournalNode
12. ZooKeeper
```

## 12. 升级顺序规则

升级顺序不能简单等同于安装顺序，需要考虑兼容窗口。

原则：

- 先升级底层依赖的兼容补丁
- 再升级上层服务
- 保持服务端和客户端版本兼容
- 对 HA 服务执行滚动升级优先
- 对无法滚动升级的服务执行停机窗口策略

示例：

```text
1. ZooKeeper compatibility check
2. HDFS rolling upgrade
3. YARN rolling upgrade
4. Hive Metastore upgrade
5. HiveServer2 upgrade
6. Spark client/runtime upgrade
7. HBase rolling or controlled upgrade
```

## 13. 回滚顺序规则

回滚通常按照升级顺序反向执行。

示例：

```text
1. HBase rollback
2. Spark rollback
3. HiveServer2 rollback
4. Hive Metastore rollback
5. YARN rollback
6. HDFS rollback
7. ZooKeeper rollback
```

注意：

- 涉及元数据 schema 变更时，必须单独声明可逆性
- 涉及数据格式变更时，必须声明数据兼容窗口
- 涉及客户端协议变更时，必须声明兼容矩阵

## 14. 影响分析

Dependency Graph 可用于故障影响分析。

示例：

```text
ZooKeeper failure
  impacts HDFS HA
  impacts YARN HA
  impacts HBase
```

```text
HDFS failure
  impacts Hive
  impacts Spark
  impacts HBase
```

```text
Hive Metastore failure
  impacts HiveServer2
  impacts Spark SQL
```

## 15. 与 Deployment Blueprint 的关系

Deployment Blueprint Engine 依赖 Dependency Graph 输出角色关系。

例如：

```text
HBase.RegionServer
  requires HDFS.DataNode locality preference
```

可以推导：

```text
HBase RegionServer should be placed on worker nodes with DataNode
```

## 16. 与 Lifecycle Engine 的关系

Lifecycle Engine 不能手写固定顺序，而应消费 Dependency Graph 输出的计划。

```text
Dependency Graph
  -> Start Plan
  -> Lifecycle Engine
  -> Backend Adapter
```

## 17. 与 Release Engine 的关系

Release Engine 在冻结版本时必须冻结 Dependency Graph Snapshot。

Release Manifest 应包含：

```yaml
dependencyGraphSnapshot: BIGDATA-1.0-graph-20260601
```

这样升级和回滚时可以追溯当时的依赖关系。

## 18. Graph Validation

Dependency Graph 必须进行校验。

校验项：

- 是否存在循环依赖
- 是否存在缺失依赖
- optional 依赖是否声明默认行为
- conflicts_with 是否有处理策略
- Role Mapping 是否满足依赖要求
- Upgrade / Rollback 是否存在不可逆操作

## 19. BIGDATA-1.0 当前目标

BIGDATA-1.0 不要求实现完整图计算引擎。

第一阶段目标：

- 明确服务依赖图
- 明确角色依赖图
- 明确安装、启动、停止顺序
- 明确升级、回滚设计原则
- 在 Runbook 和检查表中使用统一顺序

## 20. 后续文档

建议继续补：

- `docs/deployment-blueprint-design.md`
- `docs/lifecycle-design.md`
- `docs/backend-adapter-design.md`
