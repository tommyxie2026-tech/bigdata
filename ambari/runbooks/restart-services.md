# Ambari 服务重启 Runbook

## 1. 目标

本文档用于规范 Ambari 管理的大数据服务重启流程，降低配置变更、组件异常恢复和例行维护过程中的风险。

## 2. 适用场景

- 修改 Hadoop 组件配置后需要重启
- Ambari 标记服务存在 stale config
- 单个组件异常，需要重启恢复
- 例行维护窗口内的服务滚动重启

## 3. 风险说明

重启服务可能影响数据任务运行，尤其是：

- HDFS NameNode
- YARN ResourceManager
- Hive Metastore
- HiveServer2
- HBase Master / RegionServer
- Kafka Broker

生产环境执行前应确认维护窗口、任务状态和回滚方案。

## 4. 标准流程

### 4.1 检查集群状态

在 Ambari Dashboard 检查：

- 是否存在 Critical 告警
- 是否有正在运行的重要任务
- 是否存在磁盘、内存、网络异常

### 4.2 确认配置变更

确认 Ambari 中被标记为 `Restart Required` 的服务和组件。

### 4.3 执行重启

可以通过 Ambari Web UI 操作，也可以使用脚本：

```bash
cd ambari/scripts
./restart-stale-services.sh
```

### 4.4 执行服务检查

```bash
./service-check.sh HDFS
./service-check.sh YARN
./service-check.sh HIVE
```

## 5. 推荐重启顺序

```text
ZooKeeper
  -> HDFS
  -> YARN
  -> MapReduce2
  -> Hive Metastore
  -> HiveServer2
  -> Spark History Server
  -> HBase / Kafka / 其他服务
```

## 6. 验收标准

- 所有目标服务状态为 Started
- Ambari 不再显示 Restart Required
- 服务检查通过
- 核心任务可正常提交
- 关键告警已清除或确认无影响

## 7. 回滚策略

如果重启失败：

1. 记录 Ambari request id
2. 查看失败组件日志
3. 回退最近一次配置变更
4. 重启受影响组件
5. 必要时进入维护模式并人工处理
