# Bigdata Platform 组件矩阵

> 2026-10-11 基线说明：本文保留历史设计讨论。当前 openEuler/RPM 版本、七节点配置、Runbook 与验收入口以 [Phase 1 交付设计](phase1-delivery-design.md) 为准；旧 Ubuntu/DEB 和候选版本指令不可用于当前 RC1 部署。

## 1. 文档目标

本文档用于定义 Bigdata Platform 的组件范围、阶段归属、管理方式、交付优先级和组合策略。

平台目标是同时支持传统数仓与实时数据湖，并允许组件按场景灵活组合交付。

## 2. 已确认组件决策

| 决策 | 结果 |
|---|---|
| 第一阶段产品形态 | 可部署的私有化大数据平台方案 |
| 第一阶段范围 | 传统数仓物理机底座 |
| 第一阶段 HA | 必须纳入第一阶段目标 |
| Ambari 定位 | 传统大数据平台长期管理面 |
| Bigtop 定位 | 真实构建体系 |
| 自定义 Ambari Stack | 远期规划，不进入第一阶段主线 |
| 实时数据湖主线 | Iceberg + Flink |
| 对象存储 | 第三阶段引入 S3 兼容对象存储 |

## 3. 组件分层

```text
管理面：Ambari / Kubernetes / Operator
构建发行层：Bigtop / Package Repo / Version Matrix
存储层：HDFS / HBase / Object Storage
资源层：YARN / Kubernetes
计算层：Spark / Flink / MapReduce
SQL 层：Hive / Trino / Spark SQL
消息与接入层：Kafka / CDC Connector
湖仓层：Iceberg / Hudi / Paimon / Delta Lake
治理安全层：Kerberos / Ranger / Knox / Atlas
运维观测层：Ambari Metrics / Prometheus / Logs / Alerting
```

## 4. 阶段组件矩阵

| 组件 | 类型 | Phase 1 传统数仓 | Phase 3 实时数据湖 | Phase 5 云原生 | 管理方式 | 优先级 |
|---|---|---|---|---|---|---|
| Ambari | 管理面 | 必选 | 保留传统集群管理 | 与 K8s 协同 | Ambari Server | P0 |
| Bigtop | 构建发行 | 必选，真实构建 | 继续维护版本/包 | 可扩展/替换 | Build/Repo | P0 |
| ZooKeeper | 协调服务 | 必选 | 必选 | 可 Operator 化 | Ambari / K8s | P0 |
| HDFS | 分布式存储 | 必选，HA | 可选 | 部分保留 | Ambari | P0 |
| YARN | 资源管理 | 必选，HA | 可选 | 弱化 | Ambari | P0 |
| Hive Metastore | 元数据 | 必选，HA 设计 | 必选 | 可独立/K8s | Ambari / K8s | P0 |
| HiveServer2 | SQL 服务 | 必选，HA 设计 | 可选 | 可替代 | Ambari | P0 |
| Spark | 批计算/SQL | 必选 | 必选 | Spark on K8s | Ambari / K8s | P0 |
| HBase | 宽表存储 | 必选，纳入第一阶段 | 可选 | 暂缓 | Ambari | P0 |
| Kafka | 消息队列 | 暂缓 | 必选 | Operator | Ambari/K8s | P1 |
| Flink | 流计算 | 暂缓 | 必选，主线 | Operator | K8s 优先 | P1 |
| CDC Connector | 数据接入 | 暂缓 | 必选 | 容器化 | Flink/Kafka | P1 |
| Iceberg | 湖仓表格式 | 暂缓 | 必选，主线 | 推荐 | 元数据集成 | P1 |
| Hudi | 湖仓表格式 | 暂缓 | 可选 Profile | 可选 | 元数据集成 | P2 |
| Paimon | 湖仓表格式 | 暂缓 | 已交付的可选扩展 Profile | 可选 | 元数据集成 | P2 |
| Hue | SQL 查询 UI | 可选 | Trino 查询入口 | 可选 | 独立服务 | P2 |
| Delta Lake | 湖仓表格式 | 暂缓 | 可选 | 可选 | Spark 生态 | P2 |
| Trino | 查询引擎 | 暂缓 | 推荐 | 推荐 | K8s/独立部署 | P1 |
| S3 Compatible Storage | 对象存储 | 暂缓 | 必选/推荐 | 必选 | 存储服务 | P1 |
| Ranger | 权限治理 | 暂缓 | 推荐 | 推荐 | Ambari/独立 | P2 |
| Knox | 网关 | 暂缓 | 可选 | 可选 | Ambari/独立 | P3 |
| Atlas | 元数据治理 | 暂缓 | 可选 | 可选 | Ambari/独立 | P3 |
| Kubernetes | 运行平台 | 不要求 | 规划 | 必选 | K8s | P1 |
| Prometheus | 观测 | 可选 | 推荐 | 必选 | K8s/独立 | P2 |

### 4.1 Phase 3 实时数据湖组件交付状态

状态口径：**已发布/冒烟通过**只表示对应 RPM 与所列 smoke 证据存在；**回归失败/进行中**表示当前主线的实际专项测试状态；**未接入/待选型**表示尚无可验证的版本化交付。RPM fast path 或 skipped job 不视为新构建或测试通过。

| 组件 | Phase 3 角色 | 当前版本 / 方案 | 交付与验证状态 | 后续动作 |
|---|---|---:|---|---|
| Kafka | 消息接入 | 3.4.1 | RPM 已发布；KRaft smoke PASS | 补齐与 CDC/Flink 的端到端链路验证 |
| Flink | 流计算 | 1.20.1 | RPM 已发布；local-job smoke PASS | 补齐 Kafka/CDC 与湖仓表格式端到端验证 |
| Flink CDC MySQL | 数据接入 | 3.4.0 | [交付 CI #98](https://github.com/tommyxie2026-tech/bigdata/pull/98) 已合并；连接器 RPM 与 PR 专项测试 PASS；[主线专项测试 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39104310948)；[发布门禁修复 #99](https://github.com/tommyxie2026-tech/bigdata/pull/99) 与产物晋级处理中 | 核验主线 RC 和仓库晋级；之后独立推进 PostgreSQL source 与湖仓联调 |
| Iceberg | 主线湖仓表格式 | 1.12.0 | integration RPM 已发布，仓库 manifest PASS | 补齐和 Kafka/Flink、对象存储的组合验收 |
| Hudi | 可选湖仓 Profile | 1.2.1 | integration RPM 已发布；后续主线回归 PASS；manifest 引用 run 聚合 cancelled、实际 Test/Release success | 分层证据审计已通过；补 CDC upsert 与湖仓恢复验收 |
| Paimon | 可选湖仓扩展 Profile | 2.1.0 | integration RPM 已发布；主线安装、更新与 Spark/Flink 双向互读 PASS；[发布清单](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/paimon/2.1.0/manifest.yaml) | 补齐 CDC、checkpoint 恢复与远端存储组合验收 |
| Hive Metastore | 湖仓元数据 | 随 Hive 4.0.1 | Hive RPM 已发布；Phase 3 多引擎元数据协同未单独验收 | 验证 Trino、Spark、Flink 对同一 catalog 的读写与 schema 一致性 |
| Trino | 交互式查询 | 483 | RPM 已发布；single-node smoke PASS | 补齐 Iceberg/Hudi/Paimon catalog 端到端查询验证 |
| S3 兼容对象存储 | 湖仓存储 | 未选型 | 无目标实现/版本及仓库 RPM；未进入构建测试 | 选定 MinIO、OBS 或其他实现，并定义身份认证、TLS、bucket policy 与兼容性验收 |
| HDFS | 兼容存储后端 | 3.4.3 | RPM 已发布；Phase 1 包装证据 PASS | 作为对象存储未就绪时的替代后端，补齐湖仓格式读写验证 |
| Delta Lake | 可选湖仓格式 | 未定 | 路线图仅列为可选；未纳入当前交付矩阵 | 仅在有明确场景需求后选型和立项 |

Hue 是辅助查询 UI；`4.11.0-2.oe2203sp4` 已发布，[主线安装、Gunicorn 启动与 Hue→Trino 查询通过](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39086875001)，[RPM 晋级 #96](https://github.com/tommyxie2026-tech/bigdata/pull/96) 已合并。其源码是钉住的开发快照；当前测试采用临时 SQLite，不代表生产元数据库或 HA 验收。完整版本与证据见 [当前版本矩阵](version-matrix.md)。

### 4.2 下一轮 CI 工作顺序

以下是补齐交付能力的建议顺序，不改变 Phase 1 已确认范围；组件与版本未通过选型前，不默认加入平台必装组合。

| 顺序 | 工作 | 分类 | 首个验收目标 |
|---|---|---|---|
| 0 | 发布证据溯源校验 | [#97](https://github.com/tommyxie2026-tech/bigdata/pull/97) 已合并，7 个既有 v2 组件审计 PASS | 核验仓库 checksum/repodata、实际 jobs 和轻量 evidence；不下载大 RPM artifact 做逐字节比较 |
| 1 | Flink CDC：先 MySQL source，后 PostgreSQL source | 新增 connector 构建/测试/发布，P1 | 全量快照 + INSERT/UPDATE/DELETE + checkpoint 重启恢复，验证下游最终行集合 |
| 2 | S3 兼容存储适配与 fixture | 新增集成 CI，P1；存储实现另行选型 | Spark/Flink/Trino 对同一远端表的读写、凭据与失败恢复 |
| 3 | Hive Metastore / HiveServer2、Kafka→Flink→湖仓、HDFS/S3 湖仓组合 | 已发布组件集成 CI，P1 | 不重编现有 RPM，验证真实服务端口、数据变化及跨进程恢复 |
| 4 | Ambari Metrics、Kerberos | 新增服务或系统包集成 CI，P1 | 先确认源码/包和依赖，再验证指标查询、认证成功及拒绝路径 |
| 5 | Ranger、Prometheus/JMX exporters | 新增治理/观测 CI，P2 | 最小权限允许/拒绝及审计；抓取指标和故障告警 |
| 6 | Knox、Atlas、Delta Lake、Kubernetes Operators | 按业务触发，P3/后续阶段 | 各自依赖与兼容性确认后，独立 PR 分批交付 |

详细范围、依赖、测试方法和发布门槛见 [组件 CI 补齐计划](component-ci-backlog.md)。

## 5. 第一阶段核心组合

第一阶段聚焦传统数仓物理机底座，并要求支持 HA 生产拓扑设计。

```text
warehouse-ha-foundation:
  Ambari
  Bigtop Build System
  ZooKeeper
  HDFS HA
  YARN HA
  Hive Metastore
  HiveServer2
  Spark
  HBase
```

### 5.1 第一阶段目标

- 完成传统 Hadoop 数仓底座
- 支持 HDFS / YARN / Hive / Spark / HBase 基础能力
- 支持 Ambari 统一管理、配置、监控和服务检查
- 支持 Bigtop 真实构建组件包和发布仓库
- 支持 HA 生产拓扑设计与验证目标

### 5.2 第一阶段不纳入主线的组件

- Kafka
- Flink
- Iceberg / Hudi / Delta Lake
- Trino
- Ranger / Knox / Atlas
- Kubernetes / Operator
- 完整自定义 Ambari Stack 生产实现

这些组件进入后续阶段，避免第一阶段失控。

## 6. 实时数据湖组合

第三阶段开始扩展实时数据湖能力。

```text
realtime-lakehouse:
  Kafka
  Flink
  CDC Connector
  Iceberg
  Hive Metastore
  Trino or Spark SQL
  S3 Compatible Object Storage or HDFS
```

Hudi 作为可选 Profile，用于偏 CDC upsert 的实时湖仓场景。

## 7. 云原生组合

第五阶段开始支持容器平台和云原生数据组件。

```text
cloud-native-data:
  Kubernetes
  Spark Operator
  Flink Kubernetes Operator
  Kafka Operator
  Trino
  Object Storage
  Iceberg / Hudi
  Prometheus
```

## 8. 组件管理方式分类

| 管理方式 | 适合组件 | 说明 |
|---|---|---|
| Ambari | HDFS、YARN、Hive、Spark History、ZooKeeper、HBase | 传统 Hadoop / 物理机 / 虚拟机长期管理面 |
| Bigtop | Hadoop、Hive、Spark、HBase 等包构建 | 真实构建、版本矩阵和包发行体系 |
| Kubernetes / Operator | Flink、Kafka、Spark、Trino | 适合云原生和弹性计算 |
| 独立服务 | Trino、Ranger、Atlas、Prometheus | 可根据场景独立部署 |

## 9. 组件扩展规范

每个新增组件必须补充：

- 组件定位
- 依赖组件
- 推荐版本
- 部署形态
- 管理方式
- 配置模板
- 安装流程
- 服务检查方式
- 监控指标
- 运维 runbook
- 与其他组件的兼容关系

## 10. 交付 Profile 规划

| Profile | 场景 | 组件组合 |
|---|---|---|
| warehouse-basic | 最小传统数仓 | HDFS + YARN + Hive + Spark + ZooKeeper |
| warehouse-ha-foundation | 第一阶段生产基线 | Ambari + Bigtop + ZooKeeper + HDFS HA + YARN HA + Hive + Spark + HBase |
| realtime-ingestion | 实时接入 | Kafka + Flink + CDC Connector |
| lakehouse-basic | 基础数据湖 | S3/HDFS + Iceberg/Hudi + Hive Metastore |
| lakehouse-realtime | 实时数据湖 | Kafka + Flink + Iceberg + Trino |
| governance-secure | 安全治理 | Kerberos + Ranger + Knox + Atlas |
| cloud-native-data | 云原生数据平台 | Kubernetes + Operators + Object Storage |

## 11. 后续待办

- [x] 记录当前实际交付版本（历史升级候选仍不等于冻结版本）
- [x] 记录 openEuler 22.03 LTS SP4 与逐组件 JDK/Python 边界
- [x] 记录 Ambari 3.0.0 当前交付基线
- [x] 记录 HBase 2.6.5 已有 RPM 交付；集群级验收另列
- [ ] 补充 Hive / Spark / HBase / Hadoop 兼容关系
- [ ] 补充 Kafka / Flink / Iceberg 选型细节
- [ ] 补充 Profile 交付模板

- [x] 加入 manifest 引用的 run/attempt/job 分层审计（#97，7 个既有 v2 组件；独立 CDC 契约另行核验）
- [ ] 按 [CI 补齐计划](component-ci-backlog.md) 推进 CDC、S3 与现有组件集成测试
