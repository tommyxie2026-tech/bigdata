# Bigdata Platform Service Pack 设计

## 1. 文档目标

本文档定义 Bigdata Platform 的 Service Pack 抽象、目录结构、元数据规范、依赖声明、配置模型、生命周期模型、验证模型和扩展规则。

Service Pack 是平台组件扩展的核心单元。平台后续接入 Hadoop、Hive、Spark、HBase、Kafka、Flink、Iceberg、Trino 等组件时，都应通过 Service Pack 方式扩展，而不是修改平台核心逻辑。

## 2. Service Pack 定义

Service Pack 描述一个组件如何被平台识别、构建、安装、配置、启动、停止、检查、升级、回滚和运维。

```text
Service Pack = Component Metadata + Package Mapping + Config Schema + Lifecycle Actions + Health Checks + Runbooks
```

Service Pack 不等于安装脚本。安装脚本只是 Service Pack 生命周期动作的一部分。

## 3. Service Pack 与 Stack 的关系

Stack 声明一个平台版本包含哪些组件，Service Pack 声明每个组件如何被管理。

```text
BIGDATA-1.0
  ├── HDFS Service Pack
  ├── YARN Service Pack
  ├── ZooKeeper Service Pack
  ├── Hive Service Pack
  ├── Spark Service Pack
  └── HBase Service Pack
```

BIGDATA-2.0 可继续扩展：

```text
BIGDATA-2.0
  ├── Kafka Service Pack
  ├── Flink Service Pack
  ├── Iceberg Service Pack
  ├── Trino Service Pack
  └── Object Storage Service Pack
```

## 4. Service Pack 目录建议

```text
service-packs/
├── hdfs/
│   ├── service.yaml
│   ├── packages.yaml
│   ├── configs/
│   ├── lifecycle/
│   ├── checks/
│   └── runbooks/
├── yarn/
├── zookeeper/
├── hive/
├── spark/
└── hbase/
```

当前阶段可以先以文档和模板形式存在，待版本验证和 Ambari 适配明确后再逐步落地。

## 5. service.yaml 元数据规范

每个 Service Pack 必须包含 `service.yaml`，用于声明组件基本信息。

示例：

```yaml
name: hdfs
displayName: HDFS
category: storage
stack: BIGDATA-1.0
version: 3.5.0
managementBackend:
  - ambari
deployModes:
  - bare-metal
  - vm
roles:
  - NameNode
  - DataNode
  - JournalNode
  - ZKFC
dependencies:
  required:
    - zookeeper
  optional: []
```

## 6. packages.yaml 包映射规范

Service Pack 需要声明组件与包仓库之间的映射关系。

示例：

```yaml
component: hdfs
repository: bigtop-3.5.0-ubuntu22
packages:
  - hadoop-hdfs-namenode
  - hadoop-hdfs-datanode
  - hadoop-hdfs-journalnode
  - hadoop-client
```

包映射必须与 Bigtop 构建输出、apt 仓库和 Ambari Repository 配置保持一致。

## 7. 配置模型

Service Pack 需要声明配置文件、配置项、默认值、是否必填、是否影响重启。

示例：

```yaml
configs:
  - file: hdfs-site.xml
    properties:
      - name: dfs.replication
        default: 3
        required: true
        restartRequired: true
      - name: dfs.nameservices
        required: true
        restartRequired: true
```

配置模型需要支持：

- 默认配置
- HA 配置
- Profile 覆盖
- 环境覆盖
- 客户化覆盖
- 配置变更审计

## 8. 角色模型

Service Pack 中每个角色需要明确：

- 角色名称
- 部署节点类型
- 是否支持多实例
- 是否支持 HA
- 启动顺序
- 停止顺序
- 健康检查方式

示例：

```yaml
roles:
  NameNode:
    hostGroup: master
    ha: true
    minInstances: 2
  DataNode:
    hostGroup: worker
    ha: false
    minInstances: 3
```

## 9. 生命周期模型

每个 Service Pack 必须逐步支持统一生命周期。

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

BIGDATA-1.0 第一阶段重点支持：

- Install
- Configure
- Start
- Stop
- Restart
- Service Check

Upgrade / Rollback 先进入设计保留。

## 10. Lifecycle Action 规范

建议每个生命周期动作独立声明。

```text
lifecycle/
├── install.md
├── configure.md
├── start.md
├── stop.md
├── restart.md
├── service-check.md
├── upgrade.md
└── rollback.md
```

后续工程化时，可逐步替换为：

```text
lifecycle/
├── install.sh
├── configure.sh
├── start.sh
├── stop.sh
├── restart.sh
└── service-check.sh
```

但当前设计阶段不直接写重型脚本。

## 11. Health Check 与 Service Check

Service Pack 必须提供基础检查方式。

检查分为：

| 类型 | 说明 |
|---|---|
| Process Check | 进程是否存在 |
| Port Check | 端口是否监听 |
| API Check | 服务 API 是否可访问 |
| Functional Check | 基础功能是否可用 |
| HA Check | 主备状态是否正常 |

示例：

```yaml
checks:
  process:
    - NameNode
  ports:
    - 8020
    - 9870
  functional:
    - hdfs dfs -ls /
```

## 12. Runbook 规范

每个 Service Pack 必须配套 Runbook。

```text
runbooks/
├── install.md
├── restart.md
├── failover.md
├── recovery.md
├── scale-out.md
└── upgrade.md
```

BIGDATA-1.0 至少要求：

- 安装 Runbook
- 重启 Runbook
- 故障恢复 Runbook
- 巡检 Runbook

## 13. 依赖模型

Service Pack 必须声明依赖关系。

示例：

```text
HBase
  -> HDFS
  -> ZooKeeper
  -> JDK
```

依赖关系用于：

- 安装顺序
- 启动顺序
- 停止顺序
- 故障影响分析
- 升级顺序
- Blueprint 生成

## 14. BIGDATA-1.0 Service Pack 清单

| Service Pack | 组件 | 角色 | 优先级 |
|---|---|---|---|
| zookeeper | ZooKeeper | Server | P0 |
| hdfs | Hadoop HDFS | NameNode、DataNode、JournalNode、ZKFC | P0 |
| yarn | Hadoop YARN | ResourceManager、NodeManager | P0 |
| hive | Hive | Metastore、HiveServer2 | P0 |
| tez | Tez | Execution Engine | P1 |
| spark | Spark | Spark History Server、Client | P0 |
| hbase | HBase | HBase Master、RegionServer | P0 |

## 15. 与 Ambari 的关系

在 BIGDATA-1.0 中，Ambari 是主要 Management Backend。

Service Pack 需要能映射到 Ambari 的：

- Service
- Component
- Role Command
- Configuration
- Service Check
- Alert
- Stack / Repository

但 Service Pack 不应被 Ambari 绑定死。未来可以适配：

- Kubernetes Operator
- 自研 Console
- 其他管理后端

## 16. 与 Blueprint 的关系

Blueprint 使用 Service Pack 的角色定义生成部署拓扑。

示例：

```text
Profile: 3m3w1g-ha
  -> hdfs.NameNode: master-01, master-02
  -> hdfs.DataNode: worker-01, worker-02, worker-03
  -> yarn.ResourceManager: master-01, master-02
  -> hbase.RegionServer: worker-01, worker-02, worker-03
```

## 17. 与 Repository 的关系

Service Pack 的 `packages.yaml` 必须能定位到 Repository 中的包。

```text
Service Pack
  -> Package Mapping
  -> Bigtop Build Output
  -> Platform Repository
  -> Ambari Repository Config
```

## 18. 扩展新组件流程

新增组件必须遵循：

```text
1. 新建 Service Pack
2. 声明 service.yaml
3. 声明 packages.yaml
4. 声明配置模型
5. 声明角色模型
6. 声明生命周期动作
7. 声明 Service Check
8. 补充 Runbook
9. 补充版本矩阵
10. 补充 Blueprint Profile
11. 通过 Review Agent 审查
```

## 19. 当前不做事项

当前阶段不做：

- 完整可执行 Service Pack 引擎
- 完整自定义 Ambari Stack 生产实现
- 所有生命周期脚本
- 自动化 UI 接入
- Kubernetes Operator 适配

当前目标是先定义规范和扩展模型。

## 20. 后续文档

Service Pack 之后建议继续补：

- `docs/repository-design.md`
- `docs/blueprint-design.md`
- `docs/lifecycle-design.md`
- `docs/management-backend-design.md`
