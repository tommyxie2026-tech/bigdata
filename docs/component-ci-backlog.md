# 下一轮组件 CI 补齐计划

核验日期：2026-10-22（Asia/Tokyo）
实现基线：main `0f84fa2c60852e73fa8994007076c1e36f844c96`。既有已发布包与新 CDC 晋级状态分列。
范围：记录已核验的交付进展和后续实施清单；只有注明证据的组件才表示已锁定版本或已完成对应阶段。

## 1. 已完成的组件交付

当前 catalog 有 13 个组件：ZooKeeper、Hadoop、Tez、Hive、Spark、HBase、Kafka、Flink、Trino、Iceberg、Hudi、Paimon、Hue。Ambari 与 Bigtop common 另外管理，不能漏计，也不重复计为新运行时组件。

| 组件组 | 当前证据 | 下一步性质 |
|---|---|---|
| Ambari 3.0.0 与传统数仓 RPM | 版本和包清单见 [版本矩阵](version-matrix.md) | 补集群安装、HA、服务管理与负向测试；不为新增测试重编既有包 |
| Kafka 3.4.1 / Flink 1.20.1 / Trino 483 | 各自 KRaft/local-job/single-node smoke 与仓库 manifest PASS | 增加真实链路，不重复建设单组件打包流程 |
| Iceberg 1.12.0 / Hudi 1.2.1 / Paimon 2.1.0 | integration RPM 已发布，已有 Spark/Flink 专项；Paimon [run 39048307642](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39048307642) 完成更新和双向互读 | 双 CDC→三种湖仓的 HDFS 恢复与 Paimon/HTTPS S3 已通过；继续共享 Catalog、Kafka 中转和剩余 S3 格式集成 |
| Hue 4.11.0-2.oe2203sp4 | [主线 run 39086875001](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39086875001) 的重打包、安装、Gunicorn、Hue→Trino 查询与 RC PASS；[晋级 #96](https://github.com/tommyxie2026-tech/bigdata/pull/96) 已合并 | 保持复用编译成果；补生产元数据库、认证及反向代理场景 |

Hudi 的 manifest 引用 run `39035814730`：run 聚合为 cancelled，最新 attempt 的 Test/Release/gate 作业为 success；后续回归 `39043226367` 也通过。这里是需要明确解释的分层状态差异，不据此将已发布 Hudi 标记为功能失败或直接重发 RPM。

## 2. 新增组件与服务 CI

按当前实时湖仓路线提出以下实施顺序；P1/P2 是本轮建议，不改变既定 Phase 1 范围。下列组件目前未进入 `ci/components.yaml`，除 MySQL/PostgreSQL source 外，也没有对应的独立组件交付工作流。两个 CDC source 已分别发布 RPM，并完成双 source→湖仓恢复主干 CI；Metrics 也已独立发布。它们按专属 contract 管理，尚未因此自动进入统一 catalog。S3 fixture 使用独立测试工作流，不是新增生产服务包。所有新版本都需先确认 immutable source、目标 OS、JDK 和依赖组合，不能把网站“latest”直接写入构建配置。

| 顺序 / 优先级 | 新增项 | 依赖与版本边界 | 首个交付范围 | 必须通过的测试 |
|---|---|---|---|---|
| 1 / P1 | Flink CDC MySQL source | 已锁定 3.4.0 / source `06581fc73b84b1da45fccf93441d96a118d9bfc1`；Flink 1.20.1 / JDK 11 | [RPM 已发布](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/flink-cdc-mysql/3.4.0/manifest.yaml)；[#100](https://github.com/tommyxie2026-tech/bigdata/pull/100) 已合并；[主线 Test / RC / 发布作业 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39106575363) | 已验证 snapshot、I/U/D、completed checkpoint、停止原作业后从实际 savepoint 恢复及最终完整行集；后续湖仓专项见下方本轮闭环 |
| 2 / P1 | Flink CDC PostgreSQL source | 3.4.0 / source `06581fc73b84b1da45fccf93441d96a118d9bfc1`；Flink 1.20.1 / JDK 11；fixture PostgreSQL 14.15 | [RPM 已发布](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/flink-cdc-postgres/3.4.0/manifest.yaml)，#101/#102 已合并 | [主线 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39139306230)：快照、WAL I/U/D、checkpoint、原作业 FINISHED、inactive slot、离线变更及精确 savepoint 恢复；后续湖仓专项见下方本轮闭环 |
| 3 / P1 | S3 兼容存储 fixture / adapter | 临时 SeaweedFS 4.48 / source `530be3e37337488ecc34d58441e0bc476e121c93`，镜像按 digest 固定；客户端后续对齐 Hadoop 3.4.3 | [首个 API fixture CI](s3-fixture-ci.md)：只提供测试端点，不新增服务 RPM；不是生产存储选型 | 首轮：HTTPS、精确 CRUD/list、权限/错误凭据拒绝、multipart 完成/中止、重启持久化；S3A 与 Paimon/HTTPS S3 后续主干验收已 PASS；Hudi/Iceberg 的 S3 与生产存储仍单列 |
| 4 / P1 | Ambari Metrics | 3.0.0；Collector JDK 8、Monitor Python 3；独立契约 | Collector/Monitor RPM 已发布（#123） | 真实安装、CPU/内存查询、全服务重启与新旧样本 PASS；Ambari 集群管理/展示/告警仍需集成 |
| 5 / P1 | Kerberos | 优先复用 openEuler 系统 krb5 包；KDC realm/keytab 为临时测试数据 | 新增安全集成 profile，通常不需要重编第三方系统 RPM | kinit/票据续期、HDFS/Hive 合法访问、无票据/过期票据拒绝、服务 principal 和时钟边界 |
| 6 / P2 | Ranger | 版本、服务及插件依赖待核验；先选一个 HDFS 或 Hive 插件组合 | 一个服务与一个插件链路，后续再扩 Kafka/Trino | 同一资源 allow/deny、策略更新生效、审计记录落地和服务重启 |
| 7 / P2 | Prometheus + JMX/exporters | 先确定监控部署形态和 exporter allowlist | 小范围观测 profile；不把抓取器版本变更扩散成组件重编 | 指标端点实际抓取、关键指标存在、故障注入后告警触发/恢复 |
| 后续 / P3 | Knox、Atlas、Delta Lake、Kubernetes Operators | 跟随明确的网关/治理/表格式或云原生需求，分别核验依赖 | 各自独立选型和 PR；不与前述 P1 合并为大 PR | 业务功能、拒绝路径、兼容矩阵与恢复；不能只做安装烟测 |

Flink CDC 和 Kafka Connect/Debezium 是不同交付路径。第一轮采用 Flink CDC source 的建议并不要求额外部署 Kafka Connect；若确有 Kafka Connect 接入需求，再增加独立选型、包和 offset 恢复测试。[Flink CDC 官方连接器与版本映射](https://nightlies.apache.org/flink/flink-cdc-docs-release-3.7/docs/connectors/flink-sources/overview/) 仅作为候选核验入口，不表示该文档版本已成为项目锁定版本。

S3 fixture 不等于已经选定某个对象存储产品；使用假端点通过的测试也不能宣称真实 S3 兼容通过。按目标端点选择可用能力并保留跳过原因，参考 [Hadoop 3.4.3 S3A 测试指南](https://hadoop.apache.org/docs/r3.4.3/hadoop-aws/tools/hadoop-aws/testing.html)。

## 3. 本轮已完成闭环与剩余范围

| 项目 | 当前证据 | 边界 |
|---|---|---|
| 主干修复 / CI 来源与去重 | #107/#108/#120 已合并；[Build Components](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689437161) success | 原始 build/test run 保留；复用不算新编译 |
| 依赖代理 | #110/#115；[主干完整组件冷/热/离线](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689622642) PASS；265/47/39 秒，1408 依赖文件 | CI 中已实现；正式部署与 CI 生产接入待主机/域名，不代表所有组件均离线就绪 |
| 双 CDC→Paimon | [本地](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554165)、[HDFS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554220)、[HTTPS S3](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554168) success | 精确行集、checkpoint/savepoint、离线源变更恢复和远端存储重启 |
| 双 CDC→Hudi / Iceberg | [Hudi/HDFS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554558)、[Iceberg/HDFS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39689554289) success | 不外推为 S3 全覆盖、schema 演进或所有故障窗口 exactly-once |
| Ambari Metrics | [原始安装/重启](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39653729447)、[主干候选/晋级](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39691186873) PASS；#123 已发布 | 独立服务已交付，Ambari 集群监控集成另列 |
| S3A SDK | #106 已发布 2.35.4 可选依赖 RPM；[实际验收](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39621962743) PASS | 不是生产对象存储服务发行 |

## 4. 下一阶段：仍需开发与仍需验证分列

| 优先级 | 工作 | 尚需实现 / 选型 | 部署与验收 |
|---|---|---|---|
| P1 | 依赖代理正式接入 | 现有配置已交付，按正式域名接入 CI、备份策略 | 冷/热/断网与重启验证；需要授权目标 |
| P1 | Ambari 七节点管理与 Metrics | 完整 Blueprint、服务配置和生命周期适配、展示/告警联动 | Agent、服务启停、HDFS/YARN failover、历史指标和故障告警 |
| P1 | Kafka→Flink→湖仓 | 最小业务作业、Topic/状态配置与运行入口 | 精确计数/主键、更新删除、保存点恢复与无遗漏 |
| P1 | Hive Metastore + Spark/Flink/Trino | 共享 Catalog、权限与表 schema 配置/适配 | 同表跨引擎读写、schema 和结果一致性 |
| P1 | 生产对象存储；Hudi/Iceberg S3 | 产品选型、服务交付/运行配置和客户端适配 | HTTPS、凭据、权限、持久化、读写与恢复 |
| P1 | Kerberos | principal/keytab、票据、服务身份与系统包集成 | kinit、续期、合法访问、无票据/过期拒绝 |
| P2 | Ranger / Prometheus/JMX | 一个插件与审计、实际采集和告警规则 | 策略更新、allow/deny、采集、故障告警/恢复 |
| P2 | Hue 生产元数据库与认证 | PostgreSQL/MySQL、认证和反向代理配置集成 | 迁移、登录查询、元数据持久化、TLS |
| 按需立项 | 平台产品模块 / VM / Operators / 组合 Profile | 调度、治理、质量、服务 API、多租户及运行编排仍属后续实现 | 不把“有设计/模板”计作功能完成，见 [工程路线图](roadmap.md) 和 [产品路线图](product-roadmap.md) |

Knox、Atlas、Delta Lake 等可选项不构成本轮包交付的强制范围；立项后须独立锁定依赖与交付。

## 5. 持续执行约束

1. 发布清单、run attempt、实际 jobs、artifact 来源、checksum 和 repodata 分层核验；独立 Metrics/CDC/SDK 不能声称被既有七组件通用审计自动覆盖。
2. 源码和打包输入不变时消费已发布 RPM；仅修改测试、文档或下载策略不重新编译。包内容改变按发布策略处理，能复用编译结果则只重打包。
3. 独立工作流，按影响范围回归；HTTP、服务启动、查询和 cleanup 均有 deadline，失败保留原始日志。
4. 新 PR 单独审核；生产部署目标不能猜测；不在本地下载大型 RPM/JAR。集群 HA、生产存储与安全验收单列。
5. 当前清单是实现与交付状态，不是“所有迭代仅剩测试/部署”的声明；本轮五步仍有代理正式部署这一未完成项。
