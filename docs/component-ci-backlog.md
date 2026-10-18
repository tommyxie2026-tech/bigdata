# 下一轮组件 CI 补齐计划

核验日期：2026-10-18（Asia/Tokyo）  
实现基线：main `50639533eebf915815292be52f4cbbe98b2c0f43`。既有已发布包与新 CDC 晋级状态分列。  
范围：记录已核验的交付进展和后续实施清单；只有注明证据的组件才表示已锁定版本或已完成对应阶段。

## 1. 已完成的组件交付

当前 catalog 有 13 个组件：ZooKeeper、Hadoop、Tez、Hive、Spark、HBase、Kafka、Flink、Trino、Iceberg、Hudi、Paimon、Hue。Ambari 与 Bigtop common 另外管理，不能漏计，也不重复计为新运行时组件。

| 组件组 | 当前证据 | 下一步性质 |
|---|---|---|
| Ambari 3.0.0 与传统数仓 RPM | 版本和包清单见 [版本矩阵](version-matrix.md) | 补集群安装、HA、服务管理与负向测试；不为新增测试重编既有包 |
| Kafka 3.4.1 / Flink 1.20.1 / Trino 483 | 各自 KRaft/local-job/single-node smoke 与仓库 manifest PASS | 增加真实链路，不重复建设单组件打包流程 |
| Iceberg 1.12.0 / Hudi 1.2.1 / Paimon 2.1.0 | integration RPM 已发布，已有 Spark/Flink 专项；Paimon [run 39048307642](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39048307642) 完成更新和双向互读 | 补 CDC、持久化 checkpoint、HDFS/S3、catalog 和多进程恢复 |
| Hue 4.11.0-2.oe2203sp4 | [主线 run 39086875001](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39086875001) 的重打包、安装、Gunicorn、Hue→Trino 查询与 RC PASS；[晋级 #96](https://github.com/tommyxie2026-tech/bigdata/pull/96) 已合并 | 保持复用编译成果；补生产元数据库、认证及反向代理场景 |

Hudi 的 manifest 引用 run `39035814730`：run 聚合为 cancelled，最新 attempt 的 Test/Release/gate 作业为 success；后续回归 `39043226367` 也通过。这里是需要明确解释的分层状态差异，不据此将已发布 Hudi 标记为功能失败或直接重发 RPM。

## 2. 新增组件与服务 CI

按当前实时湖仓路线提出以下实施顺序；P1/P2 是本轮建议，不改变既定 Phase 1 范围。下列组件目前未进入 `ci/components.yaml`，除 MySQL source 外，也没有对应的独立组件交付工作流。MySQL 已通过 #98 接入独立 CI，以专属 contract 锁定，尚未进入统一 catalog。所有新版本都需先确认 immutable source、目标 OS、JDK 和依赖组合，不能把网站“latest”直接写入构建配置。

| 顺序 / 优先级 | 新增项 | 依赖与版本边界 | 首个交付范围 | 必须通过的测试 |
|---|---|---|---|---|
| 1 / P1 | Flink CDC MySQL source | 已锁定 3.4.0 / source `06581fc73b84b1da45fccf93441d96a118d9bfc1`；Flink 1.20.1 / JDK 11 | [RPM 已发布](../repo/openeuler-22.03-lts-sp4/bigtop-3.6/flink-cdc-mysql/3.4.0/manifest.yaml)；[#100](https://github.com/tommyxie2026-tech/bigdata/pull/100) 已合并；[主线 Test / RC / 发布作业 PASS](https://github.com/tommyxie2026-tech/bigdata/actions/runs/39106575363) | 已验证 snapshot、I/U/D、completed checkpoint、停止原作业后从实际 savepoint 恢复及最终完整行集；不代表湖仓联调已过 |
| 2 / P1 | Flink CDC PostgreSQL source | 复用已建立的 CDC 生命周期；核验数据库版本及复制配置 | 第二个独立 PR，避免与 MySQL 同次引入多个变量 | snapshot + WAL 增量 + restart/恢复；断流失败应可诊断，不能仅凭任务 RUNNING 判通过 |
| 3 / P1 | S3 兼容存储 fixture / adapter | 具体存储实现、发布形态、许可证与维护方式待选；客户端对齐 Hadoop 3.4.3 及各引擎的依赖 | 先集成测试端点和凭据/TLS配置；只有确定交付自建存储服务时，才新增其服务 RPM CI | bucket 读写/删除、无权限拒绝、凭据错误、TLS、multipart；Spark/Flink 对同一湖仓表读写，Trino 查询按实际 connector 能力验证 |
| 4 / P1 | Ambari Metrics | 先确认 Ambari 3.0.0 对应源码/recipe、包名和运行时；不能因 Ambari Server RPM 已有就认为 Metrics 已交付 | Collector/Monitor 的独立包或现有 recipe 可行性 PR | 干净安装、采集代理上报、查询带时间戳的真实指标、服务重启 |
| 5 / P1 | Kerberos | 优先复用 openEuler 系统 krb5 包；KDC realm/keytab 为临时测试数据 | 新增安全集成 profile，通常不需要重编第三方系统 RPM | kinit/票据续期、HDFS/Hive 合法访问、无票据/过期票据拒绝、服务 principal 和时钟边界 |
| 6 / P2 | Ranger | 版本、服务及插件依赖待核验；先选一个 HDFS 或 Hive 插件组合 | 一个服务与一个插件链路，后续再扩 Kafka/Trino | 同一资源 allow/deny、策略更新生效、审计记录落地和服务重启 |
| 7 / P2 | Prometheus + JMX/exporters | 先确定监控部署形态和 exporter allowlist | 小范围观测 profile；不把抓取器版本变更扩散成组件重编 | 指标端点实际抓取、关键指标存在、故障注入后告警触发/恢复 |
| 后续 / P3 | Knox、Atlas、Delta Lake、Kubernetes Operators | 跟随明确的网关/治理/表格式或云原生需求，分别核验依赖 | 各自独立选型和 PR；不与前述 P1 合并为大 PR | 业务功能、拒绝路径、兼容矩阵与恢复；不能只做安装烟测 |

Flink CDC 和 Kafka Connect/Debezium 是不同交付路径。第一轮采用 Flink CDC source 的建议并不要求额外部署 Kafka Connect；若确有 Kafka Connect 接入需求，再增加独立选型、包和 offset 恢复测试。[Flink CDC 官方连接器与版本映射](https://nightlies.apache.org/flink/flink-cdc-docs-release-3.7/docs/connectors/flink-sources/overview/) 仅作为候选核验入口，不表示该文档版本已成为项目锁定版本。

S3 fixture 不等于已经选定某个对象存储产品；使用假端点通过的测试也不能宣称真实 S3 兼容通过。按目标端点选择可用能力并保留跳过原因，参考 [Hadoop 3.4.3 S3A 测试指南](https://hadoop.apache.org/docs/r3.4.3/hadoop-aws/tools/hadoop-aws/testing.html)。

## 3. 已发布组件还需要补的集成 CI

这些是测试缺口，不是缺少 RPM，默认消费已发布包。

| 优先级 | 链路 / 场景 | 复用组件 | 结果断言 |
|---|---|---|---|
| P1 | MySQL/PostgreSQL CDC → Flink → Paimon，之后扩 Iceberg/Hudi | 已发布 Flink、湖仓 RPM + 新连接器 | I/U/D 与源库最终状态一致；重启后继续增量；schema 演进按所选 connector 能力分项验证 |
| P1 | Kafka → Flink → Iceberg/Paimon | Kafka/Flink/湖仓包 | 有限数据集计数、主键/校验和、checkpoint、重启与无重复/漏数；先一张表 |
| P1 | Hive Metastore + HiveServer2 + Spark/Trino | 已发布 Hive/Spark/Trino | 建表、schema、真实查询返回值；catalog 共享行为单独验证，不把 Hive RPM 安装当作多引擎验收 |
| P1 | HDFS/S3 + 湖仓 + Spark/Flink，按支持情况增加 Trino | Hadoop、各引擎与 integration RPM | 远端持久化、跨进程读取、schema、更新/删除、失败后重启；现有本地文件互读不能替代 |
| P1 | Ambari 3 Master + 3 Worker + 1 Gateway / HA | 已发布 Ambari 和传统数仓包 | Blueprint、Agent、服务启停、HDFS/YARN failover、Hive/HBase 服务检查 |
| P2 | Hue + 生产型元数据库 + Trino | Hue/Trino 包和临时 PostgreSQL/MySQL fixture | 迁移、登录/查询、重启后元数据保留；TLS/认证另列；当前 SQLite 冒烟不等于此项已过 |

## 4. 共用 CI 必须先补的约束

1. **分层证据审计（P0）**：校验 manifest、run attempt、实际必需 jobs、复用 Build provenance、artifact SHA256 和 repodata。run 聚合状态与作业状态分开记录；skipped 是复用或不适用，不能写成新构建/测试成功。
2. **包复用**：源版本、源码 identity 和构建/打包输入不变时，消费仓库或成功 artifact。仅改测试脚本不编译 RPM。启动器、依赖、包内容改变时递增 RPM Release；能复用编译结果就只重打包，不能修改安装后的包来掩盖发布缺陷。
3. **小而独立的流程**：每个新增组件一个专属 workflow；依赖 RPM 通过 fast path 验证，不等整条组件串行链；共享脚本变更才扩大相关回归。
4. **有界执行**：网络请求设置 connect/response 超时；服务等待、迁移、查询、进程退出均有 deadline；失败上传真实日志和卡住的步骤。不得靠不断增加总超时掩盖崩溃。
5. **完整发布门槛**：catalog/source pin → 编译或可追溯复用 → 干净 openEuler 安装 → 实际功能和恢复断言 → RC → 晋级 PR → 仓库 RPM/checksum/manifest/repodata 一致。集群/HA 验收单列，不借单机 PASS 代替。
6. **每个实施 PR 的最小内容**：组件条目或独立 contract、版本/源/依赖锁定、build/test adapter、专项 workflow、成功和失败证据、RPM allowlist、发布说明与矩阵更新。每项测试明确数据规模、超时、预期行集合和恢复点。

## 5. 建议接下来的 PR

- PR A：[#97](https://github.com/tommyxie2026-tech/bigdata/pull/97) 已合并，既有 7 个 v2 组件审计通过；校验仓库摘要、job/artifact 来源和轻量 evidence，不下载大 RPM artifact 做逐字节比较。
- PR B：[#98](https://github.com/tommyxie2026-tech/bigdata/pull/98)、发布门禁修复 [#99](https://github.com/tommyxie2026-tech/bigdata/pull/99) 和仓库晋级 [#100](https://github.com/tommyxie2026-tech/bigdata/pull/100) 均已合并。MySQL CDC RPM 已发布；主线 run `39106575363` 的实际 Test、Release Candidate 和发布作业 success；仓库主线 `50639533` 的 CI 和审计 success。发布目录的 Git blobs 与已核验晋级产物完全一致，复用 Build `39102586103`，未重新编译 RPM。
- PR C：Flink CDC PostgreSQL source，复用 B 已验证的基础流程。
- PR D：S3 fixture/adapter 选型和远端湖仓读写 CI；选型前可继续用 HDFS 做基线验收。
- PR E：Ambari Metrics 可行性和采集/查询 CI；与传统集群集成验收并行安排，但分别提交。
- 后续按安全优先级推进 Kerberos、Ranger，再补 Prometheus/JMX 和其他可选组件。

以上是下一轮工作清单；当前矩阵 PR 不新增这些组件的 catalog 项，也不触发版本升级决策。
