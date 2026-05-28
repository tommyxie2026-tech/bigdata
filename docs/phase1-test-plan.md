# Phase 1 测试计划

## 1. 文档目标

本文档定义 Bigdata Platform 第一阶段传统数仓物理机 HA 底座的测试目标、测试范围、测试环境、测试类型、验收标准和 Agent 分工。

## 2. 测试基线

| 项目 | 标准 |
|---|---|
| OS | Ubuntu 22.04 |
| JDK | JDK 8，预留 JDK 17 兼容评估 |
| 集群规模 | 3 Master + 3 Worker + 1 Gateway |
| 管理面 | Ambari |
| 构建体系 | Bigtop |
| 交付形态 | Bigtop 包仓库 + Ambari Blueprint + Runbook + Smoke Test |
| 安全 | Kerberos 设计保留，不默认启用 |

## 3. 测试范围

### 3.1 构建测试

- Bigtop 构建环境验证
- Ubuntu 22.04 DEB 包构建
- apt 仓库元数据验证
- 包安装与卸载验证

### 3.2 管理面测试

- Ambari Server 安装
- Ambari Agent 注册
- Repository 配置
- Blueprint 安装
- 服务启停
- Service Check

### 3.3 组件功能测试

- ZooKeeper
- HDFS HA
- YARN HA
- Hive Metastore / HiveServer2
- Spark
- HBase

### 3.4 HA 测试

- NameNode Failover
- ResourceManager Failover
- HBase Master Failover
- HiveServer2 多实例可用性
- ZooKeeper 节点状态检查

### 3.5 Smoke Test

- HDFS 文件操作
- YARN 任务提交
- Hive SQL
- Spark 任务
- HBase 表操作

## 4. 测试环境

```text
master-01
master-02
master-03
worker-01
worker-02
worker-03
gateway-01
```

## 5. 测试阶段

```text
T0: 文档检查
T1: 包构建测试
T2: 仓库发布测试
T3: Ambari 安装测试
T4: Blueprint 部署测试
T5: 服务功能测试
T6: HA 验证测试
T7: Smoke Test
T8: Runbook 演练
T9: 验收评审
```

## 6. 详细测试项

### 6.1 Bigtop 测试

| 编号 | 测试项 | 预期结果 |
|---|---|---|
| BT-001 | 构建 Hadoop 包 | 构建成功 |
| BT-002 | 构建 Hive 包 | 构建成功 |
| BT-003 | 构建 Spark 包 | 构建成功 |
| BT-004 | 构建 HBase 包 | 构建成功 |
| BT-005 | 发布 apt 仓库 | apt update 成功 |
| BT-006 | 安装组件包 | apt install 成功 |

### 6.2 Ambari 测试

| 编号 | 测试项 | 预期结果 |
|---|---|---|
| AM-001 | Ambari Server 安装 | 安装成功 |
| AM-002 | Ambari Agent 注册 | 7 节点 Agent 在线 |
| AM-003 | Repository 配置 | Ambari 可识别仓库 |
| AM-004 | Blueprint 导入 | Blueprint 创建成功 |
| AM-005 | 服务安装 | 核心服务安装成功 |
| AM-006 | Service Check | 检查通过 |

### 6.3 HDFS 测试

| 编号 | 测试项 | 预期结果 |
|---|---|---|
| HDFS-001 | NameNode Active/Standby | 状态正常 |
| HDFS-002 | DataNode 注册 | 3 个 DataNode 在线 |
| HDFS-003 | 文件写入读取 | 成功 |
| HDFS-004 | NameNode Failover | 可切换 |

### 6.4 YARN 测试

| 编号 | 测试项 | 预期结果 |
|---|---|---|
| YARN-001 | ResourceManager HA | Active/Standby 正常 |
| YARN-002 | NodeManager 注册 | 3 个 NodeManager 在线 |
| YARN-003 | 提交测试任务 | 成功 |
| YARN-004 | ResourceManager Failover | 可切换 |

### 6.5 Hive 测试

| 编号 | 测试项 | 预期结果 |
|---|---|---|
| HIVE-001 | Metastore 启动 | 正常 |
| HIVE-002 | HiveServer2 启动 | 正常 |
| HIVE-003 | 创建库表 | 成功 |
| HIVE-004 | SQL 查询 | 成功 |

### 6.6 Spark 测试

| 编号 | 测试项 | 预期结果 |
|---|---|---|
| SPARK-001 | spark-submit | 成功 |
| SPARK-002 | Spark SQL 访问 Hive | 成功 |
| SPARK-003 | History Server | 可查看任务 |

### 6.7 HBase 测试

| 编号 | 测试项 | 预期结果 |
|---|---|---|
| HBASE-001 | HBase Master 启动 | 正常 |
| HBASE-002 | RegionServer 注册 | 3 个 RegionServer 在线 |
| HBASE-003 | 创建 Namespace | 成功 |
| HBASE-004 | 创建表 | 成功 |
| HBASE-005 | put/get/scan | 成功 |
| HBASE-006 | HBase Master Failover | 有验证路径 |

## 7. Runbook 演练

需要演练：

- 集群安装 Runbook
- 服务重启 Runbook
- HDFS 故障恢复 Runbook
- HBase 故障恢复 Runbook
- 巡检 Runbook

## 8. 缺陷分级

| 级别 | 说明 |
|---|---|
| Blocker | 阻塞安装、核心服务不可用、数据不可读写 |
| Critical | HA 失效、关键组件不稳定 |
| Major | 部分功能失败，但有绕过方案 |
| Minor | 文档、提示、非核心功能问题 |

## 9. 退出标准

Phase 1 测试通过需要满足：

- Bigtop 包仓库可用
- Ambari 可完成部署
- 核心服务启动成功
- HDFS/YARN/Hive/Spark/HBase Smoke Test 通过
- HA 验证项有明确结果
- Runbook 至少完成安装与重启演练
- Blocker / Critical 缺陷清零

## 10. Agent 分工

| Agent | 职责 |
|---|---|
| Build Agent | Bigtop 构建与仓库测试 |
| Ambari Agent | Ambari 安装和 Blueprint 测试 |
| Hadoop Agent | HDFS/YARN HA 测试 |
| Warehouse Agent | Hive/Spark 测试 |
| HBase Agent | HBase 功能与 HA 测试 |
| QA Agent | Smoke Test、缺陷跟踪、验收报告 |
| Review Agent | 测试结果评审 |

## 11. 后续待办

- [ ] 补充测试用例模板
- [ ] 补充缺陷记录模板
- [ ] 补充验收报告模板
- [ ] 补充自动化 Smoke Test 脚本规划
