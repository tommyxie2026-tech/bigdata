# Phase 1 验收标准

## 1. 文档目标

本文档定义 Bigdata Platform 第一阶段传统数仓物理机 HA 底座的交付验收标准。

第一阶段交付形态为：

```text
Bigtop 包仓库 + Ambari Blueprint + Runbook + Smoke Test
```

## 2. 验收基线

| 项目 | 标准 |
|---|---|
| OS | Ubuntu 22.04 |
| JDK | JDK 8，预留 JDK 17 兼容评估 |
| 集群规模 | 3 Master + 3 Worker + 1 Gateway |
| 管理面 | Ambari |
| 构建体系 | Bigtop |
| 安全 | Kerberos 设计保留，不默认启用 |
| 组件 | ZooKeeper、HDFS、YARN、Hive、Spark、HBase |

## 3. 交付物验收

| 交付物 | 验收标准 |
|---|---|
| Bigtop 包仓库 | Ubuntu 22.04 apt 仓库可访问，核心组件包可安装 |
| Ambari Blueprint | 可描述 3M3W1G 拓扑和核心组件角色 |
| 配置模板 | HDFS、YARN、Hive、Spark、HBase 配置项完整 |
| Runbook | 安装、重启、恢复、巡检流程可执行 |
| Smoke Test | 覆盖 HDFS、YARN、Hive、Spark、HBase 基础验证 |
| 架构文档 | 平台定位、部署设计、组件矩阵、运维设计完整 |

## 4. Bigtop 构建验收

### 4.1 包构建

- Hadoop 包可构建
- Hive 包可构建
- Spark 包可构建
- HBase 包可构建
- ZooKeeper 相关依赖可构建或可被仓库解析

### 4.2 仓库发布

- apt 仓库元数据正确
- Ubuntu 22.04 节点可执行 `apt update`
- 核心组件包可查询
- 核心组件包可安装
- 仓库支持版本隔离和回滚规划

## 5. Ambari 验收

- Ambari Server 可访问
- 7 个节点 Ambari Agent 均在线
- Ambari 可识别目标 Repository
- Ambari 可安装核心服务
- Ambari 可下发配置
- Ambari 可执行 Service Check
- Ambari 可展示服务状态和告警

## 6. HA 验收

### 6.1 ZooKeeper

- 3 节点正常运行
- 集群状态正常
- HDFS / YARN / HBase 可正常连接 ZooKeeper

### 6.2 HDFS HA

- Active / Standby NameNode 正常
- JournalNode 正常
- DataNode 正常注册
- HDFS 文件写入、读取、删除正常
- NameNode Failover 有验证路径

### 6.3 YARN HA

- ResourceManager Active / Standby 正常
- NodeManager 正常注册
- 简单 MapReduce 或 Spark 任务可运行
- ResourceManager Failover 有验证路径

### 6.4 Hive

- Hive Metastore 可用
- HiveServer2 可连接
- 可创建库、表
- 可执行基础 SQL 查询
- Hive 与 HDFS / YARN / Spark 集成正常

### 6.5 Spark

- Spark Client 可提交任务
- Spark History Server 可查看任务历史
- Spark SQL 可访问 Hive Metastore

### 6.6 HBase

- HBase Master 正常
- RegionServer 正常注册
- 可创建 Namespace
- 可创建表
- 可写入、读取、scan 数据
- HBase Master 故障切换有验证路径

## 7. Smoke Test 验收

Smoke Test 至少覆盖：

```text
HDFS:
  mkdir / put / cat / rm

YARN:
  node list / application submit

Hive:
  create database / create table / insert / select

Spark:
  spark-submit / Spark SQL / History Server

HBase:
  create namespace / create table / put / get / scan / drop
```

## 8. 运维验收

### 8.1 Runbook

以下 Runbook 至少需要有文档：

- 集群安装
- 服务重启
- HDFS 故障恢复
- HBase 故障恢复
- 巡检
- 扩容，设计保留
- 升级，设计保留

### 8.2 巡检

巡检至少覆盖：

- Ambari Dashboard
- 主机状态
- HDFS 容量
- YARN 资源
- Hive 服务状态
- Spark History Server
- HBase Master / RegionServer
- 关键告警

## 9. 性能与容量验收

第一阶段不要求完成压测基准，但需要完成容量与性能观测项定义：

- HDFS 总容量和使用率
- YARN 总资源和可用资源
- Hive 查询基础可用性
- Spark 任务基础可用性
- HBase 基础读写可用性

## 10. 安全验收

Kerberos 第一阶段设计保留，不默认启用。

第一阶段安全验收包括：

- 主机访问权限规划
- Ambari 管理账号规划
- 服务账号规划
- Kerberos 后续启用路径说明

## 11. 文档验收

核心设计文档应至少包括：

- 平台总览
- 架构决策记录
- 路线图
- 部署设计
- 组件矩阵
- Ambari 管理面设计
- Bigtop 构建体系设计
- HBase 设计
- 运维体系设计
- 验收标准

## 12. 退出标准

当以下条件满足时，Phase 1 可认为达到设计与验证闭环：

1. 3M3W1G 拓扑设计完成
2. Bigtop 包仓库设计完成并具备验证路径
3. Ambari Blueprint 设计完成
4. HDFS / YARN / Hive / Spark / HBase 验证项明确
5. Runbook 与 Smoke Test 设计完成
6. 所有 P0 文档通过 Review Agent 审查

## 13. 后续待办

- [ ] 补充实际 Smoke Test 脚本清单
- [ ] 补充验收检查表模板
- [ ] 补充故障切换验证步骤
- [ ] 补充性能基准测试计划
- [ ] 补充安全启用路线图
