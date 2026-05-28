# Phase 1 版本验证计划

## 1. 文档目标

本文档定义 Bigdata Platform Phase 1 候选版本矩阵的验证计划，用于将“已确认候选版本”推进到“可冻结版本基线”。

当前所有 P0 组件候选版本均已确认，但尚未冻结。冻结必须经过 Bigtop 构建、Ambari 管理、Ubuntu 22.04、JDK 8、JDK 17 兼容性评估和 3M3W1G 集群验证。

## 2. 当前候选版本矩阵

| 组件 | Phase 1 候选 | 回退/评估 | 状态 |
|---|---:|---:|---|
| Ambari | 3.0.0 | 2.7.9 | 候选，不冻结 |
| Ambari Metrics | 3.0.0 | TBD | 候选，不冻结 |
| Bigtop | 3.5.0 | 3.4.0 | 候选，不冻结 |
| Hadoop | 3.5.0 | 3.4.3 / 3.3.6 | 候选，不冻结 |
| ZooKeeper | 3.9.5 | 3.8.6 | 候选，不冻结 |
| Hive | 4.2.0 | 4.1.x / 3.x | 候选，不冻结 |
| Hive Standalone Metastore | 4.2.0 | 3.0.0 | 候选，不冻结 |
| Tez | 0.10.5 | 0.10.4 / 0.10.3 | 候选，不冻结 |
| Spark | 3.5.8 | 3.4.x | 候选，不冻结 |
| Spark Upgrade Evaluation | 4.1.x | N/A | 未来升级评估 |
| HBase | 2.5.14 | 2.5.13 | 候选，不冻结 |
| HBase Upgrade Evaluation | 2.6.5 | N/A | 未来升级评估 |
| HBase Technical Watch | 3.0.0-beta-1 | N/A | 远期技术观察 |

## 3. 验证目标

Phase 1 版本验证需要回答以下问题：

1. Bigtop 3.5.0 是否能构建候选组件版本？
2. 候选组件包是否能发布为 Ubuntu 22.04 apt 仓库？
3. Ambari 3.0.0 是否能识别、安装、配置、启停和检查这些组件？
4. JDK 8 是否能作为默认运行时支撑候选版本？
5. JDK 17 是否具备未来兼容路径？
6. 3 Master + 3 Worker + 1 Gateway 是否能完成 HA 集群验证？
7. 如果主候选失败，回退版本是否具备可用路径？

## 4. 验证阶段

```text
V0: 候选版本矩阵审查
V1: Bigtop 构建验证
V2: apt 仓库发布验证
V3: Ambari 安装与 Repository 对接验证
V4: 单组件服务验证
V5: 3M3W1G 集群验证
V6: HA 与故障切换验证
V7: JDK 17 兼容性评估
V8: 回退版本验证
V9: 版本冻结评审
```

## 5. V1：Bigtop 构建验证

### 5.1 验证内容

| 组件 | 候选版本 | 验证项 |
|---|---:|---|
| Hadoop | 3.5.0 | DEB 包构建、依赖解析、安装路径 |
| ZooKeeper | 3.9.5 | DEB 包构建、服务脚本、systemd 适配 |
| Hive | 4.2.0 | HiveServer2、Metastore、依赖包构建 |
| Hive Standalone Metastore | 4.2.0 | 独立 Metastore 构建与依赖 |
| Tez | 0.10.5 | 构建与 Hive 集成依赖 |
| Spark | 3.5.8 | Spark on YARN、Spark SQL 相关依赖 |
| HBase | 2.5.14 | Master、RegionServer、HDFS/ZooKeeper 依赖 |

### 5.2 验收标准

- 所有 P0 组件可构建 DEB 包
- 包依赖完整
- 构建过程可重复
- 构建失败有记录和回退建议

## 6. V2：apt 仓库发布验证

### 6.1 验证内容

- 仓库目录结构正确
- apt metadata 可生成
- Ubuntu 22.04 节点可执行 `apt update`
- 候选组件包可查询
- 候选组件包可安装
- 回退版本可通过仓库快照或版本策略保留

### 6.2 验收标准

- apt 仓库可被 Ambari 节点访问
- 包版本可控
- 仓库具备回滚设计

## 7. V3：Ambari 安装与 Repository 对接验证

### 7.1 验证内容

- Ambari Server 3.0.0 安装
- Ambari Agent 安装与心跳
- Ambari Metrics 3.0.0 安装
- Bigtop apt 仓库接入
- Repository 配置可保存
- Blueprint 可引用目标组件

### 7.2 验收标准

- 7 个节点 Agent 在线
- Ambari 可识别目标仓库
- Ambari 可执行组件安装流程

## 8. V4：单组件服务验证

| 组件 | 验证项 |
|---|---|
| ZooKeeper | 3 节点集群、状态检查、客户端连接 |
| HDFS | NameNode、DataNode、JournalNode、文件读写 |
| YARN | ResourceManager、NodeManager、任务提交 |
| Hive | Metastore、HiveServer2、建库建表查询 |
| Tez | Hive on Tez 执行验证 |
| Spark | spark-submit、Spark SQL、History Server |
| HBase | Master、RegionServer、建表、put/get/scan |

## 9. V5：3M3W1G 集群验证

目标拓扑：

```text
3 Master + 3 Worker + 1 Gateway
```

验证项：

- master-01 / master-02 / master-03 角色分布正确
- worker-01 / worker-02 / worker-03 服务正常
- gateway-01 客户端可用
- Ambari Dashboard 状态正常
- 所有核心服务 Started
- Service Check 通过
- Smoke Test 通过

## 10. V6：HA 与故障切换验证

| 组件 | 验证项 |
|---|---|
| ZooKeeper | 单节点异常后集群仍可用 |
| HDFS | NameNode Active / Standby 切换 |
| YARN | ResourceManager Active / Standby 切换 |
| Hive | Metastore / HiveServer2 多实例可用 |
| HBase | HBase Master 切换，RegionServer 正常 |

## 11. V7：JDK 17 兼容性评估

JDK 17 不作为 Phase 1 默认运行时，只作为未来升级评估。

评估维度：

- 构建是否可通过
- 服务是否可启动
- 客户端命令是否可用
- 反射、模块化、依赖冲突风险
- Spark 4.1.x、HBase 2.6.5 等未来版本的 JDK 要求

## 12. V8：回退版本验证

当主候选验证失败时，按以下顺序回退：

| 组件 | 主候选 | 回退策略 |
|---|---:|---|
| Ambari | 3.0.0 | 回退 2.7.9 |
| Bigtop | 3.5.0 | 回退 3.4.0 |
| Hadoop | 3.5.0 | 回退 3.4.3，再评估 3.3.6 |
| ZooKeeper | 3.9.5 | 回退 3.8.6 |
| Hive | 4.2.0 | 回退 4.1.x / 3.x 兼容线 |
| Metastore | 4.2.0 | 回退 3.0.0 |
| Tez | 0.10.5 | 回退 0.10.4 / 0.10.3 |
| Spark | 3.5.8 | 回退 3.4.x |
| HBase | 2.5.14 | 回退 2.5.13 |

## 13. V9：版本冻结评审

版本冻结必须满足：

- Bigtop 构建通过
- apt 仓库发布通过
- Ambari 安装与管理通过
- JDK 8 运行验证通过
- 3M3W1G 集群验证通过
- HA 验证有明确结果
- Smoke Test 通过
- Blocker / Critical 缺陷清零
- 回退策略明确

## 14. Agent 分工

| Agent | 职责 |
|---|---|
| Version Agent | 维护版本矩阵、跟踪冻结状态 |
| Bigtop Agent | 构建与仓库验证 |
| Ambari Agent | 管理面、Repository、Blueprint 验证 |
| Hadoop Agent | ZooKeeper、HDFS、YARN 验证 |
| Warehouse Agent | Hive、Tez、Spark 验证 |
| HBase Agent | HBase 验证 |
| QA Agent | Smoke Test、缺陷记录、验收报告 |
| Review Agent | 版本冻结评审 |

## 15. 输出物

- 构建验证记录
- apt 仓库验证记录
- Ambari 安装验证记录
- 组件服务验证记录
- HA 故障切换验证记录
- JDK 17 兼容性评估记录
- 回退版本验证记录
- 版本冻结评审结论

## 16. 后续待办

- [ ] 为每个验证阶段创建检查表
- [ ] 为 Bigtop 构建验证创建 Issue
- [ ] 为 Ambari 管理适配创建 Issue
- [ ] 为 JDK 17 兼容性评估创建 Issue
- [ ] 为 3M3W1G 集群验证创建 Issue
