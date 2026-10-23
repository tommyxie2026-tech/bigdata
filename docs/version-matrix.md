# Phase 1 版本矩阵设计

> 2026-10-11 基线说明：本文保留历史设计讨论。当前 openEuler/RPM 版本、七节点配置、Runbook 与验收入口以 [Phase 1 交付设计](phase1-delivery-design.md) 为准；旧 Ubuntu/DEB 和候选版本指令不可用于当前 RC1 部署。

## 当前交付与回归矩阵（2026-10-23）

> 这张表记录仓库当前实际锁定和发布状态，不代表完整集群验收。版本取自主线 `ci/components.yaml`、RPM 仓库 manifest 和最新主线 push CI；“已发布”表示仓库中存在对应 manifest/checksum，不等于 Ambari 七节点部署验收通过。本次核验主线 SHA：`a3e673b8e5a9671afaa29310c3dd84eb323c7dde`。独立 CDC 契约分别见 `scripts/flink-cdc-mysql/contract.json` 和 `scripts/flink-cdc-postgres/contract.json`；其发布状态单独列出，不混入既有 catalog。Metrics 和 S3A SDK 也按独立契约列出；测试 fixture、代理配置不计为已发布运行时组件。

本次逐项核对 `ci/components.yaml`、19 组发布 manifest、`SHA256SUMS` 与 RPM 文件名集合，共 **78 个已发布 RPM 条目**（含 Ambari、公共依赖、独立 CDC、SDK 和 Metrics；不计 Bigtop 构建基线为独立 RPM）。相较 10 月 22 日，组件版本未变；本次更新核验基线和包数量，不表示重新构建或重跑所有专项。

| 层级 | 组件 | 当前版本 | RPM 数量 | 运行时 / OS | 状态与证据 |
| --- | --- | ---: | ---: | --- | --- |
| 管理面 | Apache Ambari | 3.0.0 | 3 | JDK 17；openEuler 22.03 LTS SP4 | RPM 仓库已发布，3 个 RPM，manifest 标记 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/ambari/3.0.0/manifest.yaml) |
| 管理观测 | Ambari Metrics | 3.0.0；RPM Release `1.oe2203sp4` | 2 | Collector JDK 8；Monitor Python 3；内嵌 HBase 2.4.13 / Phoenix 5.1.2；openEuler 22.03 LTS SP4 | Collector/Monitor 两个 RPM 已发布；[真实安装、CPU/内存采集及重启持久化 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39653729447)；[主干候选与晋级流程 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39691186873)；[#123 已合并](https://github.com/tommyxie2026-tech/bigdata/pull/123)；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/ambari-metrics/3.0.0/manifest.yaml)。不代表 Ambari 集群监控接入验收 |
| 构建基线 | Apache Bigtop | 3.6.0 | — | `branch-3.6` | 主线构建基线；不是单独的运行时 RPM 发布项 |
| 公共依赖 | Bigtop common | 3.6.0 | 3 | openEuler 22.03 LTS SP4 | RPM 仓库已发布，manifest 标记 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/common/3.6.0/manifest.yaml) |
| 协调 | ZooKeeper | 3.8.4 | 4 | Bigtop 3.6.0 | RPM 仓库已发布，4 个 RPM，manifest 标记 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/zookeeper/3.8.4/manifest.yaml) |
| 存储与资源 | Hadoop / HDFS / YARN | 3.4.3 | 23 | Bigtop 3.6.0 | RPM 仓库已发布，23 个 RPM，manifest 标记 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/hadoop/3.4.3/manifest.yaml) |
| 存储客户端依赖 | Hadoop S3A AWS SDK | 2.35.4；RPM Release `1.oe2203sp4` | 1 | Hadoop 3.4.3 / JDK 8；可选依赖 RPM | [HTTPS/S3A/API、multipart、权限拒绝与重启读取 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39621962743)；[#106 已合并](https://github.com/tommyxie2026-tech/bigdata/pull/106)；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/hadoop-aws-sdk/2.35.4/manifest.yaml)。不是生产对象存储服务包 |
| SQL 执行 | Hive | 4.0.1 | 9 | Bigtop 3.6.0 | RPM 仓库已发布，9 个 RPM，manifest 标记 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/hive/4.0.1/manifest.yaml) |
| 执行引擎 | Tez | 0.10.5 | 1 | Bigtop 3.6.0 | RPM 仓库已发布，1 个 RPM，manifest 标记 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/tez/0.10.5/manifest.yaml) |
| 批处理 | Spark | 3.5.8 | 11 | Bigtop 3.6.0 | RPM 仓库已发布，11 个 RPM，manifest 标记 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/spark/3.5.8/manifest.yaml) |
| 宽表 | HBase | 2.6.5 | 6 | Bigtop 3.6.0 | RPM 仓库已发布，6 个 RPM，manifest 标记 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/hbase/2.6.5/manifest.yaml) |
| 消息队列 | Kafka | 3.4.1 | 2 | JDK 8；openEuler 22.03 LTS SP4 | RPM 仓库已发布，KRaft smoke manifest 标记 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/kafka/3.4.1/manifest.yaml) |
| 流计算 | Flink | 1.20.1 | 3 | JDK 11；openEuler 22.03 LTS SP4 | RPM 仓库已发布，local-job smoke manifest 标记 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/flink/1.20.1/manifest.yaml) |
| 数据接入 | Flink CDC MySQL | 3.4.0；RPM Release `1.oe2203sp4` | 1 | Flink 1.20.1 / JDK 11；MySQL 8.0.36 与 JDBC 8.0.27 为测试 fixture | [RPM 已发布](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/flink-cdc-mysql/3.4.0/manifest.yaml)；[#100](https://github.com/tommyxie2026-tech/bigdata/pull/100) 已合并；[主线 Test / RC / 发布作业 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39106575363)；原始 Build `39102586103`，发布清单 Test `39104310948` |
| 数据接入 | Flink CDC PostgreSQL | 3.4.0；RPM Release `1.oe2203sp4` | 1 | Flink 1.20.1 / JDK 11；PostgreSQL 14.15 为测试 fixture，JDBC 包含于 upstream shaded JAR | [RPM 已发布](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/flink-cdc-postgres/3.4.0/manifest.yaml)，[#102](https://github.com/tommyxie2026-tech/bigdata/pull/102) 已合并；[主线实际 Test / RC / 晋级 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39139306230)；复用 Build `39124662344`，Test `39139306230` |
| 查询引擎 | Trino | 483 | 1 | JDK 25；openEuler 22.03 LTS SP4 | RPM 仓库已发布，single-node smoke manifest 标记 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/trino/483/manifest.yaml) |
| 湖仓格式 | Iceberg | 1.12.0 | 2 | JDK 17；Spark 3.5.8 / Flink 1.20.1 | 两个 integration RPM 已发布，manifest 标记 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/iceberg/1.12.0/manifest.yaml)；[双 CDC→Iceberg/HDFS 恢复 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554289) |
| 湖仓格式 | Hudi | 1.2.1 | 2 | JDK 11；Spark 3.5.8 / Flink 1.20.1 | 两个 integration RPM 已发布；[真实跨引擎回归 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39043226367)。[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/hudi/1.2.1/manifest.yaml) 引用 run `39035814730`：聚合状态 cancelled，但实际 Test/Release 作业 success；见下方分层状态说明；[双 CDC→Hudi/HDFS 恢复 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554558) |
| 湖仓格式 | Paimon | 2.1.0 | 2 | JDK 11；Spark 3.5.8 / Flink 1.20.1 | 两个 integration RPM 已发布；[主线安装、更新与双向互读 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39048307642)；复用 build `39013588597`，非重新编译；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/paimon/2.1.0/manifest.yaml)；[双 CDC→Paimon/HDFS 恢复 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554220) |
| 查询 UI | Hue | 4.11.0；RPM Release `2.oe2203sp4` | 1 | Python 3.9；Gunicorn；Trino 483 使用 JDK 25 | 一个 service RPM 已发布；[主线安装、启动、Hue→Trino 查询与 RC PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39086875001)，[晋级 PR #96](https://github.com/tommyxie2026-tech/bigdata/pull/96) 已合并；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/hue/4.11.0/manifest.yaml) |

### 当前状态口径

[本次主干 CI](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39701083586) 与 [基线一致性检查](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39701083592) 均通过；本次主干只新增文档，组件交付证据仍沿用实际运行与发布来源。此前普通 CI 与分层发布审计通过；[完整 Build Components](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689437161) 已 success。来源记录保留原始 build/test run，RPM 复用与新构建分开表述。Metrics/CDC/SDK 的独立契约证据分别核验，不属于既有七组件通用分层审计的自动覆盖范围。

- “RPM 已发布”以仓库中的 RPM、`SHA256SUMS`、manifest 和 repodata 为准；“功能 PASS”必须有实际专项测试成功证据。复用包、skipped 或 cancelled 不能替代功能测试。
- Hudi manifest 引用 run `39035814730`；API 的 run 聚合状态为 cancelled，但该 run 最新 attempt 的实际 Test、Release 和 gate 作业均为 success。后续 run `39043226367` 的跨引擎回归也为 success。需按 run/attempt/job 与产物逐层审计，不只看 run 聚合状态或 manifest 的 `test_status: PASS` 字段。
- [既有 7 个 v2 组件分层审计](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39102320767) 已通过；该审计不包含独立 CDC 契约或 v1 manifests。
- CDC MySQL/PostgreSQL 已从独立 JDBC sink 验收扩展到真实湖仓 sink：Paimon [本地](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554165) / [HDFS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554220) / [HTTPS S3](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554168)、[Hudi/HDFS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554558)、[Iceberg/HDFS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554289) 主干专项均 PASS，覆盖精确行集、实际 checkpoint/savepoint、停止期间源端变更和恢复后读取。未据此宣称所有故障窗口的端到端 exactly-once、schema 演进或生产 HA；MySQL JDBC 驱动不包含在连接器 RPM 中。
- Paimon 已完成主线测试和仓库晋级。Hue 通过 PR #95 切换 Gunicorn；`4.11.0-2` 复用旧包内已编译应用，只更新启动器和重打包，未重编前端/Python 依赖。
- Hue 的 `4.11.0` 是钉住源码提交自报版本，来源是 `65d9e489f400ac151029b33c5a2bd9df31e167da` 的开发快照；不能将其描述为新 upstream 稳定发行。Hue 测试使用临时 SQLite 元数据库，不代表生产 PostgreSQL/MySQL、HA 或 TLS 已验收。
- JDK 是逐组件边界：Hue 应用为 Python；JDK 25 服务于 Trino 集成测试，不表示 Hue 本身要求 JDK 25。HDFS 上三种湖仓格式与 Paimon/HTTPS S3 已有上述专项测试；不能外推为 Hudi/Iceberg 的 S3 全覆盖、生产集群 HA 或 Trino 共享 catalog 已验收。
- 本轮后续新增组件及集成测试见 [组件 CI 补齐计划](component-ci-backlog.md)。以下第 1—12 节保留历史候选与评估记录，不覆盖上表的实际交付版本。

## 1. 文档目标

本文档定义 Bigdata Platform 第一阶段的基础版本矩阵、兼容性评估维度和后续版本确认流程。

第一阶段目标是在 openEuler 22.x 上，以 JDK 8 为默认运行时，通过 Bigtop 构建和发布大数据组件包，并预留 JDK 17 兼容性评估。

版本选择原则：

```text
社区最新稳定版本优先，同时兼顾未来升级路径；
每一组组件版本必须经确认后再进入 Phase 1 候选矩阵；
进入候选矩阵不等于冻结，冻结必须完成 Bigtop 构建、Ambari 管理和集群验证。
```

## 2. 已确认基线

| 项目 | 结果 |
|---|---|
| OS | openEuler 22.x |
| 默认 JDK | JDK 8 |
| 兼容性评估 | JDK 17 |
| 构建体系 | Apache Bigtop 3.6.0（当前稳定版） |
| 管理面 | Apache Ambari 3.0.0（当前稳定版） |
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
| Bigtop | 3.6.0 | 3.5.0 | 以 3.6.0 为当前上游稳定构建基线；3.5.0 作为历史/回退参考 | 已更新，待验证 |

### 4.2 存储与协调底座

| 组件 | Phase 1 优先候选 | 兼容/回退候选 | 升级策略 | 状态 |
|---|---:|---:|---|---|
| Hadoop | 3.5.0 | 3.4.3 / 3.3.6 | 以 3.5.x 作为未来主线；如 Bigtop/Ambari 适配不通过，回退到 3.4.3 或 3.3.6 | 已确认候选，不冻结，待 Bigtop 3.6.0 构建与 Ambari 3.0.0 管理验证 |
| ZooKeeper | 3.9.5 | 3.8.6 | 以 3.9.x 作为未来主线；如兼容性不足，回退到 3.8.6 | 已确认候选，不冻结，待 Bigtop 3.6.0 构建与 Ambari 3.0.0 管理验证 |

### 4.3 数仓 SQL 与执行引擎

| 组件 | Phase 1 优先候选 | 兼容/回退候选 | 升级策略 | 状态 |
|---|---:|---:|---|---|
| Hive | 4.2.0 | Hive 4.1.x / 3.x 兼容线待评估 | 以 Hive 4.x 作为未来主线；如 Ambari/Bigtop/JDK/Hadoop 适配不通过，回退到 4.1.x 或 3.x 兼容线 | 已确认候选，不冻结，待 Bigtop 3.6.0 构建、Ambari 3.0.0 管理、Hadoop 3.5.0 和 JDK 8 兼容性验证 |
| Hive Standalone Metastore | 4.2.0 | 3.0.0 | 随 Hive 4.2.0 优先验证；3.0.0 作为兼容回退评估 | 已确认候选，不冻结，待 Spark SQL 访问 Metastore 兼容性验证 |
| Tez | 0.10.5 | 0.10.4 / 0.10.3 | 以 0.10.5 作为优先候选，随 Hive 4.2.0 验证；必要时回退到 0.10.4 / 0.10.3 | 已确认候选，不冻结，待 Hive 执行引擎适配验证 |

### 4.4 批处理与离线 SQL 引擎

| 组件 | Phase 1 优先候选 | 兼容/回退候选 | 升级策略 | 状态 |
|---|---:|---:|---|---|
| Spark | 3.5.8 | 3.4.x | Spark 3.5.x 作为 Phase 1 稳定主线；Spark 4.1.x 作为未来升级评估，面向后续 Spark on Kubernetes 和新生态兼容 | 已确认候选，不冻结，待 Bigtop 3.6.0 构建、Ambari 3.0.0 管理、Hadoop 3.5.0、JDK 8、Hive Metastore 4.2.0 兼容性验证 |
| Spark Upgrade Evaluation | 4.1.x | N/A | 作为未来升级评估，不进入 Phase 1 主线 | 已确认升级评估项 |

### 4.5 宽表存储

| 组件 | Phase 1 优先候选 | 兼容/回退候选 | 升级策略 | 状态 |
|---|---:|---:|---|---|
| HBase | 2.5.14 | 2.5.13 | HBase 2.5.x 作为 Phase 1 稳定主线；2.6.5 作为未来升级评估；3.0.0-beta-1 仅作为远期技术观察 | 已确认候选，不冻结，待 Bigtop 3.6.0 构建、Ambari 3.0.0 管理、Hadoop 3.5.0、ZooKeeper 3.9.5、JDK 8 兼容性验证 |
| HBase Upgrade Evaluation | 2.6.5 | N/A | 作为未来升级评估，不进入 Phase 1 主线 | 已确认升级评估项 |
| HBase Technical Watch | 3.0.0-beta-1 | N/A | Beta 版本，仅远期技术观察 | 不进入 Phase 1 |


## 4.6 Bigtop 3.6.0 Upstream BOM 对照

Bigtop 3.6.0 升级后，必须区分“Bigtop 上游稳定 BOM”和“BIGDATA 项目目标 BOM”。

| Component | Bigtop 3.6.0 upstream | BIGDATA existing target | Delta |
|---|---:|---:|---|
| ZooKeeper | 3.8.4 | 3.9.5 | PROJECT_NEWER |
| Hadoop | 3.4.3 | 3.5.0 | PROJECT_NEWER |
| HBase | 2.6.5 | 2.5.14 | UPSTREAM_NEWER |
| Hive | 4.0.1 | 4.2.0 | PROJECT_NEWER |
| Tez | 0.10.5 | 0.10.5 | UPSTREAM_MATCH |
| Spark | 3.5.8 | 3.5.8 | UPSTREAM_MATCH |

版本策略因此调整为：

```text
先验证 Bigtop 3.6.0 upstream BOM
  -> 再评估项目自定义 BOM 差异
  -> 只有存在明确需求时才保留自定义版本
  -> 不因“版本更新”本身增加适配面
```

在完成 BOM Delta Review 前，ZooKeeper/Hadoop/Hive/HBase 的项目目标版本仍为候选，不视为冻结版本。

## 5. 待确认版本组

所有 Phase 1 P0 组件候选版本已完成逐组确认，当前均为候选或升级评估状态，尚未冻结。

## 6. 版本矩阵

| 组件 | 目标版本 | 兼容/回退版本 | openEuler 22.x | JDK 8 | JDK 17 评估 | Bigtop 构建 | Ambari 管理 | 备注 |
|---|---|---|---|---|---|---|---|---|
| Ambari | 3.0.0 | 2.7.9 | 必须验证 | 必须验证 | 评估 | 可选 | 是 | 传统大数据长期管理面；已确认，待验证 |
| Ambari Metrics | 3.0.0 | TBD | 必须验证 | 必须验证 | 评估 | 可选 | 是 | 与 Ambari 3.0.0 同步验证 |
| Bigtop | 3.6.0 | 3.5.0 | 必须验证 | 必须验证 | 评估 | 是 | 否 | 真实构建体系；已确认，待验证 |
| Hadoop | 3.5.0 | 3.4.3 / 3.3.6 | 必须验证 | 必须验证 | 评估 | 是 | 是 | 社区最新稳定优先候选，不冻结；需验证 Bigtop 3.6.0 构建与 Ambari 3.0.0 管理适配 |
| ZooKeeper | 3.9.5 | 3.8.6 | 必须验证 | 必须验证 | 评估 | 是 | 是 | 社区最新稳定优先候选，不冻结；需验证 Bigtop 3.6.0 构建与 Ambari 3.0.0 管理适配 |
| Hive | 4.2.0 | 4.1.x / 3.x 兼容线待评估 | 必须验证 | 必须验证 | 评估 | 是 | 是 | 社区最新稳定优先候选，不冻结；需验证 Bigtop 3.6.0、Ambari 3.0.0、Hadoop 3.5.0、JDK 8 兼容性 |
| Hive Standalone Metastore | 4.2.0 | 3.0.0 | 必须验证 | 必须验证 | 评估 | 是 | 是 | 随 Hive 4.2.0 优先验证；需验证 Spark SQL 访问 Metastore 兼容性 |
| Tez | 0.10.5 | 0.10.4 / 0.10.3 | 必须验证 | 必须验证 | 评估 | 是/可选 | 是/可选 | Hive 执行引擎候选，随 Hive 4.2.0 验证 |
| Spark | 3.5.8 | 3.4.x | 必须验证 | 必须验证 | 评估 | 是 | 是 | Phase 1 优先候选，不冻结；需验证 Hadoop 3.5.0、Hive Metastore 4.2.0、JDK 8、Ambari/Bigtop 适配 |
| Spark Upgrade Evaluation | 4.1.x | N/A | 评估 | 可能不适用 | 评估 | 评估 | 评估 | 未来升级评估，不进入 Phase 1 主线 |
| HBase | 2.5.14 | 2.5.13 | 必须验证 | 必须验证 | 评估 | 是 | 是 | Phase 1 优先候选，不冻结；需验证 Hadoop 3.5.0、ZooKeeper 3.9.5、JDK 8、Ambari/Bigtop 适配 |
| HBase Upgrade Evaluation | 2.6.5 | N/A | 评估 | 评估 | 评估 | 评估 | 评估 | 未来升级评估，不进入 Phase 1 主线 |
| HBase Technical Watch | 3.0.0-beta-1 | N/A | 不要求 | 不要求 | 观察 | 不要求 | 不要求 | Beta 版本，仅远期技术观察 |

## 7. 兼容性评估维度

### 7.1 OS 兼容性

openEuler 22.x 下需要验证：

- 包依赖是否完整
- systemd 服务是否正常
- 用户、目录、权限是否符合预期
- DNF/YUM 仓库元数据是否正确
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

- Bigtop 3.6.0 构建目标是否支持 openEuler 22.x
- RPM 包是否成功输出
- DNF/YUM 仓库是否可发布
- 包名是否与 Ambari 期望一致
- 包依赖是否满足 Ambari 安装流程

### 7.5 Hadoop / ZooKeeper 特别验证项

Hadoop 3.5.0 与 ZooKeeper 3.9.5 作为社区最新稳定优先候选，但不立即冻结，必须额外验证：

- Bigtop 3.6.0 是否支持对应版本构建
- Ambari 3.0.0 是否能安装、配置、启停和检查对应版本
- HDFS HA 与 YARN HA 是否正常
- ZooKeeper 与 HDFS/YARN/HBase 的协调关系是否稳定
- 与 Hive、Spark、HBase 后续候选版本是否存在依赖冲突

### 7.6 Hive / Metastore / Tez 特别验证项

Hive 4.2.0、Hive Standalone Metastore 4.2.0 与 Tez 0.10.5 作为社区最新稳定优先候选，但不立即冻结，必须额外验证：

- Bigtop 3.6.0 是否支持 Hive 4.2.0、Metastore 4.2.0、Tez 0.10.5 构建
- Ambari 3.0.0 是否能安装、配置、启停和检查 Hive 4.2.0
- Hive 4.2.0 与 Hadoop 3.5.0 的兼容性
- Hive 4.2.0 在 JDK 8 下的运行兼容性
- HiveServer2 与 Hive Metastore 多实例部署是否稳定
- Spark SQL 访问 Hive Standalone Metastore 4.2.0 是否兼容
- Tez 0.10.5 是否适合作为 Hive 执行引擎

### 7.7 Spark 特别验证项

Spark 3.5.8 作为 Phase 1 优先候选，但不立即冻结，必须额外验证：

- Bigtop 3.6.0 是否支持 Spark 3.5.8 构建
- Ambari 3.0.0 是否能安装、配置、启停和检查 Spark 3.5.8
- Spark on YARN 是否兼容 Hadoop 3.5.0
- Spark SQL 是否兼容 Hive Standalone Metastore 4.2.0
- Spark 在 JDK 8 下是否稳定运行
- Spark 4.1.x 作为未来升级评估时，对 JDK、Hadoop、Hive Metastore 和 Kubernetes 的要求

### 7.8 HBase 特别验证项

HBase 2.5.14 作为 Phase 1 优先候选，但不立即冻结，必须额外验证：

- Bigtop 3.6.0 是否支持 HBase 2.5.14 构建
- Ambari 3.0.0 是否能安装、配置、启停和检查 HBase 2.5.14
- HBase 2.5.14 是否兼容 Hadoop 3.5.0
- HBase 2.5.14 是否兼容 ZooKeeper 3.9.5
- HBase 2.5.14 在 JDK 8 下是否稳定运行
- HBase Master / RegionServer HA 是否可验证
- HBase 2.6.5 作为未来升级评估时，对 Hadoop、ZooKeeper、JDK 和 Ambari 的要求

## 8. 版本确认流程

```text
候选版本收集
  -> 用户逐组确认
  -> Bigtop 可构建性检查
  -> openEuler 22.x 安装验证
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

## 11. Upstream Stable Baseline

截至 2026-09-30：

```yaml
ambari: 3.0.0
bigtop: 3.6.0
```

关联决策：

- `docs/adr/ADR-018-ambari-bigtop-stable-baseline.md`

## 12. 后续待办

- [x] 确认 Ambari 候选版本
- [x] 确认 Bigtop 当前稳定版：3.6.0
- [x] 确认 Hadoop / ZooKeeper 候选版本，状态为待验证不冻结
- [x] 确认 Hive / Tez 候选版本，状态为待验证不冻结
- [x] 确认 Spark 候选版本，状态为待验证不冻结
- [x] 确认 HBase 候选版本，状态为待验证不冻结
- [ ] 完成 Bigtop 3.6.0 upstream BOM 与 BIGDATA target BOM Delta Review
- [ ] 补充 JDK 17 兼容性评估结果
- [ ] 冻结 Phase 1 版本矩阵
