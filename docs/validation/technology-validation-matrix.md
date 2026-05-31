# P3-001 Technology Validation Matrix

## 1. 文档目标

本文档用于记录 BIGDATA-1.0 第一轮真实技术验证矩阵，目标是从架构假设进入证据驱动验证。

当前阶段不再继续扩大架构抽象，而是优先验证 BIGDATA-1.0 的两个最高风险前提：

```text
Ambari 3.0.0 是否可作为 BIGDATA-1.0 管理后端
Bigtop 3.5.0 是否可作为 BIGDATA-1.0 构建体系
```

## 2. 验证原则

```text
设计文档不是事实
验证结果才是事实
```

所有候选版本必须经过：

```text
候选假设
  -> 公开资料核验
  -> 源码/构建验证
  -> 安装验证
  -> 集成验证
  -> 证据归档
  -> 结论冻结
```

## 3. 当前已核对的公开事实

| 项目 | 公开事实 | 初步结论 |
|---|---|---|
| Ambari 3.0.0 | Apache 下载目录存在 `ambari-3.0.0` 源码包与校验文件 | 可进入源码验证 |
| Ambari Metrics 3.0.0 | Apache 下载目录存在 `ambari-metrics-3.0.0` 目录 | 可进入源码验证 |
| Bigtop 3.5.0 | Bigtop 官网将 3.5.0 标为 latest stable release，并提供下载入口 | 可进入构建验证 |
| Bigtop binary artifacts | Bigtop 下载页提供 installable binary artifacts 入口 | 可进入仓库验证 |

## 4. 第一轮 P0 验证对象

| 验证项 | 候选版本 | 风险等级 | 验证目标 | 状态 |
|---|---:|---|---|---|
| Ambari | 3.0.0 | 极高 | 验证是否可作为 BIGDATA-1.0 管理后端 | 待验证 |
| Ambari Metrics | 3.0.0 | 高 | 验证是否可与 Ambari 3.0.0 一起工作 | 待验证 |
| Bigtop | 3.5.0 | 极高 | 验证是否可作为 BIGDATA-1.0 构建体系 | 待验证 |
| Ubuntu | 22.04 | 高 | 验证 Ambari/Bigtop 与 Ubuntu 22.04 兼容性 | 待验证 |
| JDK | 8 | 高 | 验证 Ambari/Bigtop 与 JDK 8 兼容性 | 待验证 |

## 5. 第二轮 P0 验证对象

| 验证项 | 候选版本 | 风险等级 | 依赖 | 状态 |
|---|---:|---|---|---|
| Hadoop | 3.5.0 | 高 | Bigtop 构建、Ambari 管理 | 待验证 |
| ZooKeeper | 3.9.5 | 中 | Bigtop 构建、Ambari 管理 | 待验证 |
| Hive | 4.2.0 | 高 | Hadoop、Tez、Metastore、Ambari | 待验证 |
| Hive Standalone Metastore | 4.2.0 | 高 | Hive、Spark SQL | 待验证 |
| Tez | 0.10.5 | 中 | Hive | 待验证 |
| Spark | 3.5.8 | 中 | Hadoop、Hive Metastore | 待验证 |
| HBase | 2.5.14 | 中 | Hadoop、ZooKeeper | 待验证 |

## 6. Ambari 3.0.0 验证矩阵

| 编号 | 验证问题 | 验证方式 | 期望结论 | 状态 |
|---|---|---|---|---|
| A1 | Ambari 3.0.0 是否存在 ASF 正式源码发布 | Apache 下载目录核验、签名核验 | PASS | 初步 PASS，待签名校验 |
| A2 | Ambari 3.0.0 是否可在 Ubuntu 22.04 构建 | 本地/CI 构建 | PASS / FAIL | 待验证 |
| A3 | Ambari 3.0.0 是否支持 JDK 8 | 构建与运行验证 | PASS / FAIL | 待验证 |
| A4 | Ambari 3.0.0 是否可安装 Ambari Server | Ubuntu 22.04 安装验证 | PASS / FAIL | 待验证 |
| A5 | Ambari Agent 是否可注册 7 节点 | 3M3W1G 验证 | PASS / FAIL | 待验证 |
| A6 | Ambari Repository 是否可接入 Bigtop apt 仓库 | Repository 对接验证 | PASS / FAIL | 待验证 |
| A7 | Ambari 是否可管理 Hadoop 3.5.0 | Stack/Service 验证 | PASS / FAIL | 待验证 |
| A8 | Ambari 是否可管理 Hive/Spark/HBase 候选版本 | Stack/Service 验证 | PASS / FAIL | 待验证 |
| A9 | Ambari Metrics 3.0.0 是否可用 | Metrics 安装验证 | PASS / FAIL | 待验证 |
| A10 | Ambari 2.7.9 回退路径是否可行 | 回退验证 | PASS / FAIL | 待验证 |

## 7. Bigtop 3.5.0 验证矩阵

| 编号 | 验证问题 | 验证方式 | 期望结论 | 状态 |
|---|---|---|---|---|
| B1 | Bigtop 3.5.0 是否为公开 latest stable release | Bigtop 官网核验 | PASS | 初步 PASS |
| B2 | Bigtop 3.5.0 是否可在 Ubuntu 22.04 构建 | 构建验证 | PASS / FAIL | 待验证 |
| B3 | Bigtop 3.5.0 是否支持 DEB 输出 | 构建配置验证 | PASS / FAIL | 待验证 |
| B4 | Bigtop 3.5.0 是否可构建 Hadoop 3.5.0 | 构建验证 | PASS / FAIL | 待验证 |
| B5 | Bigtop 3.5.0 是否可构建 ZooKeeper 3.9.5 | 构建验证 | PASS / FAIL | 待验证 |
| B6 | Bigtop 3.5.0 是否可构建 Hive 4.2.0 | 构建验证 | PASS / FAIL | 待验证 |
| B7 | Bigtop 3.5.0 是否可构建 Spark 3.5.8 | 构建验证 | PASS / FAIL | 待验证 |
| B8 | Bigtop 3.5.0 是否可构建 HBase 2.5.14 | 构建验证 | PASS / FAIL | 待验证 |
| B9 | Bigtop 3.5.0 是否可生成 apt 仓库 | 仓库验证 | PASS / FAIL | 待验证 |
| B10 | Bigtop 3.4.0 回退路径是否可行 | 回退验证 | PASS / FAIL | 待验证 |

## 8. 结论状态模型

```text
PASS
FAIL
PARTIAL
BLOCKED
UNKNOWN
```

## 9. 风险等级

| 等级 | 说明 |
|---|---|
| 极高 | 失败会导致 BIGDATA-1.0 主路线重审 |
| 高 | 失败会导致候选版本回退或设计调整 |
| 中 | 失败可通过回退版本或局部适配解决 |
| 低 | 对主路线影响较小 |

## 10. 第一阶段决策门槛

### Gate 1: Ambari / Bigtop 可行性门槛

必须回答：

```text
Ambari 3.0.0 是否可作为 BIGDATA-1.0 管理后端？
Bigtop 3.5.0 是否可作为 BIGDATA-1.0 构建体系？
```

### Gate 1 决策结果

| Ambari | Bigtop | 决策 |
|---|---|---|
| PASS | PASS | 继续当前 BIGDATA-1.0 路线 |
| FAIL | PASS | 保留 Bigtop，重审管理后端 |
| PASS | FAIL | 保留 Ambari，重审构建/包仓库体系 |
| FAIL | FAIL | BIGDATA-1.0 技术路线重审 |

## 11. 证据归档路径

```text
validation/
├── ambari/
├── bigtop/
├── hadoop/
├── hive/
├── spark/
├── hbase/
├── repositories/
└── reports/
```

## 12. 下一步

优先创建并执行：

- P3-001-A Ambari 3.0.0 Validation
- P3-001-B Bigtop 3.5.0 Validation
