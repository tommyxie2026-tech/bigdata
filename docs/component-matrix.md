# Bigdata Platform 组件矩阵

> **下一代目标更新（2026-10-24）**：见[Hadoop 3.5.0 目标版本与 Java 矩阵图](target-version-matrix-20261024.md)。目标版本均待验证；下方已发布状态不因目标选型改变。

> 2026-10-11 基线说明：本文保留历史设计讨论。当前 openEuler/RPM 版本、七节点配置、Runbook 与验收入口以 [Phase 1 交付设计](phase1-delivery-design.md) 为准；旧 Ubuntu/DEB 和候选版本指令不可用于当前 RC1 部署。

> 当前状态更新：2026-10-22（Asia/Tokyo），主干 `0f84fa2c60852e73fa8994007076c1e36f844c96`。本轮组件包与专项 CI 交付已完成；整个平台路线图仍有集成开发和后续阶段功能，不能概括为“只剩部署、测试”。版本与证据以 [当前版本矩阵](version-matrix.md) 为准。

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
| Ambari Metrics | 指标采集 | 必选，独立 RPM 已发布 | 复用管理观测 | 集成另验 | Ambari / 独立服务 | P0 |
| Kerberos | 身份认证 | 系统包安全集成待实现 | 安全前提 | 集成另定 | 系统服务 | P1 |
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

### 4.1 当前交付与专项验证状态

“已发布”需有 RPM、checksum、manifest、repodata；“专项 PASS”仅覆盖所列实际链路。复用、skipped/cancelled 不表示新构建或测试成功；fixture 不等于生产产品交付。

| 组件 / 能力 | 当前版本 / 方案 | 已完成 | 仍需完成 |
|---|---|---|---|
| Kafka / Flink | 3.4.1 / 1.20.1 | RPM 已发布，独立 smoke PASS | Kafka→Flink→湖仓业务作业、运行与恢复配置及专项验收 |
| MySQL / PostgreSQL CDC | 均为 3.4.0 | RPM 已发布；双 source 到真实 Paimon/Hudi/Iceberg sink 的恢复专项已通过 | schema 演进与复杂故障窗口；不是所有场景 exactly-once 的证明 |
| Paimon | 2.1.0 | 本地/HDFS/HTTPS S3 双 CDC 恢复 PASS | 生产 Catalog/集群接入与业务场景 |
| Hudi | 1.2.1 | 双 CDC→Hudi/HDFS 精确行集与保存点恢复 PASS | S3 链路及生产 Catalog 集成 |
| Iceberg | 1.12.0 | 双 CDC→Iceberg/HDFS、JDK 17、存储重启后独立读取 PASS | S3 链路、共享 Catalog 与查询引擎集成 |
| HDFS | Hadoop 3.4.3 | RPM 已发布；三种湖仓格式远端读写/恢复专项 PASS | 七节点集群、HA 与容量验证 |
| HTTPS S3 fixture | SeaweedFS 4.48，镜像 digest 固定 | API/S3A、权限拒绝、multipart、持久化与 Paimon 恢复 PASS | 测试后端；不构成生产对象存储选型或服务发行 |
| Hadoop S3A SDK | 2.35.4 | 可选客户端 RPM 与仓库元数据已发布（#106） | 在实际存储端点上验证兼容性 |
| S3 兼容生产存储 | 尚未选型 | 已有测试端点与客户端集成证据 | 产品选型、服务交付/适配及运行配置仍需实现 |
| Hive Metastore / HiveServer2 | 随 Hive 4.0.1 | Hive RPM 已发布 | Spark/Flink/Trino 共享元数据与 schema 的集成配置/适配 |
| Trino | 483 | RPM 与单节点查询 smoke 已交付 | 各湖仓 Catalog 的实际查询集成 |
| Hue | 4.11.0-2.oe2203sp4 | RPM、Gunicorn 与 Hue→Trino 查询 PASS | 生产元数据库、认证/TLS 接入及 HA |
| Ambari Metrics | 3.0.0-1.oe2203sp4 | Collector/Monitor RPM 已发布（#123）；真实指标与重启持久化 PASS | Ambari 集群管理、展示和告警集成 |
| 依赖代理 | Reposilite / Verdaccio / devpi / Caddy | 配置及 CI 已合并；完整组件冷/热/离线构建 PASS | 正式主机、域名、备份与 CI 生产接入待部署验证 |
| Kerberos / Ranger | Kerberos 复用系统包；Ranger 待选型 | 安全设计边界已记录 | principal/keytab、认证/授权、插件、审计等集成仍需开发 |
| Prometheus / JMX exporters | 待锁定交付组合 | 观测设计已记录 | 采集配置、Dashboard、告警和故障恢复联动仍需实现 |
| Delta Lake / Knox / Atlas / Operators | 远期可选 | 路线图占位 | 尚未立项交付，不计为本轮未交付包，也不能计作已完成 |

逐项运行证据见 [版本矩阵](version-matrix.md) 与 [组件 CI 补齐计划](component-ci-backlog.md)。Hue 版本来自钉住开发快照，当前 SQLite smoke 不等于生产元数据库验收。

### 4.2 下一阶段工作与分类

| 顺序 | 工作 | 类型 | 交付边界 |
|---|---|---|---|
| 1 | 依赖代理正式部署和接入 | 部署 / 运维验证 | 需要主机与 HTTPS 域名；复用现有配置，不重新构建组件 RPM |
| 2 | Ambari 集群管理、Metrics 展示及告警、七节点 Blueprint | 集成开发 + 部署验证 | 单节点模板和独立 RPM 不等于七节点管理适配完成 |
| 3 | Kafka→Flink→湖仓、共享 Hive Metastore、Trino Catalog | 集成开发 + 专项测试 | 当前 CDC 直连湖仓结果不能替代消息链和多引擎服务集成 |
| 4 | Kerberos、单个 Ranger 插件、Prometheus/JMX 告警 | 安全 / 观测开发 + 验收 | 选型、服务/插件配置与拒绝路径分别交付 |
| 5 | 生产对象存储与 Hue 生产元数据库/认证 | 选型 / 适配开发 + 部署测试 | CI fixture 与 SQLite smoke 不代表这些集成已完成 |
| 后续 | 产品层开发、VM 多环境、Kubernetes Operators、组合交付 | 后续迭代，按需立项 | 阶段映射及非测试开发项见 [路线图](roadmap.md) 和 [产品路线图](product-roadmap.md) |

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

Hudi 与 Paimon 作为已交付的可选 Profile，按 CDC/upsert、引擎及 Catalog 需求组合；Iceberg 仍为既定主线。

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
- [x] 完成本轮双 CDC 湖仓/HDFS 恢复、Paimon/HTTPS S3 与 Metrics/SDK 发布
- [ ] 按 [CI 补齐计划](component-ci-backlog.md) 推进剩余集成开发、安全与部署验收（本轮完成不代表平台全阶段完成）
