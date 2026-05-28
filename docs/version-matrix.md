# Phase 1 版本矩阵设计

## 1. 文档目标

本文档定义 Bigdata Platform 第一阶段的基础版本矩阵、兼容性评估维度和后续版本确认流程。

第一阶段目标是在 Ubuntu 22.04 上，以 JDK 8 为默认运行时，通过 Bigtop 构建和发布大数据组件包，并预留 JDK 17 兼容性评估。

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
| Bigtop | Phase 1 | 是 | 真实构建、包仓库、版本管理 |
| ZooKeeper | Phase 1 | 是 | HA 协调服务 |
| Hadoop / HDFS / YARN | Phase 1 | 是 | 存储与资源管理底座 |
| Hive | Phase 1 | 是 | Metastore 与 HiveServer2 |
| Spark | Phase 1 | 是 | 批处理与离线 SQL 补充 |
| HBase | Phase 1 | 是 | 宽表存储，进入真实验证范围 |
| Tez | Phase 1 | 待定 | Hive 执行引擎，按 Hive 版本决定 |

## 4. 版本矩阵模板

> 当前版本号先保持 TBD。后续由 Version Agent 和 Bigtop Agent 根据 Ubuntu 22.04、JDK 8、Ambari 兼容性和 Bigtop 可构建性共同确认。

| 组件 | 目标版本 | Ubuntu 22.04 | JDK 8 | JDK 17 评估 | Bigtop 构建 | Ambari 管理 | 备注 |
|---|---|---|---|---|---|---|---|
| Ambari | TBD | 必须验证 | 必须验证 | 评估 | 可选 | 是 | 最新可维护兼容版本 |
| Bigtop | TBD | 必须验证 | 必须验证 | 评估 | 是 | 否 | 构建体系 |
| Hadoop | TBD | 必须验证 | 必须验证 | 评估 | 是 | 是 | HDFS / YARN |
| ZooKeeper | TBD | 必须验证 | 必须验证 | 评估 | 是 | 是 | HA 协调 |
| Hive | TBD | 必须验证 | 必须验证 | 评估 | 是 | 是 | Metastore / HS2 |
| Spark | TBD | 必须验证 | 必须验证 | 评估 | 是 | 是 | 批处理 |
| HBase | TBD | 必须验证 | 必须验证 | 评估 | 是 | 是 | 宽表存储 |
| Tez | TBD | 视 Hive 决定 | 视 Hive 决定 | 评估 | 是/可选 | 是/可选 | Hive 执行引擎 |

## 5. 兼容性评估维度

### 5.1 OS 兼容性

Ubuntu 22.04 下需要验证：

- 包依赖是否完整
- systemd 服务是否正常
- 用户、目录、权限是否符合预期
- apt 仓库元数据是否正确
- Ambari Agent 是否可正常执行安装命令

### 5.2 JDK 兼容性

JDK 8 是第一阶段默认基线。JDK 17 只做兼容性评估，不作为第一阶段默认要求。

评估项：

- 编译是否通过
- 服务是否启动
- 客户端命令是否可用
- Hive / Spark / HBase 是否有反射、模块化、依赖冲突问题
- Ambari 与组件脚本是否兼容

### 5.3 Ambari 兼容性

需要验证：

- Ambari Server 安装
- Ambari Agent 安装
- Repository 配置
- Stack / Service 识别
- Blueprint 安装流程
- Service Check
- 告警与配置下发

### 5.4 Bigtop 构建兼容性

需要验证：

- Bigtop 构建目标是否支持 Ubuntu 22.04
- DEB 包是否成功输出
- apt 仓库是否可发布
- 包名是否与 Ambari 期望一致
- 包依赖是否满足 Ambari 安装流程

## 6. 版本确认流程

```text
候选版本收集
  -> Bigtop 可构建性检查
  -> Ubuntu 22.04 安装验证
  -> JDK 8 运行验证
  -> Ambari 管理验证
  -> 3M3W1G 集群验证
  -> JDK 17 兼容性评估
  -> 版本矩阵冻结
```

## 7. 冻结标准

一个组件版本进入 Phase 1 基线，需要满足：

- 可构建
- 可安装
- 可由 Ambari 管理
- 可通过 Service Check
- 可通过 Smoke Test
- 与其他 P0 组件没有阻塞级兼容冲突

## 8. Agent 分工

| Agent | 职责 |
|---|---|
| Version Agent | 候选版本收集、兼容性矩阵维护 |
| Bigtop Agent | 构建验证、包仓库验证 |
| Ambari Agent | 管理面安装与 Service Check 验证 |
| QA Agent | Smoke Test 与集成验证 |
| Review Agent | 冻结版本矩阵 |

## 9. 后续待办

- [ ] 确认 Ambari 候选版本
- [ ] 确认 Bigtop 候选版本或分支
- [ ] 确认 Hadoop / Hive / Spark / HBase / ZooKeeper 候选版本
- [ ] 补充 JDK 17 兼容性评估结果
- [ ] 冻结 Phase 1 版本矩阵
