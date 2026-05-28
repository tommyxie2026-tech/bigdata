# HDFS 故障恢复 Runbook

## 1. 目标

本文档用于指导 Ambari 管理环境下的 HDFS 常见故障排查与恢复。

## 2. 常见故障

- NameNode 未启动
- DataNode 未启动
- HDFS 容量不足
- HDFS 块丢失或副本不足
- Safe Mode 未退出
- JournalNode / ZooKeeper 相关异常

## 3. 初步检查

### 3.1 查看 Ambari 状态

在 Ambari Dashboard 中检查：

- HDFS 服务状态
- NameNode 状态
- DataNode 数量
- HDFS 告警
- 主机磁盘和内存告警

### 3.2 执行 HDFS 服务检查

```bash
cd ambari/scripts
./service-check.sh HDFS
```

### 3.3 查看 HDFS 报告

在 HDFS Client 节点执行：

```bash
hdfs dfsadmin -report
hdfs fsck / -files -blocks -locations
```

## 4. Safe Mode 处理

检查 Safe Mode：

```bash
hdfs dfsadmin -safemode get
```

必要时手动退出：

```bash
hdfs dfsadmin -safemode leave
```

注意：如果存在大量块丢失或 DataNode 未恢复，不建议强行退出 Safe Mode。

## 5. DataNode 异常恢复

### 5.1 检查 DataNode 日志

```bash
ls -lh /var/log/hadoop/hdfs/
tail -n 200 /var/log/hadoop/hdfs/hadoop-hdfs-datanode-*.log
```

### 5.2 检查数据目录

确认 `dfs.datanode.data.dir` 配置的目录存在且权限正确。

### 5.3 通过 Ambari 重启 DataNode

优先使用 Ambari Web UI 重启异常 DataNode。

## 6. NameNode 异常恢复

### 6.1 检查 NameNode 日志

```bash
tail -n 200 /var/log/hadoop/hdfs/hadoop-hdfs-namenode-*.log
```

### 6.2 检查元数据目录

确认 `dfs.namenode.name.dir` 目录存在、权限正确、磁盘可用。

### 6.3 重启 NameNode

通过 Ambari Web UI 重启 NameNode，并观察启动日志。

## 7. 容量不足处理

### 7.1 临时处理

- 清理过期临时数据
- 清理 Hive / Spark 临时目录
- 清理历史日志
- 检查大文件异常写入

### 7.2 长期处理

- 扩容 DataNode
- 调整副本策略
- 建立冷热数据分层
- 定期执行容量巡检

## 8. 验收标准

- HDFS 服务状态为 Started
- NameNode / DataNode 状态正常
- Ambari HDFS Critical 告警清除
- `hdfs dfsadmin -report` 正常
- HDFS 服务检查通过

## 9. 注意事项

- 不要在未确认原因时直接删除 HDFS 元数据目录
- 不要随意格式化 NameNode
- 生产环境处理块丢失问题前应先备份关键元数据和日志
- 涉及 HA 的 HDFS 集群应同时检查 ZooKeeper、JournalNode 和 Standby NameNode
