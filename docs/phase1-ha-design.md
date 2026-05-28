# Phase 1 传统数仓物理机 HA 设计

## 1. 文档目标

本文档定义 Bigdata Platform 第一阶段传统数仓物理机 HA 底座的部署拓扑、节点角色、核心组件、验证范围和验收目标。

## 2. 已确认基线

| 项目 | 确认结果 |
|---|---|
| 目标 OS | Ubuntu 22.04 |
| JDK | JDK 8，预留 JDK 17 兼容评估 |
| 管理面 | Ambari，传统大数据长期管理面 |
| 构建体系 | Bigtop 真实构建体系 |
| 验证规模 | 3 Master + 3 Worker + 1 Gateway |
| Kerberos | 设计保留，不默认启用 |
| 交付形态 | Bigtop 包仓库 + Ambari Blueprint + Runbook + Smoke Test |

## 3. 第一阶段组件范围

```text
Ambari
Bigtop
ZooKeeper
HDFS HA
YARN HA
Hive Metastore
HiveServer2
Spark
HBase
```

## 4. 目标拓扑

```text
master-01   master-02   master-03
worker-01   worker-02   worker-03
gateway-01
```

### 4.1 节点角色

| 节点 | 角色 | 说明 |
|---|---|---|
| master-01 | Master | Ambari Server、NameNode、ResourceManager、Hive、HBase Master、ZooKeeper |
| master-02 | Master | Standby NameNode、Standby ResourceManager、Hive、HBase Master、ZooKeeper |
| master-03 | Master | JournalNode、ZooKeeper、Hive、HBase Master 备选 |
| worker-01 | Worker | DataNode、NodeManager、HBase RegionServer |
| worker-02 | Worker | DataNode、NodeManager、HBase RegionServer |
| worker-03 | Worker | DataNode、NodeManager、HBase RegionServer |
| gateway-01 | Gateway | Hadoop Client、Hive Client、Spark Client、运维入口 |

## 5. HA 组件设计

### 5.1 ZooKeeper

ZooKeeper 采用 3 节点部署，运行在三个 Master 节点上。

用途：

- HDFS HA 协调
- YARN HA 协调
- HBase 协调
- 其他分布式组件协调

### 5.2 HDFS HA

HDFS 采用 Active / Standby NameNode 模式。

| 角色 | 建议节点 |
|---|---|
| Active NameNode | master-01 |
| Standby NameNode | master-02 |
| JournalNode | master-01、master-02、master-03 |
| DataNode | worker-01、worker-02、worker-03 |

### 5.3 YARN HA

YARN 采用 ResourceManager Active / Standby 模式。

| 角色 | 建议节点 |
|---|---|
| Active ResourceManager | master-01 |
| Standby ResourceManager | master-02 |
| NodeManager | worker-01、worker-02、worker-03 |

### 5.4 Hive HA

Hive Metastore 和 HiveServer2 均按多实例设计。

| 组件 | 建议节点 |
|---|---|
| Hive Metastore | master-01、master-02 |
| HiveServer2 | master-01、master-02 或 gateway-01 |
| Metastore DB | 外部数据库，后续设计细化 |

### 5.5 Spark

第一阶段 Spark 主要承担批处理和离线 SQL 补充能力。

| 组件 | 建议节点 |
|---|---|
| Spark History Server | master-03 或 gateway-01 |
| Spark Client | gateway-01 |

### 5.6 HBase

HBase 进入第一阶段真实验证范围。

| 角色 | 建议节点 |
|---|---|
| HBase Master | master-01、master-02 |
| RegionServer | worker-01、worker-02、worker-03 |
| ZooKeeper | master-01、master-02、master-03 |
| HDFS | 作为 HBase 底层存储 |

## 6. 网络与端口要求

第一阶段需要至少区分以下逻辑流量：

- 管理流量：Ambari、SSH、Agent
- 存储流量：HDFS、HBase WAL、DataNode 传输
- 计算流量：YARN、Spark Shuffle
- 查询流量：HiveServer2、Gateway 访问

后续需要补充完整端口矩阵。

## 7. 存储规划

Worker 节点建议至少区分：

```text
/system          系统盘
/data1/hdfs      HDFS 数据盘
/data2/hdfs      HDFS 数据盘
/logs            服务日志
/tmp             临时目录
```

Master 节点需要重点规划：

- NameNode 元数据目录
- JournalNode 目录
- Ambari Server 数据目录
- Hive Metastore 外部数据库存储
- HBase Master 日志

## 8. 验证目标

### 8.1 管理面验证

- Ambari Server 可访问
- 所有 Agent 在线
- 所有服务状态可见
- 配置变更可下发
- Service Check 可执行

### 8.2 HDFS HA 验证

- Active / Standby NameNode 正常
- 手动 Failover 可执行
- DataNode 正常注册
- HDFS 读写正常

### 8.3 YARN HA 验证

- ResourceManager Active / Standby 正常
- NodeManager 正常注册
- Spark / MapReduce 任务可提交

### 8.4 Hive 验证

- Hive Metastore 多实例可用
- HiveServer2 可连接
- 建库、建表、查询正常

### 8.5 Spark 验证

- Spark Client 可提交任务
- Spark History Server 可查看任务历史
- Spark SQL 可访问 Hive Metastore

### 8.6 HBase 验证

- HBase Master 正常
- RegionServer 正常注册
- 表创建、写入、读取正常
- Master 故障切换具备验证路径

## 9. 交付物

| 交付物 | 说明 |
|---|---|
| Ambari Blueprint | 描述 3M3W1G 拓扑 |
| Bigtop 包仓库 | 提供 Ubuntu 22.04 组件包 |
| 配置模板 | HDFS、YARN、Hive、Spark、HBase |
| Runbook | 安装、重启、恢复、扩容 |
| Smoke Test | 验证 HDFS/YARN/Hive/Spark/HBase |

## 10. 后续待办

- [ ] 补充硬件规格建议
- [ ] 补充端口矩阵
- [ ] 补充 Ambari Blueprint 详细设计
- [ ] 补充 HBase 详细部署参数
- [ ] 补充 HA 故障切换验证步骤
