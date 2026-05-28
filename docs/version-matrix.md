# Phase 1 版本矩阵设计

## 1. 文档目标

本文档定义 Bigdata Platform 第一阶段的基础版本矩阵、兼容性评估维度和后续版本确认流程。

第一阶段目标是在 Ubuntu 22.04 上，以 JDK 8 为默认运行时，通过 Bigtop 构建和发布大数据组件包，并预留 JDK 17 兼容性评估。

版本选择原则：

```text
社区最新稳定版本优先，同时兼顾未来升级路径；
每一组组件版本必须经确认后再进入 Phase 1 候选矩阵；
进入候选矩阵不等于冻结，冻结必须完成 Bigtop 构建、Ambari 管理和集群验证。
```

## 2. 已确认基线

| 项目 | 结果 |
|---|---|
| OS | Ubuntu 22.04 |
| 默认 JDK | JDK 8 |
| 兼容性评估 | JDK 17 |
| 构建体系 | Bigtop 真实构建体系 |
| 管理面 | Ambari 最新可维护社区/发行版兼容版本 |
| 验证规模 | 3 Master + 3 Worker + 1 Gateway |

## 3. 第一阶段组件范围

| 组件 | 阶段 | 必选 | 说明 |
|---|---|---|---|
| Ambari | Phase 1 | 是 | 传统大数据长期管理面 |
| Ambari Metrics | Phase 1 | 是 | Ambari 指标体系，随 Ambari 主版本验证 |
| Bigtop | Phase 1 | 是 | 真实构建、包仓库、版本管理 |
| ZooKeeper | Phase 1 | 是 | HA 协调服务 |
| Hadoop / HDFS / YARN | Phase 1 | 是 | 存储与资源管理底座 |
| Hive | Phase 1 | 是 | Metastore 与 HiveServer2 |
| Hive Standalone Metastore | Phase 1 | 是 | 元数据服务候选形态，随 Hive 版本验证 |
| Spark | Phase 1 | 是 | 批处理与离线 SQL 补充 |
| HBase | Phase 1 | 是 | 宽表存储，进入真实验证范围 |
| Tez | Phase 1 | 待定 | Hive 执行引擎，按 Hive 版本决定 |

## 4. 已确认版本组

### 4.1 管理面与构建体系

| 组件 | Phase 1 主候选 | 兼容/回退候选 | 升级策略 | 状态 |
|---|---:|---:|---|---|
| Ambari | 3.0.0 | 2.7.9 | 以 3.x 为长期管理面基线，2.7.9 仅作为兼容回退 | 已确认，待验证 |
| Ambari Metrics | 3.0.0 | TBD | 与 Ambari 3.0.0 同步验证 | 已确认，待验证 |
| Bigtop | 3.5.0 | 3.4.0 | 以 3.5.0 为构建体系基线，后续跟随 Bigtop stable release 升级 | 已确认，待验证 |

### 4.2 存储与协调底座

| 组件 | Phase 1 优先候选 | 兼容/回退候选 | 升级策略 | 状态 |
|---|---:|---:|---|---|
| Hadoop | 3.5.0 | 3.4.3 / 3.3.6 | 以 3.5.x 作为未来主线；如 Bigtop/Ambari 适配不通过，回退到 3.4.3 或 3.3.6 | 已确认候选，不冻结，待 Bigtop 3.5.0 构建与 Ambari 3.0.0 管理验证 |
| ZooKeeper | 3.9.5 | 3.8.6 | 以 3.9.x 作为未来主线；如兼容性不足，回退到 3.8.6 | 已确认候选，不冻结，待 Bigtop 3.5.0 构建与 Ambari 3.0.0 管理验证 |

### 4.3 数仓 SQL 与执行引擎

| 组件 | Phase 1 优先候选 | 兼容/回退候选 | 升级策略 | 状态 |
|---|---:|---:|---|---|
| Hive | 4.2.0 | Hive 4.1.x / 3.x 兼容线待评估 | 以 Hive 4.x 作为未来主线；如 Ambari/Bigtop/JDK/Hadoop 适配不通过，回退到 4.1.x 或 3.x 兼容线 | 已确认候选，不冻结，待 Bigtop 3.5.0 构建、Ambari 3.0.0 管理、Hadoop 3.5.0 和 JDK 8 兼容性验证 |
| Hive Standalone Metastore | 4.2.0 | 3.0.0 | 随 Hive 4.2.0 优先验证；3.0.0 作为兼容回退评估 | 已确认候选，不冻结，待 Spark SQL 访问 Metastore 兼容性验证 |
| Tez | 0.10.5 | 0.10.4 / 0.10.3 | 以 0.10.5 作为优先候选，随 Hive 4.2.0 验证；必要时回退到 0.10.4 / 0.10.3 | 已确认候选，不冻结，待 Hive 执行引擎适配验证 |

## 5. 待确认版本组

后续按依赖顺序逐组确认：

1. Spark
2. HBase

## 6. 版本矩阵

| 组件 | 目标版本 | 兼容/回退版本 | Ubuntu 22.04 | JDK 8 | JDK 17 评估 | Bigtop 构建 | Ambari 管理 | 备注 |
|---|---|---|---|---|---|---|---|---|
| Ambari | 3.0.0 | 2.7.9 | 必须验证 | 必须验证 | 评估 | 可选 | 是 | 传统大数据长期管理面；已确认，待验证 |
| Ambari Metrics | 3.0.0 | TBD | 必须验证 | 必须验证 | 评估 | 可选 | 是 | 与 Ambari 3.0.0 同步验证 |
| Bigtop | 3.5.0 | 3.4.0 | 必须验证 | 必须验证 | 评估 | 是 | 否 | 真实构建体系；已确认，待验证 |
| Hadoop | 3.5.0 | 3.4.3 / 3.3.6 | 必须验证 | 必须验证 | 评估 | 是 | 是 | 社区最新稳定优先候选，不冻结；需验证 Bigtop 3.5.0 构建与 Ambari 3.0.0 管理适配 |
| ZooKeeper | 3.9.5 | 3.8.6 | 必须验证 | 必须验证 | 评估 | 是 | 是 | 社区最新稳定优先候选，不冻结；需验证 Bigtop 3.5.0 构建与 Ambari 3.0.0 管理适配 |
| Hive | 4.2.0 | 4.1.x / 3.x 兼容线待评估 | 必须验证 | 必须验证 | 评估 | 是 | 是 | 社区最新稳定优先候选，不冻结；需验证 Bigtop 3.5.0、Ambari 3.0.0、Hadoop 3.5.0、JDK 8 兼容性 |
| Hive Standalone Metastore | 4.2.0 | 3.0.0 | 必须验证 | 必须验证 | 评估 | 是 | 是 | 随 Hive 4.2.0 优先验证；需验证 Spark SQL 访问 Metastore 兼容性 |
| Tez | 0.10.5 | 0.10.4 / 0.10.3 | 必须验证 | 必须验证 | 评估 | 是/可选 | 是/可选 | Hive 执行引擎候选，随 Hive 4.2.0 验证 |
| Spark | TBD | TBD | 必须验证 | 必须验证 | 评估 | 是 | 是 | 批处理 |
| HBase | TBD | TBD | 必须验证 | 必须验证 | 评估 | 是 | 是 | 宽表存储 |

## 7. 兼容性评估维度

### 7.1 OS 兼容性

Ubuntu 22.04 下需要验证：

- 包依赖是否完整
- systemd 服务是否正常
- 用户、目录、权限是否符合预期
- apt 仓库元数据是否正确
- Ambari Agent 是否可正常执行安装命令

### 7.2 JDK 兼容性

JDK 8 是第一阶段默认基线。JDK 17 只做兼容性评估，不作为第一阶段默认要求。

评估项：

- 编译是否通过
- 服务是否启动
- 客户端命令是否可用
- Hive / Spark / HBase 是否有反射、模块化、依赖冲突问题
- Ambari 与组件脚本是否兼容

### 7.3 Ambari 兼容性

需要验证：

- Ambari Server 安装
- Ambari Agent 安装
- Repository 配置
- Stack / Service 识别
- Blueprint 安装流程
- Service Check
- 告警与配置下发

### 7.4 Bigtop 构建兼容性

需要验证：

- Bigtop 构建目标是否支持 Ubuntu 22.04
- DEB 包是否成功输出
- apt 仓库是否可发布
- 包名是否与 Ambari 期望一致
- 包依赖是否满足 Ambari 安装流程

### 7.5 Hadoop / ZooKeeper 特别验证项

Hadoop 3.5.0 与 ZooKeeper 3.9.5 作为社区最新稳定优先候选，但不立即冻结，必须额外验证：

- Bigtop 3.5.0 是否支持对应版本构建
- Ambari 3.0.0 是否能安装、配置、启停和检查对应版本
- HDFS HA 与 YARN HA 是否正常
- ZooKeeper 与 HDFS/YARN/HBase 的协调关系是否稳定
- 与 Hive、Spark、HBase 后续候选版本是否存在依赖冲突

### 7.6 Hive / Metastore / Tez 特别验证项

Hive 4.2.0、Hive Standalone Metastore 4.2.0 与 Tez 0.10.5 作为社区最新稳定优先候选，但不立即冻结，必须额外验证：

- Bigtop 3.5.0 是否支持 Hive 4.2.0、Metastore 4.2.0、Tez 0.10.5 构建
- Ambari 3.0.0 是否能安装、配置、启停和检查 Hive 4.2.0
- Hive 4.2.0 与 Hadoop 3.5.0 的兼容性
- Hive 4.2.0 在 JDK 8 下的运行兼容性
- HiveServer2 与 Hive Metastore 多实例部署是否稳定
- Spark SQL 访问 Hive Standalone Metastore 4.2.0 是否兼容
- Tez 0.10.5 是否适合作为 Hive 执行引擎

## 8. 版本确认流程

```text
候选版本收集
  -> 用户逐组确认
  -> Bigtop 可构建性检查
  -> Ubuntu 22.04 安装验证
  -> JDK 8 运行验证
  -> Ambari 管理验证
  -> 3M3W1G 集群验证
  -> JDK 17 兼容性评估
  -> 版本矩阵冻结
```

## 9. 冻结标准

一个组件版本进入 Phase 1 基线，需要满足：

- 可构建
- 可安装
- 可由 Ambari 管理
- 可通过 Service Check
- 可通过 Smoke Test
- 与其他 P0 组件没有阻塞级兼容冲突
- 具备后续升级路径

## 10. Agent 分工

| Agent | 职责 |
|---|---|
| Version Agent | 候选版本收集、兼容性矩阵维护 |
| Bigtop Agent | 构建验证、包仓库验证 |
| Ambari Agent | 管理面安装与 Service Check 验证 |
| QA Agent | Smoke Test 与集成验证 |
| Review Agent | 冻结版本矩阵 |

## 11. 后续待办

- [x] 确认 Ambari 候选版本
- [x] 确认 Bigtop 候选版本或分支
- [x] 确认 Hadoop / ZooKeeper 候选版本，状态为待验证不冻结
- [x] 确认 Hive / Tez 候选版本，状态为待验证不冻结
- [ ] 确认 Spark 候选版本
- [ ] 确认 HBase 候选版本
- [ ] 补充 JDK 17 兼容性评估结果
- [ ] 冻结 Phase 1 版本矩阵
