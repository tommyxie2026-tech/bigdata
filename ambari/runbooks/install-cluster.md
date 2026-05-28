# Ambari 集群安装 Runbook

## 1. 目标

本文档用于指导通过 Apache Ambari 安装 Hadoop 基础集群。

## 2. 前置条件

- 所有主机已完成 OS 初始化
- 主机之间网络互通
- 主机名与 DNS / hosts 配置正确
- SSH 免密或 Ambari Agent 安装方式已准备
- 防火墙、SELinux、时间同步等基础项已检查
- Ambari Server 已安装并启动

## 3. 安装步骤

### 3.1 注册主机

在 Ambari Web UI 中添加目标主机，或通过自动化脚本注册主机。

### 3.2 选择服务

第一阶段建议选择：

- HDFS
- YARN
- MapReduce2
- ZooKeeper
- Hive
- Spark History Server

### 3.3 分配组件角色

单节点测试环境可使用 `ambari/blueprints/single-node-hadoop.json`。

生产环境应至少拆分：

- Master 节点
- Worker 节点
- Gateway 节点

### 3.4 修改配置

重点检查：

- `core-site.xml`
- `hdfs-site.xml`
- `yarn-site.xml`
- `mapred-site.xml`
- `hive-site.xml`

### 3.5 启动服务

建议启动顺序：

```text
ZooKeeper -> HDFS -> YARN -> MapReduce2 -> Hive -> Spark
```

### 3.6 服务检查

使用 Ambari Web UI 或脚本执行服务检查：

```bash
cd ambari/scripts
./service-check.sh HDFS
./service-check.sh YARN
./service-check.sh HIVE
```

## 4. 验收标准

- Ambari Dashboard 无 Critical 告警
- HDFS NameNode / DataNode 状态正常
- YARN ResourceManager / NodeManager 状态正常
- HiveServer2 与 Metastore 正常
- 服务检查全部通过

## 5. 回滚策略

如果安装失败：

1. 记录失败步骤与 Ambari request id
2. 查看失败组件日志
3. 修复配置或主机环境
4. 重新执行 failed step 或重装服务
