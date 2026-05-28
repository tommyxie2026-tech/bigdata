# Bigdata Platform 运维体系设计

## 1. 文档目标

本文档用于定义 Bigdata Platform 的标准化运维体系，包括服务生命周期管理、配置变更、监控告警、巡检、容量管理、故障恢复和交付验收。

第一阶段以 Ambari 管理的传统 Hadoop 数仓底座为主，后续扩展到实时数据湖和云原生环境。

## 2. 运维目标

平台运维体系需要实现：

- 可安装
- 可配置
- 可监控
- 可告警
- 可巡检
- 可恢复
- 可扩容
- 可升级
- 可验收

## 3. 运维对象

| 对象 | 说明 |
|---|---|
| Cluster | 大数据集群整体 |
| Host | 物理机、虚拟机或容器节点 |
| Service | HDFS、YARN、Hive、Spark、Kafka、Flink 等服务 |
| Component | NameNode、DataNode、ResourceManager、HiveServer2 等组件角色 |
| Configuration | 服务配置项 |
| Alert | 告警规则与告警事件 |
| Job | Spark、Hive、Flink 等任务 |
| Data | HDFS 文件、Hive 表、Lakehouse 表 |

## 4. 运维流程总览

```text
安装部署
  -> 配置变更
  -> 服务启停
  -> 监控告警
  -> 日常巡检
  -> 容量管理
  -> 故障恢复
  -> 版本升级
  -> 交付验收
```

## 5. 安装部署运维

### 5.1 标准流程

```text
环境检查
  -> 主机初始化
  -> Ambari Server / Agent 安装
  -> Repository 配置
  -> Blueprint / Install Wizard
  -> 服务启动
  -> Service Check
  -> Smoke Test
  -> 交付确认
```

### 5.2 验收点

- Ambari Dashboard 正常
- 所有主机 Agent 在线
- 核心服务 Started
- HDFS / YARN / Hive / Spark 检查通过
- Smoke Test 通过
- 关键告警清零或确认无影响

## 6. 配置变更管理

### 6.1 变更原则

- 所有配置变更必须有记录
- 生产环境配置变更必须有回滚方案
- 影响服务重启的配置必须进入维护窗口
- 配置变更后必须执行服务检查

### 6.2 标准流程

```text
提出变更
  -> 影响评估
  -> 审核确认
  -> 修改配置
  -> 重启受影响服务
  -> 执行 Service Check
  -> 观察监控
  -> 记录变更结果
```

### 6.3 配置分类

| 类型 | 示例 | 影响 |
|---|---|---|
| 存储配置 | HDFS 副本数、数据目录 | 可能影响数据可靠性 |
| 资源配置 | YARN 内存、CPU、队列 | 影响任务调度 |
| SQL 配置 | HiveServer2、Metastore | 影响查询服务 |
| 安全配置 | Kerberos、权限 | 影响访问控制 |
| 性能配置 | Spark 参数、压缩参数 | 影响任务性能 |

## 7. 服务生命周期管理

### 7.1 标准状态

```text
Installed
Started
Stopped
Restart Required
Maintenance Mode
Unknown
```

### 7.2 操作类型

- Start
- Stop
- Restart
- Rolling Restart
- Service Check
- Maintenance Mode

### 7.3 推荐依赖顺序

```text
ZooKeeper
  -> HDFS
  -> YARN
  -> Hive Metastore
  -> HiveServer2
  -> Spark History Server
  -> 其他服务
```

## 8. 监控与告警设计

### 8.1 第一阶段核心指标

| 组件 | 指标 |
|---|---|
| Host | CPU、内存、磁盘、网络、负载 |
| HDFS | 容量、块数、副本、NameNode 状态、DataNode 状态 |
| YARN | 队列资源、NodeManager 状态、应用数量 |
| Hive | HiveServer2 状态、Metastore 状态、连接数 |
| Spark | History Server 状态、任务历史、应用失败数 |
| Ambari | Agent 状态、服务告警、配置状态 |

### 8.2 告警分级

| 级别 | 说明 | 示例 |
|---|---|---|
| Critical | 影响核心服务可用性 | NameNode 不可用、磁盘满 |
| Warning | 存在风险但未中断服务 | DataNode 丢失、容量过高 |
| Info | 状态变化或提示 | 配置需要重启 |

## 9. 日常巡检

### 9.1 巡检频率

| 类型 | 频率 |
|---|---|
| 基础健康检查 | 每日 |
| 容量检查 | 每日 / 每周 |
| 告警检查 | 每日 |
| 配置变更检查 | 每次变更后 |
| 备份检查 | 每周 |
| 灾备演练 | 每季度 |

### 9.2 巡检内容

- Ambari Dashboard 状态
- 主机在线状态
- HDFS 容量与块健康
- YARN 资源利用率
- Hive / Spark 服务状态
- 关键告警
- 最近失败任务
- 磁盘与日志目录

## 10. 容量管理

### 10.1 容量对象

- HDFS 存储容量
- YARN 计算资源
- Hive Metastore 数据库容量
- 日志目录容量
- 临时目录容量
- Kafka Topic 容量，后续阶段
- Flink Checkpoint 容量，后续阶段

### 10.2 容量水位

| 水位 | 行动 |
|---|---|
| 70% | 关注趋势 |
| 80% | 发出预警，准备扩容或清理 |
| 90% | 进入高风险状态，必须处理 |
| 95% | 严重风险，可能影响服务 |

## 11. 故障恢复

### 11.1 故障分类

| 类型 | 示例 |
|---|---|
| 主机故障 | 节点宕机、磁盘故障、网络故障 |
| 服务故障 | NameNode、ResourceManager、HiveServer2 异常 |
| 配置故障 | 参数错误、配置不一致 |
| 数据故障 | HDFS 块丢失、表损坏、数据延迟 |
| 任务故障 | Spark/Hive/Flink 任务失败 |

### 11.2 恢复原则

- 先恢复核心服务可用性
- 再恢复数据完整性
- 再恢复任务调度
- 最后分析根因并补充 runbook

## 12. 版本升级

版本升级应遵循：

```text
版本评估
  -> 兼容性验证
  -> 测试环境升级
  -> 回滚方案
  -> 生产维护窗口
  -> 升级执行
  -> 验证与观察
```

## 13. 第一阶段 Runbook 清单

| Runbook | 状态 |
|---|---|
| 集群安装 Runbook | 已有初版 |
| 服务重启 Runbook | 已有初版 |
| HDFS 恢复 Runbook | 已有初版 |
| YARN 故障恢复 Runbook | 待补充 |
| Hive 故障恢复 Runbook | 待补充 |
| Spark 故障恢复 Runbook | 待补充 |
| 扩容 Runbook | 待补充 |
| 升级 Runbook | 待补充 |

## 14. 后续待办

- [ ] 补充 YARN 恢复手册
- [ ] 补充 Hive 恢复手册
- [ ] 补充 Spark 任务故障排查手册
- [ ] 补充扩容流程
- [ ] 补充升级流程
- [ ] 补充监控告警指标表
- [ ] 补充生产巡检模板
