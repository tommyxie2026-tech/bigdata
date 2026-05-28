# HBase 第一阶段设计

## 1. 文档目标

本文档定义 Bigdata Platform 第一阶段中 HBase 的定位、部署模型、依赖关系、验证范围、运维要求和后续扩展方向。

HBase 已确认进入第一阶段真实验证范围。

## 2. HBase 定位

HBase 在第一阶段作为传统数仓底座中的宽表存储能力，用于补充 HDFS + Hive + Spark 体系在低延迟随机读写、宽表模型和半结构化数据访问上的能力。

适用场景：

- 宽表存储
- 大规模明细查询
- 随机读写
- 半结构化数据存储
- 需要较低延迟的在线查询辅助场景

## 3. 组件依赖

```text
HBase
  -> HDFS
  -> ZooKeeper
  -> JDK 8
  -> Ubuntu 22.04
  -> Ambari 管理
  -> Bigtop 构建包
```

## 4. 部署拓扑

第一阶段验证规模：

```text
3 Master + 3 Worker + 1 Gateway
```

### 4.1 推荐角色分布

| 组件 | 节点 |
|---|---|
| HBase Master | master-01、master-02 |
| HBase Master 备选 | master-03，可选 |
| HBase RegionServer | worker-01、worker-02、worker-03 |
| ZooKeeper | master-01、master-02、master-03 |
| HDFS DataNode | worker-01、worker-02、worker-03 |
| HBase Client | gateway-01 |

## 5. HA 设计

HBase HA 依赖：

- 多 HBase Master
- 多 RegionServer
- ZooKeeper 协调
- HDFS HA 底层存储

### 5.1 HBase Master

至少部署两个 HBase Master，形成 Active / Standby 关系。

### 5.2 RegionServer

RegionServer 部署在 Worker 节点，第一阶段至少 3 个 RegionServer。

### 5.3 ZooKeeper

HBase 依赖 ZooKeeper 管理集群状态、Master 选举、Region 分配等。

### 5.4 HDFS

HBase 数据和 WAL 存储在 HDFS 上，因此 HDFS HA 是 HBase 稳定运行的基础。

## 6. 配置设计

第一阶段需要重点关注：

| 配置 | 说明 |
|---|---|
| `hbase.rootdir` | HBase 在 HDFS 上的数据根目录 |
| `hbase.cluster.distributed` | 分布式模式开关 |
| `hbase.zookeeper.quorum` | ZooKeeper 节点列表 |
| `hbase.regionserver.handler.count` | RegionServer 处理线程数 |
| `hbase.hregion.memstore.flush.size` | MemStore flush 阈值 |
| `hbase.hstore.compactionThreshold` | Compaction 触发阈值 |
| `hbase.wal.provider` | WAL 实现方式 |

配置模板应进入：

```text
ambari/configs/
```

或后续 Ambari Stack / Service 配置体系。

## 7. 验证范围

第一阶段 HBase 真实验证至少包括：

### 7.1 服务状态验证

- HBase Master 启动正常
- RegionServer 注册正常
- ZooKeeper 连接正常
- HDFS 存储路径可用

### 7.2 功能验证

- 创建 Namespace
- 创建表
- 写入数据
- 读取数据
- Scan 查询
- 删除表

### 7.3 HA 验证

- 停止 Active HBase Master
- Standby Master 接管
- RegionServer 保持可用
- 基础读写不受严重影响

### 7.4 与 HDFS 验证

- HBase rootdir 在 HDFS 上正常创建
- HDFS HA 切换后 HBase 可恢复

## 8. 运维关注点

### 8.1 容量

- HBase 表数据容量
- HDFS 空间
- Region 数量
- WAL 大小
- Compaction 负载

### 8.2 性能

- RegionServer CPU / 内存
- 读写延迟
- BlockCache 命中率
- MemStore flush 频率
- Compaction 频率

### 8.3 稳定性

- RegionServer 宕机恢复
- Region 迁移
- ZooKeeper 会话稳定性
- HDFS 写入延迟

## 9. 监控指标

| 维度 | 指标 |
|---|---|
| Master | Active 状态、Region 分配、Cluster 状态 |
| RegionServer | Region 数量、读写请求数、延迟 |
| WAL | WAL 文件数、写入延迟 |
| MemStore | 使用量、flush 次数 |
| Compaction | 队列长度、执行时间 |
| HDFS | HBase 目录容量、块健康 |

## 10. Smoke Test

第一阶段 HBase Smoke Test 应覆盖：

```text
create_namespace
create_table
put
get
scan
disable_table
drop_table
```

## 11. Runbook 需求

后续需要补充：

- HBase 安装 Runbook
- HBase 重启 Runbook
- HBase Master 故障恢复 Runbook
- RegionServer 故障恢复 Runbook
- Region 热点处理 Runbook
- Compaction 问题排查 Runbook

## 12. 后续扩展

后续阶段 HBase 可以继续作为：

- 实时查询补充存储
- 宽表服务 Profile
- 与 Phoenix 等 SQL 层集成的可选组件

但不作为实时数据湖主线组件，实时数据湖主线仍然是 Kafka + Flink + Iceberg + S3/HDFS + Trino/Spark SQL。

## 13. 后续待办

- [ ] 补充 HBase 推荐版本
- [ ] 补充 HBase 配置模板
- [ ] 补充 HBase Smoke Test 脚本
- [ ] 补充 HBase Runbook
- [ ] 补充 HBase 与 JDK 17 兼容性评估
